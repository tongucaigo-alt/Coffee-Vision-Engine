import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/analysis/coffee_detection_stabilizer.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/coffee_region_mask.dart';
import 'package:coffee_camera/src/models/cup_detection_result.dart';
import 'package:coffee_camera/src/models/frame_analysis_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'activates after three good frames and releases after two bad frames',
    () {
      final stabilizer = CoffeeDetectionStabilizer(const CoffeeCameraConfig());
      final good = _result(valid: true);
      final bad = _result(valid: false);

      expect(stabilizer.update(good).coffeeDetected, isFalse);
      expect(stabilizer.update(good).coffeeDetected, isFalse);
      final activated = stabilizer.update(good);
      expect(activated.coffeeDetected, isTrue);
      final held = stabilizer.update(bad);
      expect(held.coffeeDetected, isTrue);
      expect(identical(held.coffeeMask, activated.coffeeMask), isTrue);
      final released = stabilizer.update(bad);
      expect(released.coffeeDetected, isFalse);
      expect(released.coffeeMask, isNull);
    },
  );

  test('a failed frame resets activation progress', () {
    final stabilizer = CoffeeDetectionStabilizer(const CoffeeCameraConfig());
    expect(stabilizer.update(_result(valid: true)).coffeeDetected, isFalse);
    expect(stabilizer.update(_result(valid: false)).coffeeDetected, isFalse);
    expect(stabilizer.update(_result(valid: true)).coffeeDetected, isFalse);
    expect(stabilizer.update(_result(valid: true)).coffeeDetected, isFalse);
    expect(stabilizer.update(_result(valid: true)).coffeeDetected, isTrue);
  });
}

FrameAnalysisResult _result({required bool valid}) {
  final values = Uint8List(32 * 32);
  if (valid) values.fillRange(200, 340, 220);
  final mask = CoffeeRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.25),
    width: 32,
    height: 32,
    intensities: values,
    coverage: valid ? 0.22 : 0,
  );
  return FrameAnalysisResult(
    cupAnalysisAvailable: true,
    cup: valid
        ? const CupDetectionResult(
            confidence: 0.9,
            normalizedBounds: Rect.fromLTWH(0.25, 0.25, 0.5, 0.35),
          )
        : null,
    brightness: 0.6,
    sharpness: 0.6,
    darkPixelRatio: valid ? 0.22 : 0,
    coffeePresenceScore: valid ? 0.4 : 0,
    coffeeMask: valid ? mask : null,
    angleDegrees: 0,
    isStable: true,
    timestamp: DateTime(2026),
  );
}
