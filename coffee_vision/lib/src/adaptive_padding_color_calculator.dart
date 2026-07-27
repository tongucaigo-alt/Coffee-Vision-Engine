import 'package:image/image.dart' as image;

/// Calculates one deterministic color from the outer edge of an image.
final class AdaptivePaddingColorCalculator {
  const AdaptivePaddingColorCalculator();

  image.ColorUint8 calculate(image.Image source) {
    if (source.width <= 0 || source.height <= 0 || source.data == null) {
      throw const FormatException(
        'Image has no usable edge pixels for adaptive padding.',
      );
    }

    var red = 0;
    var green = 0;
    var blue = 0;
    var alpha = 0;
    var count = 0;

    void addPixel(int x, int y) {
      final pixel = source.getPixel(x, y);
      red += pixel.r.toInt();
      green += pixel.g.toInt();
      blue += pixel.b.toInt();
      alpha += pixel.a.toInt();
      count++;
    }

    for (var x = 0; x < source.width; x++) {
      addPixel(x, 0);
    }
    if (source.height > 1) {
      for (var x = 0; x < source.width; x++) {
        addPixel(x, source.height - 1);
      }
    }

    // The top and bottom loops already include all four corners.
    for (var y = 1; y < source.height - 1; y++) {
      addPixel(0, y);
      if (source.width > 1) {
        addPixel(source.width - 1, y);
      }
    }

    if (count == 0) {
      throw const FormatException(
        'Image has no usable edge pixels for adaptive padding.',
      );
    }

    return image.ColorUint8.rgba(
      _roundedAverage(red, count),
      _roundedAverage(green, count),
      _roundedAverage(blue, count),
      _roundedAverage(alpha, count),
    );
  }

  /// Uses integer nearest rounding, with exact halves rounded upward.
  int _roundedAverage(int total, int count) {
    return (total + count ~/ 2) ~/ count;
  }
}
