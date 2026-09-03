import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../config/residue_detection_profile.dart';
import '../models/analysis_frame.dart';
import '../models/residue_analysis_result.dart';
import '../models/residue_region_mask.dart';
import '../models/saucer_detection_result.dart';
import 'frame_pixel_sampler.dart';

class SaucerResidueAnalyzer {
  const SaucerResidueAnalyzer();

  Future<ResidueAnalysisResult> analyze({
    required AnalysisFrame frame,
    required SaucerDetectionResult? saucer,
    required ResidueDetectionProfile profile,
  }) async {
    if (frame.previewTransform == null || profile.gridSize < 2) {
      return const ResidueAnalysisResult.empty();
    }
    return Isolate.run(() => _analyzeSaucerResidue(frame, saucer, profile));
  }
}

ResidueAnalysisResult _analyzeSaucerResidue(
  AnalysisFrame frame,
  SaucerDetectionResult? saucer,
  ResidueDetectionProfile profile,
) {
  final transform = frame.previewTransform;
  if (transform == null || transform.viewportSize.isEmpty) {
    return const ResidueAnalysisResult.empty();
  }
  final gridSize = profile.gridSize;
  final viewport = transform.viewportSize;
  final normalizedBounds = _clampNormalized(profile.normalizedAnalysisBounds);
  final analysisBounds = Rect.fromLTRB(
    normalizedBounds.left * viewport.width,
    normalizedBounds.top * viewport.height,
    normalizedBounds.right * viewport.width,
    normalizedBounds.bottom * viewport.height,
  );
  if (analysisBounds.isEmpty) {
    return const ResidueAnalysisResult.empty(analysisPerformed: true);
  }

  final boundaryUsed = saucer != null;
  final saucerBounds = saucer == null
      ? null
      : Rect.fromLTRB(
          saucer.normalizedBounds.left * viewport.width,
          saucer.normalizedBounds.top * viewport.height,
          saucer.normalizedBounds.right * viewport.width,
          saucer.normalizedBounds.bottom * viewport.height,
        );
  final roundedRegion = RRect.fromRectAndRadius(
    analysisBounds,
    Radius.circular(
      math.min(analysisBounds.width, analysisBounds.height) * 0.14,
    ),
  );
  final sampler = FramePixelSampler(frame);
  final samples = List<FramePixel?>.filled(gridSize * gridSize, null);
  final eligible = Uint8List(gridSize * gridSize);

  for (var row = 0; row < gridSize; row++) {
    for (var column = 0; column < gridSize; column++) {
      final point = Offset(
        analysisBounds.left + analysisBounds.width * (column + 0.5) / gridSize,
        analysisBounds.top + analysisBounds.height * (row + 0.5) / gridSize,
      );
      if (!_insideAnalysisShape(
        point,
        analysisBounds,
        roundedRegion,
        profile.analysisShape,
      )) {
        continue;
      }
      if (saucerBounds != null &&
          !_insideSaucerInterior(
            point,
            saucerBounds,
            profile.boundaryInnerRatio,
          )) {
        continue;
      }
      final sample = sampler.sampleViewport(point);
      if (sample == null) continue;
      final index = row * gridSize + column;
      eligible[index] = 1;
      samples[index] = sample;
    }
  }

  final eligibleCount = eligible.where((value) => value != 0).length;
  if (eligibleCount < gridSize * gridSize ~/ 5) {
    return ResidueAnalysisResult(
      mask: null,
      score: 0,
      confidence: 0,
      residueDetected: false,
      residueBounds: null,
      boundaryUsed: boundaryUsed,
      analysisPerformed: true,
    );
  }

  final raw = Uint8List(gridSize * gridSize);
  final radius = math.max(2, profile.localReferenceRadius);
  final weightTotal =
      profile.luminanceContrastWeight +
      profile.chromaDifferenceWeight +
      profile.textureWeight;
  for (var row = 0; row < gridSize; row++) {
    for (var column = 0; column < gridSize; column++) {
      final index = row * gridSize + column;
      final sample = samples[index];
      if (sample == null) continue;
      final neighbors = <FramePixel>[];
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nextRow = row + dy;
          final nextColumn = column + dx;
          if (nextRow < 0 ||
              nextRow >= gridSize ||
              nextColumn < 0 ||
              nextColumn >= gridSize) {
            continue;
          }
          final neighbor = samples[nextRow * gridSize + nextColumn];
          if (neighbor != null) neighbors.add(neighbor);
        }
      }
      if (neighbors.length < 8) continue;

      final luminances = neighbors.map((pixel) => pixel.luminance).toList()
        ..sort();
      final chromaUs = neighbors.map((pixel) => pixel.chromaU).toList()..sort();
      final chromaVs = neighbors.map((pixel) => pixel.chromaV).toList()..sort();
      final luminanceReference = _percentile(luminances, 0.72);
      final chromaUReference = _percentile(chromaUs, 0.50);
      final chromaVReference = _percentile(chromaVs, 0.50);
      final luminanceFeature = ((luminanceReference - sample.luminance) / 64)
          .clamp(0.0, 1.0);
      final chromaDistance = math.sqrt(
        math.pow(sample.chromaU - chromaUReference, 2) +
            math.pow(sample.chromaV - chromaVReference, 2),
      );
      final chromaFeature = (chromaDistance / 64).clamp(0.0, 1.0);
      final meanLuminance =
          luminances.reduce((first, second) => first + second) /
          luminances.length;
      final textureFeature =
          (neighbors
                      .map((pixel) => (pixel.luminance - meanLuminance).abs())
                      .reduce((first, second) => first + second) /
                  neighbors.length /
                  36)
              .clamp(0.0, 1.0);

      if (luminanceFeature < 0.10 && chromaFeature < 0.14) continue;
      final intensity = weightTotal <= 0
          ? 0.0
          : (luminanceFeature * profile.luminanceContrastWeight +
                    chromaFeature * profile.chromaDifferenceWeight +
                    textureFeature * profile.textureWeight) /
                weightTotal;
      if (intensity < profile.minimumCandidateIntensity) continue;
      raw[index] = (intensity * 255).round().clamp(1, 255);
    }
  }

  final components = _connectedComponents(raw, gridSize);
  var retained = components.where((component) {
    final average = component.totalIntensity / component.indices.length / 255;
    final strongest = component.maximumIntensity / 255;
    return component.indices.length >= profile.minimumComponentCells ||
        (strongest >= profile.strongComponentMinimumIntensity &&
            average >= profile.minimumCandidateIntensity);
  }).toList();
  if (!profile.preserveMultipleComponents && retained.length > 1) {
    retained.sort(
      (first, second) => second.totalIntensity.compareTo(first.totalIntensity),
    );
    retained = <_ResidueComponent>[retained.first];
  }

  final cleaned = Uint8List(gridSize * gridSize);
  Rect? residueBounds;
  for (final component in retained) {
    for (final index in component.indices) {
      cleaned[index] = raw[index];
      final row = index ~/ gridSize;
      final column = index % gridSize;
      final cellBounds = Rect.fromLTRB(
        normalizedBounds.left + normalizedBounds.width * column / gridSize,
        normalizedBounds.top + normalizedBounds.height * row / gridSize,
        normalizedBounds.left +
            normalizedBounds.width * (column + 1) / gridSize,
        normalizedBounds.top + normalizedBounds.height * (row + 1) / gridSize,
      );
      residueBounds = residueBounds == null
          ? cellBounds
          : residueBounds.expandToInclude(cellBounds);
    }
  }

  final activeValues = cleaned.where((value) => value > 0).toList();
  final coverage = activeValues.length / eligibleCount;
  final averageIntensity = activeValues.isEmpty
      ? 0.0
      : activeValues.reduce((first, second) => first + second) /
            activeValues.length /
            255;
  final coverageReference = math.max(profile.minimumCoverage * 4, 0.08);
  final coverageStrength = (coverage / coverageReference).clamp(0.0, 1.0);
  final score = (averageIntensity * 0.70 + coverageStrength * 0.30).clamp(
    0.0,
    1.0,
  );
  final mask = ResidueRegionMask(
    normalizedBounds: normalizedBounds,
    width: gridSize,
    height: gridSize,
    intensities: cleaned,
    coverage: coverage,
    residueBounds: residueBounds,
    componentCount: retained.length,
  );
  final residueDetected =
      coverage >= profile.minimumCoverage &&
      coverage <= profile.maximumCoverage &&
      mask.activeCellCount >= profile.minimumActiveCells &&
      score >= profile.minimumScore;
  final activeCellConfidence =
      (mask.activeCellCount / math.max(1, profile.minimumActiveCells * 2))
          .clamp(0.0, 1.0);
  var confidence = score * 0.72 + activeCellConfidence * 0.10;
  if (saucer != null) {
    confidence += saucer.confidence.clamp(0.0, 1.0) * 0.18;
  } else {
    confidence *= 0.82;
  }

  return ResidueAnalysisResult(
    mask: mask,
    score: score,
    confidence: confidence.clamp(0.0, 1.0),
    residueDetected: residueDetected,
    residueBounds: residueBounds,
    boundaryUsed: boundaryUsed,
    analysisPerformed: true,
  );
}

Rect _clampNormalized(Rect value) {
  return Rect.fromLTRB(
    value.left.clamp(0.0, 1.0),
    value.top.clamp(0.0, 1.0),
    value.right.clamp(0.0, 1.0),
    value.bottom.clamp(0.0, 1.0),
  );
}

bool _insideAnalysisShape(
  Offset point,
  Rect bounds,
  RRect roundedRegion,
  ResidueAnalysisShape shape,
) {
  if (shape == ResidueAnalysisShape.roundedRectangle) {
    return roundedRegion.contains(point);
  }
  final nx = (point.dx - bounds.center.dx) / (bounds.width / 2);
  final ny = (point.dy - bounds.center.dy) / (bounds.height / 2);
  return nx * nx + ny * ny <= 1;
}

bool _insideSaucerInterior(Offset point, Rect bounds, double innerRatio) {
  final radiusX = bounds.width * 0.5 * innerRatio;
  final radiusY = bounds.height * 0.5 * innerRatio;
  if (radiusX <= 0 || radiusY <= 0) return false;
  final nx = (point.dx - bounds.center.dx) / radiusX;
  final ny = (point.dy - bounds.center.dy) / radiusY;
  return nx * nx + ny * ny <= 1;
}

double _percentile(List<double> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index.clamp(0, sorted.length - 1)];
}

List<_ResidueComponent> _connectedComponents(Uint8List source, int width) {
  final components = <_ResidueComponent>[];
  final visited = Uint8List(source.length);
  for (var start = 0; start < source.length; start++) {
    if (source[start] == 0 || visited[start] != 0) continue;
    final queue = <int>[start];
    final indices = <int>[];
    var totalIntensity = 0;
    var maximumIntensity = 0;
    visited[start] = 1;
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final index = queue[cursor];
      indices.add(index);
      totalIntensity += source[index];
      maximumIntensity = math.max(maximumIntensity, source[index]);
      final row = index ~/ width;
      final column = index % width;
      for (final delta in const <(int, int)>[
        (0, -1),
        (1, 0),
        (0, 1),
        (-1, 0),
      ]) {
        final nextColumn = column + delta.$1;
        final nextRow = row + delta.$2;
        if (nextColumn < 0 ||
            nextColumn >= width ||
            nextRow < 0 ||
            nextRow >= width) {
          continue;
        }
        final next = nextRow * width + nextColumn;
        if (source[next] == 0 || visited[next] != 0) continue;
        visited[next] = 1;
        queue.add(next);
      }
    }
    components.add(
      _ResidueComponent(
        indices: indices,
        totalIntensity: totalIntensity,
        maximumIntensity: maximumIntensity,
      ),
    );
  }
  return components;
}

class _ResidueComponent {
  const _ResidueComponent({
    required this.indices,
    required this.totalIntensity,
    required this.maximumIntensity,
  });

  final List<int> indices;
  final int totalIntensity;
  final int maximumIntensity;
}
