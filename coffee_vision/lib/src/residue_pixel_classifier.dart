import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'models/residue_mask.dart';
import 'models/vision_geometry.dart';
import 'models/vision_image_metadata.dart';
import 'models/working_image.dart';

/// Applies the single Coffee Vision dark-pixel decision to a working image.
final class ResiduePixelClassifier {
  const ResiduePixelClassifier();

  static const int _histogramSize = 256;
  static const int _minimumLuminanceDifference = 32;

  ResiduePixelClassification classify(WorkingImage workingImage) {
    final decodedImage = _decode(
      workingImage.bytes,
      workingImage.workingMetadata.format,
    );
    _validateMetadata(decodedImage, workingImage);

    final contentBounds = _toPixelBounds(
      workingImage.contentRect,
      width: decodedImage.width,
      height: decodedImage.height,
    );
    if (contentBounds.isEmpty) {
      throw ArgumentError.value(
        workingImage.contentRect,
        'workingImage.contentRect',
        'must cover at least one decoded pixel',
      );
    }

    final histogram = Uint32List(_histogramSize);
    var contentPixelCount = 0;
    for (var y = contentBounds.top; y < contentBounds.bottom; y++) {
      for (var x = contentBounds.left; x < contentBounds.right; x++) {
        histogram[_luminance(decodedImage.getPixel(x, y))]++;
        contentPixelCount++;
      }
    }

    final backgroundLuminance = _percentile75(histogram, contentPixelCount);
    final residueThreshold = backgroundLuminance - _minimumLuminanceDifference;
    final pixels = Uint8List(decodedImage.width * decodedImage.height);
    var residuePixelCount = 0;

    for (var y = contentBounds.top; y < contentBounds.bottom; y++) {
      for (var x = contentBounds.left; x < contentBounds.right; x++) {
        final luminance = _luminance(decodedImage.getPixel(x, y));
        if (luminance <= residueThreshold) {
          pixels[y * decodedImage.width + x] = 1;
          residuePixelCount++;
        }
      }
    }

    return ResiduePixelClassification._(
      width: decodedImage.width,
      height: decodedImage.height,
      pixels: pixels,
      residuePixelCount: residuePixelCount,
      contentPixelCount: contentPixelCount,
    );
  }

  image.Image _decode(Uint8List bytes, VisionImageFormat format) {
    try {
      final decoded = switch (format) {
        VisionImageFormat.jpeg => image.decodeJpg(bytes),
        VisionImageFormat.png => image.decodePng(bytes),
      };
      if (decoded != null) return decoded;
    } on image.ImageException {
      throw const FormatException('Working image data could not be decoded.');
    } on RangeError {
      throw const FormatException('Working image data could not be decoded.');
    } on StateError {
      throw const FormatException('Working image data could not be decoded.');
    }

    throw const FormatException('Working image data could not be decoded.');
  }

  void _validateMetadata(image.Image decodedImage, WorkingImage workingImage) {
    final metadata = workingImage.workingMetadata;
    if (decodedImage.width != metadata.width ||
        decodedImage.height != metadata.height) {
      throw const FormatException(
        'Working image metadata does not match decoded image dimensions.',
      );
    }
  }

  int _luminance(image.Pixel pixel) {
    return pixel.luminance.round().clamp(0, _histogramSize - 1);
  }

  int _percentile75(Uint32List histogram, int pixelCount) {
    final nearestRank = (pixelCount * 3 + 3) ~/ 4;
    var cumulativeCount = 0;
    for (var luminance = 0; luminance < histogram.length; luminance++) {
      cumulativeCount += histogram[luminance];
      if (cumulativeCount >= nearestRank) return luminance;
    }
    throw StateError('Luminance histogram does not contain any pixels.');
  }
}

/// Internal immutable classification shared by mask and density calculations.
final class ResiduePixelClassification {
  const ResiduePixelClassification._({
    required this.width,
    required this.height,
    required Uint8List pixels,
    required this.residuePixelCount,
    required this.contentPixelCount,
  }) : _pixels = pixels;

  final int width;
  final int height;
  final Uint8List _pixels;
  final int residuePixelCount;
  final int contentPixelCount;

  ResidueMask createMask() {
    return ResidueMask(
      width: width,
      height: height,
      pixels: _pixels,
      residueRatio: residuePixelCount / contentPixelCount,
    );
  }

  double densityFor(VisionRect rect) {
    final bounds = _toPixelBounds(rect, width: width, height: height);
    if (bounds.isEmpty) return 0.0;

    var regionResiduePixelCount = 0;
    var regionPixelCount = 0;
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        regionResiduePixelCount += _pixels[y * width + x];
        regionPixelCount++;
      }
    }
    return regionResiduePixelCount / regionPixelCount;
  }
}

_PixelBounds _toPixelBounds(
  VisionRect rect, {
  required int width,
  required int height,
}) {
  final bounds = _PixelBounds(
    left: (rect.left * width).round(),
    top: (rect.top * height).round(),
    right: (rect.right * width).round(),
    bottom: (rect.bottom * height).round(),
  );
  if (bounds.left < 0 ||
      bounds.top < 0 ||
      bounds.right > width ||
      bounds.bottom > height ||
      bounds.left > bounds.right ||
      bounds.top > bounds.bottom) {
    throw ArgumentError.value(
      rect,
      'rect',
      'must map inside the decoded image bounds',
    );
  }
  return bounds;
}

final class _PixelBounds {
  const _PixelBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isEmpty => left == right || top == bottom;
}
