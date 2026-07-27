import 'vision_geometry.dart';
import 'vision_image_input.dart';

/// Identifies one of the fixed analysis bands within a working image.
///
/// [middle] is the horizontal center band, while [center] is the vertical
/// center band. Horizontal and vertical bands intentionally overlap.
enum VisionRegionId { top, middle, bottom, left, center, right }

/// A normalized analysis region associated with one vision surface.
final class VisionAnalysisRegion {
  const VisionAnalysisRegion({
    required this.id,
    required this.rect,
    required this.surfaceType,
  });

  final VisionRegionId id;
  final VisionRect rect;
  final VisionSurfaceType surfaceType;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionAnalysisRegion &&
            other.id == id &&
            other.rect == rect &&
            other.surfaceType == surfaceType;
  }

  @override
  int get hashCode => Object.hash(id, rect, surfaceType);

  @override
  String toString() {
    return 'VisionAnalysisRegion(id: $id, rect: $rect, '
        'surfaceType: $surfaceType)';
  }
}
