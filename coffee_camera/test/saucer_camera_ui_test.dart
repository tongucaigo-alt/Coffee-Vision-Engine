import 'dart:typed_data';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/coffee_region_mask.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/camera_target_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saucer target is larger than the unchanged cup target', () {
    const size = Size(360, 800);
    const config = CoffeeCameraConfig();
    final cup = TargetGeometry.fromViewport(size, config);
    final saucer = TargetGeometry.forSaucer(size, config.saucerConfig);

    expect(saucer.radius, greaterThan(cup.radius));
    expect(cup.radius, closeTo(129.6, 0.001));
    expect(saucer.radius, closeTo(154.8, 0.001));
  });

  testWidgets('saucer target renders its own effect without cup particles', (
    tester,
  ) async {
    const size = Size(360, 800);
    const config = CoffeeCameraConfig();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.fromSize(
          size: size,
          child: CameraTargetOverlay(
            config: config,
            effectProfile: CaptureEffectProfile.saucer,
            ringColor: config.theme.readyRing,
            isReady: true,
            subjectDetected: true,
            saucerSweepProgress: 0.4,
            coffeeDetected: true,
            coffeeMask: CoffeeRegionMask(
              normalizedBounds: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.4),
              width: 32,
              height: 32,
              intensities: Uint8List(32 * 32)..fillRange(0, 256, 220),
              coverage: 0.25,
            ),
            targetGeometry: TargetGeometry.forSaucer(size, config.saucerConfig),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('coffee-camera-target-overlay')), findsOne);
    expect(
      find.byKey(const Key('coffee-camera-saucer-sweep-effect')),
      findsOne,
    );
    expect(find.byKey(const Key('coffee-camera-scan-effect')), findsNothing);
  });
}
