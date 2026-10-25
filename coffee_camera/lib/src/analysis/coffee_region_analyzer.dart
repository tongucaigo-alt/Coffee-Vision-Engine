import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/analysis_frame.dart';
import '../models/coffee_region_mask.dart';
import '../models/cup_detection_result.dart';
import 'frame_pixel_sampler.dart';

class CoffeeRegionAnalysis {
  const CoffeeRegionAnalysis({
    required this.score,
    required this.coverage,
    this.mask,
  });

  const CoffeeRegionAnalysis.empty() : score = 0, coverage = 0, mask = null;

  final double score;
  final double coverage;
  final CoffeeRegionMask? mask;
}

class CoffeeRegionAnalyzer {
  const CoffeeRegionAnalyzer();

  Future<CoffeeRegionAnalysis> analyze({
    required AnalysisFrame frame,
    required CupDetectionResult? cup,
    required CoffeeCameraConfig config,
  }) async {
    final transform = frame.previewTransform;
    if (cup == null ||
        transform == null ||
        cup.confidence < config.minimumCupConfidence) {
      return const CoffeeRegionAnalysis.empty();
    }
    return Isolate.run(
      () => _analyzeCoffeeRegion(
        frame,
        cup.normalizedBounds,
        config.minimumGroundCoverage,
        config.maximumGroundCoverage,
        config.minimumCoffeePresence,
        0.78,
      ),
    );
  }
}

CoffeeRegionAnalysis _analyzeCoffeeRegion(
  AnalysisFrame frame,
  Rect normalizedBounds,
  double minimumCoverage,
  double maximumCoverage,
  double minimumScore,
  double innerAnalysisRatio,
) {
  const gridSize = 32;
  final transform = frame.previewTransform;
  if (transform == null) return const CoffeeRegionAnalysis.empty();
  final viewport = transform.viewportSize;
  final subjectBounds = Rect.fromLTRB(
    normalizedBounds.left * viewport.width,
    normalizedBounds.top * viewport.height,
    normalizedBounds.right * viewport.width,
    normalizedBounds.bottom * viewport.height,
  );
  final innerBounds = Rect.fromCenter(
    center: subjectBounds.center,
    width: subjectBounds.width * innerAnalysisRatio,
    height: subjectBounds.height * innerAnalysisRatio,
  );
  final sampler = FramePixelSampler(frame);
  final samples = List<FramePixel?>.filled(gridSize * gridSize, null);
  final inside = Uint8List(gridSize * gridSize);
  final luminances = <double>[];

  for (var row = 0; row < gridSize; row++) {
    for (var column = 0; column < gridSize; column++) {
      final nx = ((column + 0.5) / gridSize - 0.5) * 2;
      final ny = ((row + 0.5) / gridSize - 0.5) * 2;
      if (nx * nx + ny * ny > 1) continue;
      final index = row * gridSize + column;
      final point = Offset(
        innerBounds.left + innerBounds.width * (column + 0.5) / gridSize,
        innerBounds.top + innerBounds.height * (row + 0.5) / gridSize,
      );
      final sample = sampler.sampleViewport(point);
      if (sample == null) continue;
      inside[index] = 1;
      samples[index] = sample;
      luminances.add(sample.luminance);
    }
  }
  if (luminances.length < 400) return const CoffeeRegionAnalysis.empty();
  luminances.sort();
  final brightReference = _percentile(luminances, 0.78);
  final middleReference = _percentile(luminances, 0.48);
  final threshold = math.min(brightReference - 26, middleReference - 10);
  final raw = Uint8List(gridSize * gridSize);
  for (var index = 0; index < raw.length; index++) {
    final sample = samples[index];
    if (sample == null) continue;
    final contrast = brightReference - sample.luminance;
    final colorAccepted = sample.warmth > -0.24 || contrast >= 52;
    if (brightReference >= 105 &&
        sample.luminance <= threshold &&
        contrast >= 22 &&
        colorAccepted) {
      raw[index] = ((contrast - 18) / 80 * 255).round().clamp(48, 255);
    }
  }

  final normalizedInnerBounds = Rect.fromLTRB(
    innerBounds.left / viewport.width,
    innerBounds.top / viewport.height,
    innerBounds.right / viewport.width,
    innerBounds.bottom / viewport.height,
  );
  final insideCount = inside.where((value) => value > 0).length;
  CoffeeRegionAnalysis resultFor(Uint8List cells, {bool dense = false}) {
    final cleaned = _cleanGroundCells(cells, gridSize);
    final activeValues = cleaned.where((value) => value > 0).toList();
    final coverage = insideCount == 0 ? 0.0 : activeValues.length / insideCount;
    final averageIntensity = activeValues.isEmpty
        ? 0.0
        : activeValues.reduce((a, b) => a + b) / activeValues.length / 255;
    final score = (coverage * 0.65 + averageIntensity * 0.35).clamp(0.0, 1.0);
    return CoffeeRegionAnalysis(
      score: score,
      coverage: coverage,
      mask: CoffeeRegionMask(
        normalizedBounds: normalizedInnerBounds,
        width: gridSize,
        height: gridSize,
        intensities: cleaned,
        coverage: coverage,
        requiresStrictPhotoVerification: dense,
      ),
    );
  }

  bool usable(CoffeeRegionAnalysis result) =>
      result.score >= minimumScore &&
      result.coverage >= minimumCoverage &&
      result.coverage <= maximumCoverage &&
      (result.mask?.activeCellCount ?? 0) >= 24;

  final legacy = resultFor(raw);
  if (usable(legacy)) return legacy;

  // A coated cup has little exposed porcelain inside the analysis disk.
  // Keep the existing path first; use the visible rim only when warm colour
  // and spatial texture independently support dense grounds.
  final denseCells = _denseGroundCells(
    samples: samples,
    gridSize: gridSize,
    sampler: sampler,
    subjectBounds: subjectBounds,
    middleReference: middleReference,
    luminances: luminances,
  );
  if (denseCells != null) {
    final dense = resultFor(denseCells, dense: true);
    if (usable(dense)) return dense;
  }
  return brightReference < 105 ? const CoffeeRegionAnalysis.empty() : legacy;
}

Uint8List? _denseGroundCells({
  required List<FramePixel?> samples,
  required int gridSize,
  required FramePixelSampler sampler,
  required Rect subjectBounds,
  required double middleReference,
  required List<double> luminances,
}) {
  if (middleReference < 24 || middleReference > 150) return null;
  if (_percentile(luminances, 0.90) - _percentile(luminances, 0.10) < 18) {
    return null;
  }
  bool brown(FramePixel pixel) =>
      pixel.luminance >= 18 &&
      pixel.luminance <= 155 &&
      pixel.warmth >= 0.025 &&
      pixel.chromaU < 128 &&
      pixel.chromaV > 128;
  if (samples.whereType<FramePixel>().where(brown).length <
      luminances.length * 0.55) {
    return null;
  }

  final rimValues = <double>[];
  var brightRimSamples = 0;
  const angleSamples = 64;
  for (var index = 0; index < angleSamples; index++) {
    final angle = 2 * math.pi * index / angleSamples;
    final direction = Offset(
      math.cos(angle) * subjectBounds.width / 2,
      math.sin(angle) * subjectBounds.height / 2,
    );
    double? brightest;
    // Stay inside the detected rim: a bright background outside a dark cup
    // must not become the porcelain reference.
    for (final ratio in const [0.90, 0.94, 0.98]) {
      final pixel = sampler.sampleViewport(
        subjectBounds.center + direction * ratio,
      );
      if (pixel != null) {
        brightest = math.max(brightest ?? 0, pixel.luminance);
      }
    }
    if (brightest == null) continue;
    rimValues.add(brightest);
    if (brightest >= 142 && brightest - middleReference >= 35) {
      brightRimSamples++;
    }
  }
  if (rimValues.length < 56 || brightRimSamples < angleSamples * 0.48) {
    return null;
  }
  rimValues.sort();
  final rimReference = _percentile(rimValues, 0.60);
  final raw = Uint8List(samples.length);
  var texturedCells = 0;
  for (var row = 1; row < gridSize - 1; row++) {
    for (var column = 1; column < gridSize - 1; column++) {
      final index = row * gridSize + column;
      final pixel = samples[index];
      if (pixel == null) continue;
      final neighbors = [
        samples[index - 1],
        samples[index + 1],
        samples[index - gridSize],
        samples[index + gridSize],
      ].whereType<FramePixel>().toList();
      if (neighbors.length != 4) continue;
      final localMean =
          neighbors.fold(0.0, (sum, value) => sum + value.luminance) / 4;
      final localValues = [
        pixel.luminance,
        ...neighbors.map((p) => p.luminance),
      ];
      final localRange =
          localValues.reduce(math.max) - localValues.reduce(math.min);
      // Reject a flat brown surface, smooth shadows and sensor black. The
      // actual texture cells become the mask; no synthetic coverage is added.
      final textured =
          (pixel.luminance - localMean).abs() >= 3 && localRange >= 10;
      if (textured && brown(pixel)) texturedCells++;
      final contrast = rimReference - pixel.luminance;
      if (textured &&
          brown(pixel) &&
          pixel.luminance <= middleReference &&
          contrast >= 35) {
        raw[index] = ((contrast - 18) / 80 * 255).round().clamp(48, 255);
      }
    }
  }
  return texturedCells >= luminances.length * 0.12 ? raw : null;
}

Uint8List _cleanGroundCells(Uint8List raw, int gridSize) {
  final filtered = Uint8List(gridSize * gridSize);
  for (var row = 1; row < gridSize - 1; row++) {
    for (var column = 1; column < gridSize - 1; column++) {
      final index = row * gridSize + column;
      if (raw[index] == 0) continue;
      var neighbors = 0;
      var strongest = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final value = raw[(row + dy) * gridSize + column + dx];
          if (value > 0) neighbors++;
          strongest = math.max(strongest, value);
        }
      }
      if (neighbors >= 3) filtered[index] = strongest;
    }
  }

  return _removeSmallComponents(filtered, gridSize, minimumCells: 3);
}

double _percentile(List<double> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index.clamp(0, sorted.length - 1)];
}

Uint8List _removeSmallComponents(
  Uint8List source,
  int width, {
  required int minimumCells,
}) {
  final output = Uint8List.fromList(source);
  final visited = Uint8List(source.length);
  for (var start = 0; start < source.length; start++) {
    if (source[start] == 0 || visited[start] != 0) continue;
    final queue = <int>[start];
    final component = <int>[];
    visited[start] = 1;
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final index = queue[cursor];
      component.add(index);
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
    if (component.length < minimumCells) {
      for (final index in component) {
        output[index] = 0;
      }
    }
  }
  return output;
}
