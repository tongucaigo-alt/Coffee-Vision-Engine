import 'models.dart';

/// Display-only bounds in the persisted, orientation-corrected full photo.
/// Annotation coordinates are always stored in the full photo's coordinate space.
final class PhotoCrop {
  PhotoCrop(this.x, this.y, this.width, this.height) {
    if (![x, y, width, height].every((value) => value.isFinite) ||
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1 ||
        y + height > 1) {
      throw ArgumentError('Invalid normalized display crop');
    }
  }

  static final full = PhotoCrop(0, 0, 1, 1);
  static const version = 'atlas-display-crop-v1';
  static const coordinateSpace = 'orientedFullPhotoNormalized';

  final double x, y, width, height;

  bool get isFull => x == 0 && y == 0 && width == 1 && height == 1;

  double aspectRatio(int photoWidth, int photoHeight) {
    if (photoWidth <= 0 || photoHeight <= 0) {
      throw ArgumentError('Photo dimensions must be positive');
    }
    return photoWidth * width / (photoHeight * height);
  }

  bool containsBox(RegionBox box) =>
      isFull ||
      (box.x >= x - width * 1e-10 &&
          box.y >= y - height * 1e-10 &&
          box.x + box.width <= x + width + width * 1e-10 &&
          box.y + box.height <= y + height + height * 1e-10);

  RegionBox toFullBox(RegionBox displayBox) => isFull
      ? displayBox
      : RegionBox(
          x + displayBox.x * width,
          y + displayBox.y * height,
          displayBox.width * width,
          displayBox.height * height,
        );

  /// Reject outside regions instead of hiding or clipping saved annotations.
  RegionBox toDisplayBox(RegionBox fullBox) {
    if (isFull) return fullBox;
    if (!containsBox(fullBox)) {
      throw ArgumentError('Region is outside the display crop');
    }
    final left = ((fullBox.x - x) / width).clamp(0.0, 1.0);
    final top = ((fullBox.y - y) / height).clamp(0.0, 1.0);
    final right = ((fullBox.x + fullBox.width - x) / width).clamp(0.0, 1.0);
    final bottom = ((fullBox.y + fullBox.height - y) / height).clamp(0.0, 1.0);
    return RegionBox(left, top, right - left, bottom - top);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'coordinateSpace': coordinateSpace,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory PhotoCrop.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version ||
        json['coordinateSpace'] != coordinateSpace) {
      throw const FormatException('Unsupported display crop');
    }
    return PhotoCrop(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['width'] as num).toDouble(),
      (json['height'] as num).toDouble(),
    );
  }
}
