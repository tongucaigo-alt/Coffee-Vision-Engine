import 'vision_analysis_region.dart';
import 'vision_image_input.dart';

/// The explainable residue-candidate ratio for one analysis region.
final class VisionRegionDensity {
  VisionRegionDensity({
    required this.regionId,
    required this.surfaceType,
    required double density,
  }) : density = _validatedDensity(density);

  final VisionRegionId regionId;
  final VisionSurfaceType surfaceType;
  final double density;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionRegionDensity &&
            other.regionId == regionId &&
            other.surfaceType == surfaceType &&
            other.density == density;
  }

  @override
  int get hashCode => Object.hash(regionId, surfaceType, density);

  @override
  String toString() {
    return 'VisionRegionDensity(regionId: $regionId, '
        'surfaceType: $surfaceType, density: $density)';
  }
}

double _validatedDensity(double value) {
  if (!value.isFinite || value < 0.0 || value > 1.0) {
    throw ArgumentError.value(value, 'density', 'must be between 0.0 and 1.0');
  }
  return value;
}
