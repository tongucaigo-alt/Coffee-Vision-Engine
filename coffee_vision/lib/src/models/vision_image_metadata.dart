enum VisionImageFormat { jpeg, png }

final class VisionImageMetadata {
  VisionImageMetadata({
    required this.format,
    required int width,
    required int height,
  }) : width = _validatedDimension(width, 'width'),
       height = _validatedDimension(height, 'height');

  final VisionImageFormat format;
  final int width;
  final int height;

  static int _validatedDimension(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
    return value;
  }
}
