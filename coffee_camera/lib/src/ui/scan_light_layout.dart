import 'dart:ui';

import '../models/coffee_region_mask.dart';

class ScanLight {
  const ScanLight({required this.normalizedPosition, required this.intensity});

  final Offset normalizedPosition;
  final double intensity;
}

List<ScanLight> buildScanLights(
  CoffeeRegionMask? mask, {
  int minimumLights = 24,
  int maximumLights = 48,
}) {
  if (mask == null) return const [];
  final candidates = <ScanLight>[];
  for (var row = 0; row < mask.height; row++) {
    for (var column = 0; column < mask.width; column++) {
      final value = mask.intensityAt(column, row);
      if (value < 48) continue;
      candidates.add(
        ScanLight(
          normalizedPosition: mask.normalizedPointFor(column, row),
          intensity: value / 255,
        ),
      );
    }
  }
  if (candidates.length < minimumLights) return const [];
  if (candidates.length <= maximumLights) return candidates;
  final selected = <ScanLight>[];
  final step = candidates.length / maximumLights;
  for (var index = 0; index < maximumLights; index++) {
    selected.add(candidates[((index + 0.5) * step).floor()]);
  }
  return selected;
}
