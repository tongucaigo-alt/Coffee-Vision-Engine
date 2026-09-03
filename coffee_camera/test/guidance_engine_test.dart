import 'dart:ui';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/guidance/guidance_engine.dart';
import 'package:coffee_camera/src/models/cup_detection_result.dart';
import 'package:coffee_camera/src/models/frame_analysis_result.dart';
import 'package:coffee_camera/src/quality/quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const viewport = Size(1000, 1600);
  const checker = QualityChecker();
  const guidance = GuidanceEngine();

  String message(FrameAnalysisResult result) {
    final assessment = checker.assess(
      result: result,
      viewportSize: viewport,
      config: config,
    );
    return guidance.message(
      result: result,
      assessment: assessment,
      config: config,
    );
  }

  FrameAnalysisResult frame({
    CupDetectionResult? cup,
    double brightness = 0.7,
    double sharpness = 0.7,
    double angle = 0,
  }) {
    return FrameAnalysisResult(
      cupAnalysisAvailable: true,
      cup: cup,
      brightness: brightness,
      sharpness: sharpness,
      darkPixelRatio: 0.24,
      coffeePresenceScore: 0.36,
      angleDegrees: angle,
      isStable: true,
      timestamp: DateTime(2026),
    );
  }

  const goodCup = CupDetectionResult(
    confidence: 0.95,
    normalizedBounds: Rect.fromLTRB(0.212, 0.24, 0.788, 0.60),
  );

  test('asks for a cup before reporting other quality issues', () {
    expect(message(frame(brightness: 0.1)), config.strings.bringCupToTarget);
  });

  test('prioritizes low light over centering', () {
    const leftCup = CupDetectionResult(
      confidence: 0.95,
      normalizedBounds: Rect.fromLTRB(0.05, 0.24, 0.626, 0.60),
    );
    expect(
      message(frame(cup: leftCup, brightness: 0.1)),
      config.strings.lowLight,
    );
  });

  test('tells the user to move a left-side cup to the right', () {
    const leftCup = CupDetectionResult(
      confidence: 0.95,
      normalizedBounds: Rect.fromLTRB(0.05, 0.24, 0.626, 0.60),
    );
    expect(message(frame(cup: leftCup)), config.strings.moveRight);
  });

  test('reports ready when all conditions pass', () {
    expect(message(frame(cup: goodCup)), config.strings.readyHoldStill);
  });

  test('asks for more distance when a centered cup is too large', () {
    const largeCup = CupDetectionResult(
      confidence: 0.95,
      normalizedBounds: Rect.fromLTRB(0.14, 0.195, 0.86, 0.645),
    );
    expect(message(frame(cup: largeCup)), config.strings.moveFarther);
  });
}
