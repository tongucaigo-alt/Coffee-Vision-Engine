import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:coffee_vision/src/adaptive_padding_color_calculator.dart';
import 'package:coffee_vision/src/image_resizer.dart';
import 'package:coffee_vision/src/working_image_factory.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  group('ImageResizer', () {
    test('resizes with bilinear interpolation', () {
      final source = image.Image(width: 2, height: 2);
      source.setPixelRgba(0, 0, 0, 0, 0, 255);
      source.setPixelRgba(1, 0, 255, 255, 255, 255);
      source.setPixelRgba(0, 1, 255, 255, 255, 255);
      source.setPixelRgba(1, 1, 0, 0, 0, 255);

      final resized = const ImageResizer().resize(
        decodedImage: source,
        resolution: 4,
      );
      final interpolatedPixel = resized.getPixel(1, 1);

      expect(resized.width, 4);
      expect(resized.height, 4);
      expect(interpolatedPixel.r, allOf(greaterThan(0), lessThan(255)));
    });

    test('fits a landscape image without cropping or stretching', () {
      final resized = const ImageResizer().resize(
        decodedImage: _createImage(width: 4, height: 2),
        resolution: 8,
      );

      expect(resized.width, 8);
      expect(resized.height, 4);
    });

    test('uses nearest integer rounding with exact halves rounded up', () {
      final resized = const ImageResizer().resize(
        decodedImage: _createImage(width: 3, height: 2),
        resolution: 4,
      );

      expect(resized.width, 4);
      expect(resized.height, 3);
    });

    test('rejects a non-positive resolution', () {
      expect(
        () => const ImageResizer().resize(
          decodedImage: _createImage(width: 2, height: 2),
          resolution: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('AdaptivePaddingColorCalculator', () {
    test('averages RGBA edge channels without double-counting corners', () {
      final source = image.Image(width: 4, height: 2, numChannels: 4);
      _setPixel(source, 0, 0, 255, 0, 0, 255);
      _setPixel(source, 1, 0, 0, 100, 0, 200);
      _setPixel(source, 2, 0, 0, 0, 100, 100);
      _setPixel(source, 3, 0, 0, 0, 255, 0);
      _setPixel(source, 0, 1, 255, 255, 0, 255);
      _setPixel(source, 1, 1, 10, 20, 30, 40);
      _setPixel(source, 2, 1, 40, 50, 60, 70);
      _setPixel(source, 3, 1, 0, 255, 255, 128);

      final color = const AdaptivePaddingColorCalculator().calculate(source);

      expect([color.r, color.g, color.b, color.a], [70, 85, 88, 131]);
    });
  });

  group('WorkingImageFactory fit-with-padding pipeline', () {
    test('landscape source retains both side edges', () {
      final source = _solidImage(width: 4, height: 2, r: 0, g: 255, b: 0);
      for (var y = 0; y < source.height; y++) {
        _setPixel(source, 0, y, 255, 0, 0, 255);
        _setPixel(source, 3, y, 0, 0, 255, 255);
      }

      final result = _createWorkingImage(
        image.encodePng(source),
        resolution: 8,
      );
      final decoded = image.decodePng(result.bytes)!;

      _expectColor(decoded.getPixel(0, 3), [255, 0, 0, 255]);
      _expectColor(decoded.getPixel(7, 3), [0, 0, 255, 255]);
      expect(
        result.contentRect,
        VisionRect(left: 0.0, top: 0.25, right: 1.0, bottom: 0.75),
      );
    });

    test('portrait source retains both top and bottom edges', () {
      final source = _solidImage(width: 2, height: 4, r: 0, g: 255, b: 0);
      for (var x = 0; x < source.width; x++) {
        _setPixel(source, x, 0, 255, 0, 0, 255);
        _setPixel(source, x, 3, 0, 0, 255, 255);
      }

      final result = _createWorkingImage(
        image.encodePng(source),
        resolution: 8,
      );
      final decoded = image.decodePng(result.bytes)!;

      _expectColor(decoded.getPixel(3, 0), [255, 0, 0, 255]);
      _expectColor(decoded.getPixel(3, 7), [0, 0, 255, 255]);
      expect(
        result.contentRect,
        VisionRect(left: 0.25, top: 0.0, right: 0.75, bottom: 1.0),
      );
    });

    test('square source fills the output without padding', () {
      final source = image.Image(width: 2, height: 2, numChannels: 4);
      _setPixel(source, 0, 0, 255, 0, 0, 255);
      _setPixel(source, 1, 0, 0, 255, 0, 255);
      _setPixel(source, 0, 1, 0, 0, 255, 255);
      _setPixel(source, 1, 1, 255, 255, 255, 255);

      final result = _createWorkingImage(
        image.encodePng(source),
        resolution: 4,
      );
      final decoded = image.decodePng(result.bytes)!;

      expect(
        result.contentRect,
        VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
      );
      _expectColor(decoded.getPixel(0, 0), [255, 0, 0, 255]);
      _expectColor(decoded.getPixel(3, 3), [255, 255, 255, 255]);
    });

    test('uses the calculated adaptive color only in padding rows', () {
      final source = image.Image(width: 4, height: 2, numChannels: 4);
      _setPixel(source, 0, 0, 255, 0, 0, 255);
      _setPixel(source, 1, 0, 0, 100, 0, 200);
      _setPixel(source, 2, 0, 0, 0, 100, 100);
      _setPixel(source, 3, 0, 0, 0, 255, 0);
      _setPixel(source, 0, 1, 255, 255, 0, 255);
      _setPixel(source, 1, 1, 10, 20, 30, 40);
      _setPixel(source, 2, 1, 40, 50, 60, 70);
      _setPixel(source, 3, 1, 0, 255, 255, 128);

      final result = _createWorkingImage(
        image.encodePng(source),
        resolution: 8,
      );
      final decoded = image.decodePng(result.bytes)!;
      const paddingColor = [70, 85, 88, 131];

      for (final y in [0, 1, 6, 7]) {
        for (var x = 0; x < decoded.width; x++) {
          _expectColor(decoded.getPixel(x, y), paddingColor);
        }
      }
      expect(_pixelChannels(decoded.getPixel(0, 2)), isNot(paddingColor));
    });

    test('derives contentRect from actual rounded size and placement', () {
      final bytes = image.encodePng(_createImage(width: 3, height: 2));

      final result = _createWorkingImage(bytes, resolution: 8);

      expect(
        result.contentRect,
        VisionRect(left: 0.0, top: 1 / 8, right: 1.0, bottom: 6 / 8),
      );
    });

    test('preserves source metadata and reports working metadata', () {
      final bytes = image.encodePng(_createImage(width: 4, height: 2));

      final result = _createWorkingImage(bytes, resolution: 8);

      expect(result.sourceMetadata.format, VisionImageFormat.png);
      expect(result.sourceMetadata.width, 4);
      expect(result.sourceMetadata.height, 2);
      expect(result.workingMetadata.format, VisionImageFormat.png);
      expect(result.workingMetadata.width, 8);
      expect(result.workingMetadata.height, 8);
      expect(identical(result.metadata, result.workingMetadata), isTrue);
    });

    test('applies a custom working resolution and half-up fit rounding', () {
      final bytes = image.encodePng(_createImage(width: 4, height: 2));

      final result = _createWorkingImage(bytes, resolution: 7);

      expect(result.resolution, 7);
      expect(result.workingMetadata.width, 7);
      expect(result.workingMetadata.height, 7);
      expect(
        result.contentRect,
        VisionRect(left: 0.0, top: 1 / 7, right: 1.0, bottom: 5 / 7),
      );
    });

    test('downscales a large image without changing its aspect ratio', () {
      final bytes = image.encodePng(_createImage(width: 1024, height: 768));

      final result = _createWorkingImage(bytes, resolution: 64);

      expect(
        result.contentRect,
        VisionRect(left: 0.0, top: 8 / 64, right: 1.0, bottom: 56 / 64),
      );
    });

    test('upscales a small image without changing its aspect ratio', () {
      final bytes = image.encodeJpg(_createImage(width: 2, height: 3));

      final result = _createWorkingImage(bytes, resolution: 40);

      expect(result.workingMetadata.format, VisionImageFormat.jpeg);
      expect(
        result.contentRect,
        VisionRect(left: 6 / 40, top: 0.0, right: 33 / 40, bottom: 1.0),
      );
    });

    test('keeps JPEG output encoded as opaque JPEG', () {
      final bytes = image.encodeJpg(_createImage(width: 4, height: 2));

      final result = _createWorkingImage(bytes, resolution: 8);
      final decoded = image.decodeJpg(result.bytes)!;

      expect(result.workingMetadata.format, VisionImageFormat.jpeg);
      expect(decoded.getPixel(0, 0).a, 255);
    });

    test('does not modify the original input bytes', () {
      final bytes = image.encodePng(_createImage(width: 12, height: 5));
      final before = Uint8List.fromList(bytes);

      _createWorkingImage(bytes, resolution: 32);

      expect(bytes, before);
    });

    test('keeps controlled unsupported-image failures', () {
      final bytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39]);
      final input = VisionImageInput(
        imageBytes: bytes,
        surfaceType: VisionSurfaceType.cup,
      );

      expect(
        () => const WorkingImageFactory(
          config: VisionConfig(workingResolution: 16),
        ).create(input),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Unsupported image format'),
          ),
        ),
      );
    });
  });
}

WorkingImage _createWorkingImage(Uint8List bytes, {required int resolution}) {
  return WorkingImageFactory(
    config: VisionConfig(workingResolution: resolution),
  ).create(
    VisionImageInput(imageBytes: bytes, surfaceType: VisionSurfaceType.cup),
  );
}

image.Image _createImage({required int width, required int height}) {
  final result = image.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      _setPixel(
        result,
        x,
        y,
        (x * 37 + y * 11) % 256,
        (x * 17 + y * 29) % 256,
        (x * 7 + y * 43) % 256,
        255,
      );
    }
  }
  return result;
}

image.Image _solidImage({
  required int width,
  required int height,
  required int r,
  required int g,
  required int b,
}) {
  final result = image.Image(width: width, height: height, numChannels: 4);
  for (final pixel in result) {
    pixel.setRgba(r, g, b, 255);
  }
  return result;
}

void _setPixel(image.Image target, int x, int y, int r, int g, int b, int a) {
  target.setPixelRgba(x, y, r, g, b, a);
}

void _expectColor(image.Pixel pixel, List<num> expected) {
  expect(_pixelChannels(pixel), expected);
}

List<num> _pixelChannels(image.Pixel pixel) {
  return [pixel.r, pixel.g, pixel.b, pixel.a];
}
