import 'vision_geometry.dart';

final class VisionCoordinateMapper {
  VisionCoordinateMapper({required int imageWidth, required int imageHeight})
    : imageWidth = _validatedDimension(imageWidth, 'imageWidth'),
      imageHeight = _validatedDimension(imageHeight, 'imageHeight');

  final int imageWidth;
  final int imageHeight;

  VisionPoint normalizePoint({required double pixelX, required double pixelY}) {
    final x = _validatedPixelCoordinate(
      pixelX,
      imageWidth.toDouble(),
      'pixelX',
    );
    final y = _validatedPixelCoordinate(
      pixelY,
      imageHeight.toDouble(),
      'pixelY',
    );
    return VisionPoint(x: x / imageWidth, y: y / imageHeight);
  }

  ({double x, double y}) denormalizePoint(VisionPoint point) {
    return (x: point.x * imageWidth, y: point.y * imageHeight);
  }

  VisionRect normalizeRect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final validatedLeft = _validatedPixelCoordinate(
      left,
      imageWidth.toDouble(),
      'left',
    );
    final validatedTop = _validatedPixelCoordinate(
      top,
      imageHeight.toDouble(),
      'top',
    );
    final validatedRight = _validatedPixelCoordinate(
      right,
      imageWidth.toDouble(),
      'right',
    );
    final validatedBottom = _validatedPixelCoordinate(
      bottom,
      imageHeight.toDouble(),
      'bottom',
    );
    if (validatedLeft > validatedRight) {
      throw ArgumentError.value(left, 'left', 'must not be greater than right');
    }
    if (validatedTop > validatedBottom) {
      throw ArgumentError.value(top, 'top', 'must not be greater than bottom');
    }

    return VisionRect(
      left: validatedLeft / imageWidth,
      top: validatedTop / imageHeight,
      right: validatedRight / imageWidth,
      bottom: validatedBottom / imageHeight,
    );
  }

  static int _validatedDimension(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
    return value;
  }

  static double _validatedPixelCoordinate(
    double value,
    double maximum,
    String name,
  ) {
    if (!value.isFinite || value < 0.0 || value > maximum) {
      throw ArgumentError.value(
        value,
        name,
        'must be between 0.0 and $maximum',
      );
    }
    return value;
  }
}
