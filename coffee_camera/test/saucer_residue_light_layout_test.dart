import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:coffee_camera/src/ui/saucer_residue_light_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects deterministic cell centers and enforces the maximum', () {
    final mask = _mask(activeCells: 140);

    final first = buildSaucerResidueLights(mask);
    final second = buildSaucerResidueLights(mask);

    expect(first, hasLength(64));
    expect(
      first.map((light) => light.cellIndex),
      orderedEquals(second.map((light) => light.cellIndex)),
    );
    expect(
      first.map((light) => light.normalizedPosition),
      orderedEquals(second.map((light) => light.normalizedPosition)),
    );
    for (final light in first) {
      final row = light.cellIndex ~/ mask.width;
      final column = light.cellIndex % mask.width;
      expect(
        light.normalizedPosition.dx,
        closeTo(
          mask.normalizedBounds.left +
              mask.normalizedBounds.width * (column + 0.5) / mask.width,
          1e-9,
        ),
      );
      expect(
        light.normalizedPosition.dy,
        closeTo(
          mask.normalizedBounds.top +
              mask.normalizedBounds.height * (row + 0.5) / mask.height,
          1e-9,
        ),
      );
    }
  });

  test('does not expose a sparse mask below the visual minimum', () {
    expect(buildSaucerResidueLights(_mask(activeCells: 19)), isEmpty);
    expect(buildSaucerResidueLights(_mask(activeCells: 20)), hasLength(20));
  });

  test('keeps selected lights inside residue bounds and limits sparkles', () {
    final mask = _mask(activeCells: 96, intensity: 250);
    final lights = buildSaucerResidueLights(mask);

    expect(
      lights.every(
        (light) => mask.residueBounds!.contains(light.normalizedPosition),
      ),
      isTrue,
    );
    expect(
      lights.where((light) => light.sparkleEligible).length,
      lessThanOrEqualTo(4),
    );
  });
}

ResidueRegionMask _mask({required int activeCells, int intensity = 210}) {
  final values = Uint8List(32 * 32);
  values.fillRange(0, activeCells.clamp(0, values.length), intensity);
  return ResidueRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.8, 0.4),
    width: 32,
    height: 32,
    intensities: values,
    coverage: activeCells / (32 * 32),
    residueBounds: const Rect.fromLTWH(0.1, 0.2, 0.8, 0.4),
    componentCount: activeCells == 0 ? 0 : 1,
  );
}
