import 'dart:typed_data';

/// Binary residue-candidate pixels aligned to a complete working image.
///
/// Pixel values are row-major bytes containing only `0` or `1`. Pixels outside
/// the working image's content rectangle remain `0`. [residueRatio] is measured
/// against analyzed content pixels, so adaptive padding does not dilute it.
final class ResidueMask {
  factory ResidueMask({
    required int width,
    required int height,
    required Uint8List pixels,
    required double residueRatio,
  }) {
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be greater than zero');
    }
    if (height <= 0) {
      throw ArgumentError.value(height, 'height', 'must be greater than zero');
    }
    if (!residueRatio.isFinite || residueRatio < 0.0 || residueRatio > 1.0) {
      throw ArgumentError.value(
        residueRatio,
        'residueRatio',
        'must be finite and between 0.0 and 1.0',
      );
    }

    final expectedLength = width * height;
    if (pixels.length != expectedLength) {
      throw ArgumentError.value(
        pixels.length,
        'pixels.length',
        'must equal width * height ($expectedLength)',
      );
    }

    final pixelCopy = Uint8List.fromList(pixels);
    var residuePixelCount = 0;
    for (final value in pixelCopy) {
      if (value != 0 && value != 1) {
        throw ArgumentError.value(
          value,
          'pixels',
          'must contain only binary values 0 and 1',
        );
      }
      residuePixelCount += value;
    }

    return ResidueMask._(
      width: width,
      height: height,
      pixels: pixelCopy,
      residuePixelCount: residuePixelCount,
      residueRatio: residueRatio,
    );
  }

  const ResidueMask._({
    required this.width,
    required this.height,
    required Uint8List pixels,
    required this.residuePixelCount,
    required this.residueRatio,
  }) : _pixels = pixels;

  final int width;
  final int height;
  final Uint8List _pixels;
  final int residuePixelCount;
  final double residueRatio;

  Uint8List get pixels => Uint8List.fromList(_pixels);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ResidueMask &&
            other.width == width &&
            other.height == height &&
            other.residuePixelCount == residuePixelCount &&
            other.residueRatio == residueRatio &&
            _samePixels(other._pixels, _pixels);
  }

  @override
  int get hashCode => Object.hash(
    width,
    height,
    residuePixelCount,
    residueRatio,
    Object.hashAll(_pixels),
  );

  @override
  String toString() {
    return 'ResidueMask(width: $width, height: $height, '
        'residuePixelCount: $residuePixelCount, '
        'residueRatio: $residueRatio)';
  }

  static bool _samePixels(Uint8List first, Uint8List second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
