import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/analysis_frame.dart';
import '../models/cup_detection_result.dart';
import '../models/target_geometry.dart';
import 'frame_pixel_sampler.dart';

abstract interface class CupDetector {
  bool get isAvailable;

  Future<CupDetectionResult?> detect(AnalysisFrame frame);
}

class UnavailableCupDetector implements CupDetector {
  const UnavailableCupDetector();

  @override
  bool get isAvailable => false;

  @override
  Future<CupDetectionResult?> detect(AnalysisFrame frame) async => null;
}

class LightCupDetector implements CupDetector {
  const LightCupDetector(this.config);

  final CoffeeCameraConfig config;

  @override
  bool get isAvailable => true;

  @override
  Future<CupDetectionResult?> detect(AnalysisFrame frame) async {
    final transform = frame.previewTransform;
    if (transform == null || transform.viewportSize.isEmpty) return null;
    final target = TargetGeometry.fromViewport(transform.viewportSize, config);
    return Isolate.run(
      () => _detectLightCup(
        frame,
        target.center.dx,
        target.center.dy,
        target.radius,
        config.minimumCupConfidence,
      ),
    );
  }
}

CupDetectionResult? _detectLightCup(
  AnalysisFrame frame,
  double targetX,
  double targetY,
  double targetRadius,
  double minimumConfidence,
) {
  final transform = frame.previewTransform;
  if (transform == null || targetRadius <= 0) return null;
  final sampler = FramePixelSampler(frame);
  _CupCandidate? best;
  const centerOffsets = <double>[-0.12, -0.06, 0, 0.06, 0.12];
  const radiusRatios = <double>[0.58, 0.64, 0.70, 0.76, 0.82, 0.88, 0.94];

  for (final offsetY in centerOffsets) {
    for (final offsetX in centerOffsets) {
      final center = Offset(
        targetX + offsetX * targetRadius,
        targetY + offsetY * targetRadius,
      );
      for (final radiusRatio in radiusRatios) {
        final radius = targetRadius * radiusRatio;
        var visibleSamples = 0;
        var continuousSamples = 0;
        var rimTotal = 0.0;
        var contrastTotal = 0.0;
        const angleSamples = 64;
        for (var index = 0; index < angleSamples; index++) {
          final angle = math.pi * 2 * index / angleSamples;
          final direction = Offset(math.cos(angle), math.sin(angle));
          final inner = sampler.sampleViewport(
            center + direction * radius * 0.78,
          );
          final rim = sampler.sampleViewport(
            center + direction * radius * 0.96,
          );
          final outer = sampler.sampleViewport(
            center + direction * radius * 1.08,
          );
          if (inner == null || rim == null || outer == null) continue;
          visibleSamples++;
          final innerContrast = rim.luminance - inner.luminance;
          final outerContrast = rim.luminance - outer.luminance;
          rimTotal += rim.luminance;
          contrastTotal +=
              math.max(0, innerContrast) + math.max(0, outerContrast) * 0.25;
          if (rim.luminance >= 142 &&
              innerContrast >= 11 &&
              outerContrast >= -18) {
            continuousSamples++;
          }
        }
        if (visibleSamples < 56) continue;
        final continuity = continuousSamples / visibleSamples;
        final meanRim = rimTotal / visibleSamples;
        final meanContrast = contrastTotal / visibleSamples;
        if (continuity < 0.48 || meanRim < 142 || meanContrast < 10) {
          continue;
        }
        final contrastScore = (meanContrast / 42).clamp(0.0, 1.0);
        final brightnessScore = ((meanRim - 128) / 92).clamp(0.0, 1.0);
        final centerDistance = (center - Offset(targetX, targetY)).distance;
        final centerScore = (1 - centerDistance / (targetRadius * 0.22)).clamp(
          0.0,
          1.0,
        );
        final radiusScore = (1 - (radiusRatio - 0.76).abs() / 0.28).clamp(
          0.0,
          1.0,
        );
        final confidence =
            (continuity * 0.52 +
                    contrastScore * 0.20 +
                    brightnessScore * 0.16 +
                    centerScore * 0.07 +
                    radiusScore * 0.05)
                .clamp(0.0, 1.0);
        final candidate = _CupCandidate(
          center: center,
          radius: radius,
          confidence: confidence,
        );
        if (best == null || candidate.confidence > best.confidence) {
          best = candidate;
        }
      }
    }
  }

  if (best == null || best.confidence < minimumConfidence) return null;
  final viewport = transform.viewportSize;
  final bounds = Rect.fromCircle(center: best.center, radius: best.radius);
  return CupDetectionResult(
    confidence: best.confidence,
    normalizedBounds: Rect.fromLTRB(
      bounds.left / viewport.width,
      bounds.top / viewport.height,
      bounds.right / viewport.width,
      bounds.bottom / viewport.height,
    ),
  );
}

class _CupCandidate {
  const _CupCandidate({
    required this.center,
    required this.radius,
    required this.confidence,
  });

  final Offset center;
  final double radius;
  final double confidence;
}
