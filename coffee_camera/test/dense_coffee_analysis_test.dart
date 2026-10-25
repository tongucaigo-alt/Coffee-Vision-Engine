import 'dart:ui';

import 'package:coffee_camera/src/analysis/coffee_detection_stabilizer.dart';
import 'package:coffee_camera/src/analysis/coffee_region_analyzer.dart';
import 'package:coffee_camera/src/analysis/cup_detector.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/analysis_frame.dart';
import 'package:coffee_camera/src/models/cup_detection_result.dart';
import 'package:coffee_camera/src/models/frame_analysis_result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dense_coffee_scene.dart';

void main() {
  const config = CoffeeCameraConfig(
    coffeeActivationFrames: 2,
    coffeeReleaseFrames: 3,
  );
  const detector = LightCupDetector(config);
  const analyzer = CoffeeRegionAnalyzer();
  for (final level in [60, 125]) {
    test(
      'dense textured brown grounds work with little white at level $level',
      () async {
        final frame = denseCoffeeScene(luminance: level);
        final cup = await detector.detect(frame);
        expect(cup, isNotNull);
        final coffee = await analyzer.analyze(
          frame: frame,
          cup: cup,
          config: config,
        );
        final result = _result(coffee, cup);
        final stabilizer = CoffeeDetectionStabilizer(config);
        expect(stabilizer.isCurrentValid(result), true);
        expect(coffee.mask!.requiresStrictPhotoVerification, true);
        expect(stabilizer.update(result).coffeeDetected, false);
        final active = stabilizer.update(
          result.copyWith(
            timestamp: result.timestamp.add(const Duration(milliseconds: 250)),
          ),
        );
        expect(active.coffeeDetected, true);
        expect(active.coffeeMask!.requiresStrictPhotoVerification, true);
        // Every visible point comes from a real accepted cell, inside the disk.
        final mask = coffee.mask!;
        for (var row = 0; row < mask.height; row++) {
          for (var column = 0; column < mask.width; column++) {
            if (mask.intensityAt(column, row) == 0) continue;
            final x = ((column + .5) / mask.width - .5) * 2;
            final y = ((row + .5) / mask.height - .5) * 2;
            expect(x * x + y * y, lessThanOrEqualTo(1));
          }
        }
        final expired = stabilizer.update(
          result.copyWith(
            timestamp: active.timestamp.add(const Duration(milliseconds: 750)),
            coffeePresenceScore: 0,
            clearCoffeeMask: true,
          ),
        );
        expect(expired.coffeeDetected, false);
        expect(expired.coffeeMask, isNull);
      },
    );
  }
  for (final entry in <String, AnalysisFrame>{
    'flat brown surface': denseCoffeeScene(textured: false),
    'smooth brown shadow': denseCoffeeScene(
      textured: false,
      smoothShadow: true,
    ),
    'grey textured surface': denseCoffeeScene(chromaU: 128, chromaV: 128),
    'blue textured surface': denseCoffeeScene(chromaU: 160, chromaV: 110),
    'sensor black': denseCoffeeScene(luminance: 8),
    'dark rim': denseCoffeeScene(lightRim: false),
  }.entries) {
    test('dense fallback rejects ${entry.key}', () async {
      // A supplied candidate also checks the rim/chroma guard independently
      // of the detector, rather than passing merely because it returned null.
      const candidate = CupDetectionResult(
        confidence: .9,
        normalizedBounds: Rect.fromLTRB(
          74 / 360,
          230 / 800,
          286 / 360,
          442 / 800,
        ),
      );
      final coffee = await analyzer.analyze(
        frame: entry.value,
        cup: candidate,
        config: config,
      );
      expect(
        CoffeeDetectionStabilizer(
          config,
        ).isCurrentValid(_result(coffee, candidate)),
        false,
      );
      expect(coffee.mask?.requiresStrictPhotoVerification ?? false, false);
    });
  }
  test('dense grounds still require a current confident cup', () async {
    final frame = denseCoffeeScene();
    for (final cup in <CupDetectionResult?>[
      null,
      const CupDetectionResult(
        confidence: .3,
        normalizedBounds: Rect.fromLTWH(.2, .2, .6, .5),
      ),
    ]) {
      final coffee = await analyzer.analyze(
        frame: frame,
        cup: cup,
        config: config,
      );
      expect(coffee.mask, isNull);
      expect(coffee.score, 0);
    }
  });
}

FrameAnalysisResult _result(
  CoffeeRegionAnalysis coffee,
  CupDetectionResult? cup,
) => FrameAnalysisResult(
  cupAnalysisAvailable: true,
  cup: cup,
  brightness: .6,
  sharpness: .6,
  darkPixelRatio: coffee.coverage,
  coffeePresenceScore: coffee.score,
  coffeeMask: coffee.mask,
  angleDegrees: 0,
  isStable: true,
  timestamp: DateTime(2026),
);
