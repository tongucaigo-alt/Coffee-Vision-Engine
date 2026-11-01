import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/analysis/coffee_detection_stabilizer.dart';
import 'package:coffee_camera/src/capture/auto_capture_readiness.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/coffee_region_mask.dart';
import 'package:coffee_camera/src/models/cup_detection_result.dart';
import 'package:coffee_camera/src/models/frame_analysis_result.dart';
import 'package:coffee_camera/src/quality/quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const checker = QualityChecker();
  bool hard(FrameAnalysisResult frame, {bool? coffeeValid}) =>
      requiresAutoCaptureReset(
        analysis: frame,
        assessment: checker.assess(
          result: frame,
          viewportSize: const Size(360, 800),
          config: config,
        ),
        config: config,
        currentCoffeeValid:
            coffeeValid ??
            CoffeeDetectionStabilizer(config).isCurrentValid(frame),
      );

  for (final entry in {
    'movement': _frame().copyWith(isStable: false),
    'borderline light': _frame().copyWith(brightness: .27),
    'borderline focus': _frame().copyWith(sharpness: .29),
    'slightly wrong angle': _frame().copyWith(angleDegrees: 13),
    'slightly small cup': _frame().copyWith(
      cup: const CupDetectionResult(
        confidence: .95,
        normalizedBounds: Rect.fromLTWH(.29, .3255, .42, .189),
      ),
    ),
  }.entries) {
    test('${entry.key} can pause but cannot authorize a photograph', () {
      final assessment = checker.assess(
        result: entry.value,
        viewportSize: const Size(360, 800),
        config: config,
      );
      expect(assessment.autoCaptureReady, false);
      expect(hard(entry.value), false);
    });
  }

  for (final entry in {
    'darkness': _frame().copyWith(brightness: .20),
    'blur': _frame().copyWith(sharpness: .20),
    'cup absent': _frame().copyWith(clearCup: true),
    'cup unconfident': _frame().copyWith(
      cup: const CupDetectionResult(
        confidence: .4,
        normalizedBounds: Rect.fromLTWH(.212, .2904, .576, .2592),
      ),
    ),
    'cup clipped at screen edge': _frame().copyWith(
      cup: const CupDetectionResult(
        confidence: .95,
        normalizedBounds: Rect.fromLTWH(0, .29, .576, .2592),
      ),
    ),
    'coffee lost': _frame().copyWith(coffeeDetected: false),
    'raw mask missing': _frame().copyWith(clearCoffeeMask: true),
    'nonfinite light': _frame().copyWith(brightness: double.nan),
    'nonfinite focus': _frame().copyWith(sharpness: double.infinity),
  }.entries) {
    test('${entry.key} immediately resets progress', () {
      expect(hard(entry.value), true);
    });
  }
  test('a held old mask cannot replace current coffee detection', () {
    expect(hard(_frame(), coffeeValid: false), true);
  });
  test('fully ready frame keeps the original quality thresholds', () {
    final frame = _frame();
    expect(
      checker
          .assess(
            result: frame,
            viewportSize: const Size(360, 800),
            config: config,
          )
          .autoCaptureReady,
      true,
    );
    expect(hard(frame), false);
  });
}

FrameAnalysisResult _frame() => FrameAnalysisResult(
  cupAnalysisAvailable: true,
  cup: const CupDetectionResult(
    confidence: .95,
    normalizedBounds: Rect.fromLTWH(.212, .2904, .576, .2592),
  ),
  brightness: .6,
  sharpness: .6,
  darkPixelRatio: .22,
  coffeePresenceScore: .4,
  coffeeDetected: true,
  coffeeMask: CoffeeRegionMask(
    normalizedBounds: const Rect.fromLTWH(.3, .3, .4, .25),
    width: 6,
    height: 6,
    intensities: Uint8List(36)..fillRange(0, 36, 210),
    coverage: .22,
  ),
  angleDegrees: 0,
  isStable: true,
  timestamp: DateTime(2026),
);
