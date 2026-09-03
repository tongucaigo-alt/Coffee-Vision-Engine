import 'dart:ui';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/cup_detection_result.dart';
import 'package:coffee_camera/src/models/frame_analysis_result.dart';
import 'package:coffee_camera/src/quality/quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(1000, 1600);
  const config = CoffeeCameraConfig();
  const checker = QualityChecker();

  FrameAnalysisResult result({
    Rect? bounds,
    double brightness = 0.7,
    double sharpness = 0.7,
    double angle = 0,
    bool stable = true,
  }) {
    return FrameAnalysisResult(
      cupAnalysisAvailable: true,
      cup: CupDetectionResult(
        confidence: 0.95,
        normalizedBounds:
            bounds ?? const Rect.fromLTRB(0.212, 0.24, 0.788, 0.60),
      ),
      brightness: brightness,
      sharpness: sharpness,
      darkPixelRatio: 0.24,
      coffeePresenceScore: 0.36,
      angleDegrees: angle,
      isStable: stable,
      timestamp: DateTime(2026),
    );
  }

  test('calculates a perfect score and allows automatic capture', () {
    final assessment = checker.assess(
      result: result(),
      viewportSize: viewport,
      config: config,
    );

    expect(assessment.score, 100);
    expect(assessment.centered, isTrue);
    expect(assessment.rightSize, isTrue);
    expect(assessment.contained, isTrue);
    expect(assessment.autoCaptureReady, isTrue);
  });

  test('rejects a cup outside the center tolerance', () {
    final assessment = checker.assess(
      result: result(bounds: const Rect.fromLTRB(0.05, 0.24, 0.626, 0.60)),
      viewportSize: viewport,
      config: config,
    );

    expect(assessment.centered, isFalse);
    expect(assessment.autoCaptureReady, isFalse);
  });

  test('rejects a cup with the wrong diameter ratio', () {
    final assessment = checker.assess(
      result: result(bounds: const Rect.fromLTRB(0.35, 0.32625, 0.65, 0.51375)),
      viewportSize: viewport,
      config: config,
    );

    expect(assessment.cupDiameterRatio, closeTo(0.4167, 0.01));
    expect(assessment.rightSize, isFalse);
    expect(assessment.autoCaptureReady, isFalse);
  });

  test('critical low light blocks capture even when score is at least 85', () {
    final assessment = checker.assess(
      result: result(brightness: 0.1),
      viewportSize: viewport,
      config: config,
    );

    expect(assessment.score, 90);
    expect(assessment.autoCaptureReady, isFalse);
  });

  test('screen clipping blocks capture', () {
    final assessment = checker.assess(
      result: result(bounds: const Rect.fromLTRB(0, 0.24, 0.576, 0.60)),
      viewportSize: viewport,
      config: config,
    );

    expect(assessment.notClipped, isFalse);
    expect(assessment.autoCaptureReady, isFalse);
  });
}
