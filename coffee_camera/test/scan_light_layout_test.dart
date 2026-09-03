import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/models/coffee_region_mask.dart';
import 'package:coffee_camera/src/ui/scan_light_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects 24 to 48 lights only from active coffee-mask cells', () {
    final values = Uint8List(32 * 32);
    for (var row = 8; row < 24; row++) {
      for (var column = 7; column < 25; column++) {
        if ((row + column).isEven) values[row * 32 + column] = 210;
      }
    }
    final mask = CoffeeRegionMask(
      normalizedBounds: const Rect.fromLTWH(0.2, 0.25, 0.6, 0.4),
      width: 32,
      height: 32,
      intensities: values,
      coverage: 0.25,
    );

    final lights = buildScanLights(mask);
    expect(lights.length, inInclusiveRange(24, 48));
    for (final light in lights) {
      final column =
          ((light.normalizedPosition.dx - mask.normalizedBounds.left) /
                  mask.normalizedBounds.width *
                  mask.width)
              .floor();
      final row =
          ((light.normalizedPosition.dy - mask.normalizedBounds.top) /
                  mask.normalizedBounds.height *
                  mask.height)
              .floor();
      expect(mask.intensityAt(column, row), greaterThanOrEqualTo(48));
    }
  });

  test('does not build an effect from a sparse mask', () {
    final values = Uint8List(32 * 32)..fillRange(0, 12, 255);
    final mask = CoffeeRegionMask(
      normalizedBounds: const Rect.fromLTWH(0.2, 0.25, 0.6, 0.4),
      width: 32,
      height: 32,
      intensities: values,
      coverage: 0.01,
    );
    expect(buildScanLights(mask), isEmpty);
  });
}
