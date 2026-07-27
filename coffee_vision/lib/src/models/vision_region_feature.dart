import 'vision_analysis_region.dart';
import 'vision_geometry.dart';

/// Immutable physical residue measurement for one canonical analysis region.
final class VisionRegionFeature {
  VisionRegionFeature({
    required this.regionId,
    required VisionRect rect,
    required double residueDensity,
  }) : rect = _validatedRect(rect),
       residueDensity = _validatedDensity(residueDensity);

  final VisionRegionId regionId;
  final VisionRect rect;
  final double residueDensity;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionRegionFeature &&
            other.regionId == regionId &&
            other.rect == rect &&
            other.residueDensity == residueDensity;
  }

  @override
  int get hashCode => Object.hash(regionId, rect, residueDensity);

  @override
  String toString() {
    return 'VisionRegionFeature(regionId: $regionId, rect: $rect, '
        'residueDensity: $residueDensity)';
  }

  static VisionRect _validatedRect(VisionRect value) {
    if (value.width <= 0.0 || value.height <= 0.0) {
      throw ArgumentError.value(
        value,
        'rect',
        'must have positive width and height',
      );
    }
    return value;
  }

  static double _validatedDensity(double value) {
    if (!value.isFinite || value < 0.0 || value > 1.0) {
      throw ArgumentError.value(
        value,
        'residueDensity',
        'must be finite and between 0.0 and 1.0',
      );
    }
    return value;
  }
}
