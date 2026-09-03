import 'dart:ui';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/guidance/saucer_guidance_engine.dart';
import 'package:coffee_camera/src/models/saucer_analysis_result.dart';
import 'package:coffee_camera/src/models/saucer_detection_result.dart';
import 'package:coffee_camera/src/quality/saucer_quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const checker = SaucerQualityChecker();
  const guidance = SaucerGuidanceEngine();

  test('guides small and oversized saucers by their outer diameter', () {
    final small = _state(const Rect.fromLTWH(0.1775, 0.2749, 0.645, 0.2902));
    final large = _state(const Rect.fromLTWH(0.0356, 0.2110, 0.9288, 0.4180));

    expect(_message(small, checker, guidance), config.strings.moveSaucerCloser);
    expect(
      _message(large, checker, guidance),
      config.strings.moveSaucerFarther,
    );
  });

  test('guides an off-center saucer toward the target center', () {
    final shiftedRight = _state(
      const Rect.fromLTWH(0.192, 0.2418, 0.792, 0.3564),
    );

    expect(
      _message(shiftedRight, checker, guidance),
      config.strings.centerSaucer,
    );
  });

  test('uses one quality message and reports stabilized ready', () {
    final ready = _state(const Rect.fromLTWH(0.104, 0.2418, 0.792, 0.3564));
    final moving = SaucerAnalysisResult(
      analysisAvailable: ready.analysisAvailable,
      saucer: ready.saucer,
      brightness: ready.brightness,
      sharpness: ready.sharpness,
      angleDegrees: ready.angleDegrees,
      isStable: false,
      timestamp: ready.timestamp,
    );

    expect(
      _message(ready, checker, guidance, stabilizedReady: true),
      config.strings.saucerReady,
    );
    expect(_message(moving, checker, guidance), config.strings.holdCameraStill);
  });
}

String _message(
  SaucerAnalysisResult result,
  SaucerQualityChecker checker,
  SaucerGuidanceEngine guidance, {
  bool stabilizedReady = false,
}) {
  final assessment = checker.assess(
    result: result,
    viewportSize: const Size(360, 800),
    config: const CoffeeCameraConfig(),
  );
  return guidance.message(
    result: result,
    assessment: assessment,
    viewportSize: const Size(360, 800),
    config: const CoffeeCameraConfig(),
    stabilizedReady: stabilizedReady,
  );
}

SaucerAnalysisResult _state(Rect bounds) {
  return SaucerAnalysisResult(
    analysisAvailable: true,
    saucer: SaucerDetectionResult(confidence: 0.9, normalizedBounds: bounds),
    brightness: 0.8,
    sharpness: 0.8,
    angleDegrees: 0,
    isStable: true,
    timestamp: DateTime(2026),
  );
}
