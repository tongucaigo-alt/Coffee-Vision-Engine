import 'package:image/image.dart' as image;

/// Resizes decoded images to fit inside a square working resolution.
///
/// The dominant dimension becomes [resolution]. The other dimension is
/// calculated with integer nearest rounding, with exact halves rounded up.
/// No source pixels are cropped and no padding is added by this service.
final class ImageResizer {
  const ImageResizer();

  image.Image resize({
    required image.Image decodedImage,
    required int resolution,
  }) {
    if (resolution <= 0) {
      throw ArgumentError.value(
        resolution,
        'resolution',
        'must be greater than zero',
      );
    }
    if (decodedImage.width <= 0 || decodedImage.height <= 0) {
      throw const FormatException(
        'Decoded image dimensions must be greater than zero.',
      );
    }

    // Palette indices cannot be bilinearly interpolated as color channels.
    final interpolationSource = decodedImage.hasPalette
        ? decodedImage.convert(
            format: image.Format.uint8,
            numChannels: decodedImage.hasAlpha ? 4 : 3,
            withPalette: false,
            noAnimation: true,
          )
        : decodedImage;
    final targetSize = _fitSize(
      width: interpolationSource.width,
      height: interpolationSource.height,
      resolution: resolution,
    );
    return image.copyResize(
      interpolationSource,
      width: targetSize.width,
      height: targetSize.height,
      interpolation: image.Interpolation.linear,
    );
  }

  ({int width, int height}) _fitSize({
    required int width,
    required int height,
    required int resolution,
  }) {
    if (width >= height) {
      return (
        width: resolution,
        height: _scaleDimension(height, resolution, width),
      );
    }
    return (
      width: _scaleDimension(width, resolution, height),
      height: resolution,
    );
  }

  int _scaleDimension(int value, int resolution, int dominantDimension) {
    final scaled =
        (value * resolution + dominantDimension ~/ 2) ~/ dominantDimension;
    return scaled.clamp(1, resolution);
  }
}
