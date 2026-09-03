import 'dart:ui';

import '../models/residue_region_mask.dart';

class SaucerResidueLight {
  const SaucerResidueLight({
    required this.cellIndex,
    required this.normalizedPosition,
    required this.intensity,
    required this.sparkleEligible,
  });

  final int cellIndex;
  final Offset normalizedPosition;
  final double intensity;
  final bool sparkleEligible;
}

List<SaucerResidueLight> buildSaucerResidueLights(
  ResidueRegionMask? mask, {
  int minimumCount = 20,
  int maximumCount = 64,
  int maximumSparkles = 4,
  double sparkleIntensityThreshold = 0.90,
}) {
  if (mask == null || minimumCount < 1 || maximumCount < minimumCount) {
    return const [];
  }
  final candidates = <SaucerResidueLight>[];
  for (var row = 0; row < mask.height; row++) {
    for (var column = 0; column < mask.width; column++) {
      final intensityByte = mask.intensityAt(column, row);
      if (intensityByte == 0) continue;
      final point = Offset(
        mask.normalizedBounds.left +
            mask.normalizedBounds.width * (column + 0.5) / mask.width,
        mask.normalizedBounds.top +
            mask.normalizedBounds.height * (row + 0.5) / mask.height,
      );
      final residueBounds = mask.residueBounds;
      if (residueBounds != null && !residueBounds.contains(point)) continue;
      candidates.add(
        SaucerResidueLight(
          cellIndex: row * mask.width + column,
          normalizedPosition: point,
          intensity: intensityByte / 255,
          sparkleEligible: false,
        ),
      );
    }
  }
  if (candidates.length < minimumCount) return const [];

  final selected = candidates.length <= maximumCount
      ? candidates
      : List<SaucerResidueLight>.generate(maximumCount, (index) {
          final sourceIndex = maximumCount == 1
              ? 0
              : (index * (candidates.length - 1) / (maximumCount - 1)).round();
          return candidates[sourceIndex];
        }, growable: false);
  final sparkleCells =
      selected
          .where((light) => light.intensity >= sparkleIntensityThreshold)
          .toList(growable: false)
        ..sort((first, second) {
          final intensityOrder = second.intensity.compareTo(first.intensity);
          return intensityOrder != 0
              ? intensityOrder
              : first.cellIndex.compareTo(second.cellIndex);
        });
  final sparkleCellIds = sparkleCells
      .take(maximumSparkles)
      .map((light) => light.cellIndex)
      .toSet();
  return List<SaucerResidueLight>.unmodifiable(
    selected.map(
      (light) => SaucerResidueLight(
        cellIndex: light.cellIndex,
        normalizedPosition: light.normalizedPosition,
        intensity: light.intensity,
        sparkleEligible: sparkleCellIds.contains(light.cellIndex),
      ),
    ),
  );
}
