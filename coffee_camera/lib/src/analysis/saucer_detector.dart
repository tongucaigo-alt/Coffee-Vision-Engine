import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/analysis_frame.dart';
import '../models/saucer_detection_result.dart';
import '../models/target_geometry.dart';
import 'frame_pixel_sampler.dart';

abstract interface class SaucerDetector {
  bool get isAvailable;

  Future<SaucerDetectionResult?> detect(AnalysisFrame frame);
}

class UnavailableSaucerDetector implements SaucerDetector {
  const UnavailableSaucerDetector();

  @override
  bool get isAvailable => false;

  @override
  Future<SaucerDetectionResult?> detect(AnalysisFrame frame) async => null;
}

class LightSaucerDetector implements SaucerDetector {
  const LightSaucerDetector(this.config);

  final CoffeeCameraConfig config;

  @override
  bool get isAvailable => true;

  @override
  Future<SaucerDetectionResult?> detect(AnalysisFrame frame) async {
    final transform = frame.previewTransform;
    if (transform == null || transform.viewportSize.isEmpty) return null;
    final target = TargetGeometry.forSaucer(
      transform.viewportSize,
      config.saucerConfig,
    );
    return Isolate.run(
      () => _detectLightSaucer(
        frame,
        target.center.dx,
        target.center.dy,
        target.radius,
        config.saucerConfig.minimumSaucerConfidence,
      ),
    );
  }
}

SaucerDetectionResult? _detectLightSaucer(
  AnalysisFrame frame,
  double targetX,
  double targetY,
  double targetRadius,
  double minimumConfidence,
) {
  final transform = frame.previewTransform;
  if (transform == null || targetRadius <= 0) return null;
  final sampler = FramePixelSampler(frame);
  _SaucerCandidate? best;
  const centerOffsets = <double>[-0.16, -0.08, 0, 0.08, 0.16];
  const radiusRatios = <double>[0.68, 0.76, 0.84, 0.92, 1.00, 1.08, 1.16, 1.24];
  const verticalRatios = <double>[0.90, 0.95, 1.0];
  const angleSamples = 48;

  for (final offsetY in centerOffsets) {
    for (final offsetX in centerOffsets) {
      final center = Offset(
        targetX + offsetX * targetRadius,
        targetY + offsetY * targetRadius,
      );
      for (final radiusRatio in radiusRatios) {
        final radiusX = targetRadius * radiusRatio;
        for (final verticalRatio in verticalRatios) {
          final radiusY = radiusX * verticalRatio;
          var visibleSamples = 0;
          var edgeSamples = 0;
          var outermostSamples = 0;
          var edgeStrengthTotal = 0.0;
          for (var index = 0; index < angleSamples; index++) {
            final angle = math.pi * 2 * index / angleSamples;
            final targetDirection = Offset(
              math.cos(angle) * targetRadius,
              math.sin(angle) * targetRadius * verticalRatio,
            );
            final innerDeep = sampler.sampleViewport(
              center + targetDirection * (radiusRatio - 0.12),
            );
            final innerEdge = sampler.sampleViewport(
              center + targetDirection * (radiusRatio - 0.035),
            );
            final outerEdge = sampler.sampleViewport(
              center + targetDirection * (radiusRatio + 0.035),
            );
            final outerFar = sampler.sampleViewport(
              center + targetDirection * (radiusRatio + 0.12),
            );
            if (innerDeep == null ||
                innerEdge == null ||
                outerEdge == null ||
                outerFar == null) {
              continue;
            }
            visibleSamples++;
            final edgeStrength = _colorDistance(innerEdge, outerEdge);
            final innerVariation = _colorDistance(innerDeep, innerEdge);
            final outerVariation = _colorDistance(outerEdge, outerFar);
            if (edgeStrength < 12 ||
                outerVariation > edgeStrength * 0.90 + 5 ||
                edgeStrength < innerVariation * 0.55) {
              continue;
            }
            edgeSamples++;
            edgeStrengthTotal += edgeStrength;

            var strongerOuterEdge = false;
            for (
              var outerRatio = radiusRatio + 0.14;
              outerRatio <= 1.30;
              outerRatio += 0.08
            ) {
              final before = sampler.sampleViewport(
                center + targetDirection * (outerRatio - 0.025),
              );
              final after = sampler.sampleViewport(
                center + targetDirection * (outerRatio + 0.025),
              );
              if (before == null || after == null) continue;
              final outerStrength = _colorDistance(before, after);
              if (outerStrength >= math.max(12, edgeStrength * 0.72)) {
                strongerOuterEdge = true;
                break;
              }
            }
            if (!strongerOuterEdge) outermostSamples++;
          }
          if (visibleSamples < 42 || edgeSamples == 0) continue;
          final continuity = edgeSamples / visibleSamples;
          final outermostContinuity = outermostSamples / edgeSamples;
          final meanEdgeStrength = edgeStrengthTotal / edgeSamples;
          if (continuity < 0.48 ||
              outermostContinuity < 0.70 ||
              meanEdgeStrength < 15) {
            continue;
          }

          final edgeScore = (meanEdgeStrength / 70).clamp(0.0, 1.0);
          final centerDistance = (center - Offset(targetX, targetY)).distance;
          final centerScore = (1 - centerDistance / (targetRadius * 0.24))
              .clamp(0.0, 1.0);
          final radiusScore = (1 - (radiusRatio - 0.96).abs() / 0.56).clamp(
            0.0,
            1.0,
          );
          final roundnessScore = ((verticalRatio - 0.88) / 0.12).clamp(
            0.0,
            1.0,
          );
          final confidence =
              (continuity * 0.46 +
                      edgeScore * 0.24 +
                      outermostContinuity * 0.16 +
                      centerScore * 0.06 +
                      radiusScore * 0.04 +
                      roundnessScore * 0.04)
                  .clamp(0.0, 1.0);
          final candidate = _SaucerCandidate(
            center: center,
            radiusX: radiusX,
            radiusY: radiusY,
            radiusRatio: radiusRatio,
            confidence: confidence,
          );
          if (best == null ||
              candidate.confidence > best.confidence + 0.01 ||
              ((candidate.confidence - best.confidence).abs() <= 0.01 &&
                  candidate.radiusRatio > best.radiusRatio)) {
            best = candidate;
          }
        }
      }
    }
  }

  if (best == null || best.confidence < minimumConfidence) return null;
  final viewport = transform.viewportSize;
  final bounds = Rect.fromCenter(
    center: best.center,
    width: best.radiusX * 2,
    height: best.radiusY * 2,
  );
  return SaucerDetectionResult(
    confidence: best.confidence,
    normalizedBounds: Rect.fromLTRB(
      bounds.left / viewport.width,
      bounds.top / viewport.height,
      bounds.right / viewport.width,
      bounds.bottom / viewport.height,
    ),
  );
}

double _colorDistance(FramePixel first, FramePixel second) {
  return (first.luminance - second.luminance).abs() +
      (first.chromaU - second.chromaU).abs() * 0.32 +
      (first.chromaV - second.chromaV).abs() * 0.32;
}

class _SaucerCandidate {
  const _SaucerCandidate({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.radiusRatio,
    required this.confidence,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final double radiusRatio;
  final double confidence;
}
