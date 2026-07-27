import 'vision_geometry.dart';

/// Immutable physical measurements projected for one canonical component.
///
/// All fields except [residueShare] are direct values from existing pipeline
/// models. This contract contains no pixel indices, semantic labels, symbols,
/// confidence, or fortune information.
final class VisionComponentFeature {
  VisionComponentFeature({
    required int componentId,
    required int pixelCount,
    required VisionRect boundingBox,
    required VisionPoint centroid,
    required double width,
    required double height,
    required double aspectRatio,
    required double areaRatio,
    required double fillRatio,
    required this.touchesBorder,
    required double residueShare,
    required this.nearestNeighborComponentId,
  }) : componentId = _validatedPositiveInt(componentId, 'componentId'),
       pixelCount = _validatedPositiveInt(pixelCount, 'pixelCount'),
       boundingBox = _validatedBoundingBox(boundingBox),
       centroid = _validatedCentroid(centroid, boundingBox),
       width = _validatedPositiveFinite(width, 'width'),
       height = _validatedPositiveFinite(height, 'height'),
       aspectRatio = _validatedPositiveFinite(aspectRatio, 'aspectRatio'),
       areaRatio = _validatedRatio(areaRatio, 'areaRatio'),
       fillRatio = _validatedRatio(fillRatio, 'fillRatio'),
       residueShare = _validatedRatio(residueShare, 'residueShare') {
    if (this.width != this.boundingBox.width) {
      throw ArgumentError.value(width, 'width', 'must equal boundingBox.width');
    }
    if (this.height != this.boundingBox.height) {
      throw ArgumentError.value(
        height,
        'height',
        'must equal boundingBox.height',
      );
    }
    if (this.aspectRatio != this.width / this.height) {
      throw ArgumentError.value(
        aspectRatio,
        'aspectRatio',
        'must equal width / height',
      );
    }
    final nearestId = nearestNeighborComponentId;
    if (nearestId != null) {
      if (nearestId <= 0) {
        throw ArgumentError.value(
          nearestId,
          'nearestNeighborComponentId',
          'must be greater than zero',
        );
      }
      if (nearestId == this.componentId) {
        throw ArgumentError.value(
          nearestId,
          'nearestNeighborComponentId',
          'must reference a different component',
        );
      }
    }
  }

  final int componentId;
  final int pixelCount;
  final VisionRect boundingBox;
  final VisionPoint centroid;
  final double width;
  final double height;
  final double aspectRatio;
  final double areaRatio;
  final double fillRatio;
  final bool touchesBorder;
  final double residueShare;
  final int? nearestNeighborComponentId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionComponentFeature &&
            other.componentId == componentId &&
            other.pixelCount == pixelCount &&
            other.boundingBox == boundingBox &&
            other.centroid == centroid &&
            other.width == width &&
            other.height == height &&
            other.aspectRatio == aspectRatio &&
            other.areaRatio == areaRatio &&
            other.fillRatio == fillRatio &&
            other.touchesBorder == touchesBorder &&
            other.residueShare == residueShare &&
            other.nearestNeighborComponentId == nearestNeighborComponentId;
  }

  @override
  int get hashCode => Object.hash(
    componentId,
    pixelCount,
    boundingBox,
    centroid,
    width,
    height,
    aspectRatio,
    areaRatio,
    fillRatio,
    touchesBorder,
    residueShare,
    nearestNeighborComponentId,
  );

  @override
  String toString() {
    return 'VisionComponentFeature(componentId: $componentId, '
        'pixelCount: $pixelCount, boundingBox: $boundingBox, '
        'centroid: $centroid, width: $width, height: $height, '
        'aspectRatio: $aspectRatio, areaRatio: $areaRatio, '
        'fillRatio: $fillRatio, touchesBorder: $touchesBorder, '
        'residueShare: $residueShare, '
        'nearestNeighborComponentId: $nearestNeighborComponentId)';
  }

  static int _validatedPositiveInt(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
    return value;
  }

  static VisionRect _validatedBoundingBox(VisionRect value) {
    if (value.width <= 0.0 || value.height <= 0.0) {
      throw ArgumentError.value(
        value,
        'boundingBox',
        'must have positive width and height',
      );
    }
    return value;
  }

  static VisionPoint _validatedCentroid(
    VisionPoint value,
    VisionRect boundingBox,
  ) {
    if (!boundingBox.contains(value)) {
      throw ArgumentError.value(
        value,
        'centroid',
        'must be inside boundingBox',
      );
    }
    return value;
  }

  static double _validatedPositiveFinite(double value, String name) {
    if (!value.isFinite || value <= 0.0) {
      throw ArgumentError.value(
        value,
        name,
        'must be finite and greater than zero',
      );
    }
    return value;
  }

  static double _validatedRatio(double value, String name) {
    if (!value.isFinite || value <= 0.0 || value > 1.0) {
      throw ArgumentError.value(
        value,
        name,
        'must be finite, greater than 0.0, and at most 1.0',
      );
    }
    return value;
  }
}
