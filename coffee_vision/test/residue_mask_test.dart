import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  group('ResidueMask', () {
    test('stores binary pixels and derives the residue count', () {
      final mask = ResidueMask(
        width: 2,
        height: 2,
        pixels: Uint8List.fromList([1, 0, 1, 0]),
        residueRatio: 0.5,
      );

      expect(mask.width, 2);
      expect(mask.height, 2);
      expect(mask.pixels, [1, 0, 1, 0]);
      expect(mask.residuePixelCount, 2);
      expect(mask.residueRatio, 0.5);
    });

    test('defensively protects input and returned pixel buffers', () {
      final source = Uint8List.fromList([1, 0, 0, 0]);
      final mask = ResidueMask(
        width: 2,
        height: 2,
        pixels: source,
        residueRatio: 0.25,
      );

      source[0] = 0;
      final returned = mask.pixels;
      returned[0] = 0;

      expect(mask.pixels, [1, 0, 0, 0]);
      expect(mask.residuePixelCount, 1);
    });

    test('rejects invalid dimensions, buffers, and ratios', () {
      expect(
        () => ResidueMask(
          width: 0,
          height: 1,
          pixels: Uint8List(0),
          residueRatio: 0.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ResidueMask(
          width: 2,
          height: 2,
          pixels: Uint8List(3),
          residueRatio: 0.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ResidueMask(
          width: 1,
          height: 1,
          pixels: Uint8List.fromList([2]),
          residueRatio: 1.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ResidueMask(
          width: 1,
          height: 1,
          pixels: Uint8List(1),
          residueRatio: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final first = ResidueMask(
        width: 2,
        height: 1,
        pixels: Uint8List.fromList([1, 0]),
        residueRatio: 0.5,
      );
      final second = ResidueMask(
        width: 2,
        height: 1,
        pixels: Uint8List.fromList([1, 0]),
        residueRatio: 0.5,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'ResidueMask(width: 2, height: 1, residuePixelCount: 1, '
        'residueRatio: 0.5)',
      );
    });
  });

  group('CoffeeVisionEngine.createResidueMask', () {
    const engine = CoffeeVisionEngine();

    test('returns an asynchronous binary mask for a white image', () async {
      final future = engine.createResidueMask(
        workingImage: _workingImage(_solidImage(4, 4, 255)),
      );

      expect(future, isA<Future<ResidueMask>>());
      final mask = await future;
      expect(mask.width, 4);
      expect(mask.height, 4);
      expect(mask.pixels, everyElement(0));
      expect(mask.residuePixelCount, 0);
      expect(mask.residueRatio, 0.0);
    });

    test('documents zero residue for a uniform black image', () async {
      final mask = await engine.createResidueMask(
        workingImage: _workingImage(_solidImage(4, 4, 0)),
      );

      expect(mask.pixels, everyElement(0));
      expect(mask.residuePixelCount, 0);
      expect(mask.residueRatio, 0.0);
    });

    test('creates the expected deterministic mask for mixed pixels', () async {
      final source = _solidImage(4, 4, 255);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 2; x++) {
          _setGray(source, x, y, 0);
        }
      }
      final workingImage = _workingImage(source);

      final first = await engine.createResidueMask(workingImage: workingImage);
      final second = await engine.createResidueMask(workingImage: workingImage);

      expect(first.pixels, [1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(first.residuePixelCount, 4);
      expect(first.residueRatio, 0.25);
      expect(second, first);
    });

    test('keeps the existing difference 32 threshold boundary', () async {
      final source = _solidImage(4, 4, 255);
      _setGray(source, 0, 0, 223);
      _setGray(source, 1, 0, 224);

      final mask = await engine.createResidueMask(
        workingImage: _workingImage(source),
      );

      expect(mask.pixels[0], 1);
      expect(mask.pixels[1], 0);
      expect(mask.residuePixelCount, 1);
      expect(mask.residueRatio, 1 / 16);
    });

    test('keeps padding zero and excludes it from the residue ratio', () async {
      final source = _solidImage(6, 6, 0);
      for (var y = 1; y < 5; y++) {
        for (var x = 1; x < 5; x++) {
          _setGray(source, x, y, 255);
        }
      }
      for (var y = 1; y < 3; y++) {
        for (var x = 1; x < 3; x++) {
          _setGray(source, x, y, 0);
        }
      }

      final mask = await engine.createResidueMask(
        workingImage: _workingImage(
          source,
          contentRect: VisionRect(
            left: 1 / 6,
            top: 1 / 6,
            right: 5 / 6,
            bottom: 5 / 6,
          ),
        ),
      );

      expect(mask.residuePixelCount, 4);
      expect(mask.residueRatio, 0.25);
      expect(mask.pixels.take(6), everyElement(0));
      expect(mask.pixels.skip(30), everyElement(0));
      for (var y = 0; y < 6; y++) {
        expect(mask.pixels[y * 6], 0);
        expect(mask.pixels[y * 6 + 5], 0);
      }
    });

    test('does not modify WorkingImage byte data', () async {
      final workingImage = _workingImage(_solidImage(4, 4, 255));
      final before = workingImage.bytes;

      await engine.createResidueMask(workingImage: workingImage);

      expect(workingImage.bytes, before);
    });

    test('preserves controlled decode and metadata errors', () async {
      final metadata = VisionImageMetadata(
        format: VisionImageFormat.png,
        width: 2,
        height: 2,
      );
      final undecodable = WorkingImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: metadata,
        resolution: 2,
      );

      await expectLater(
        engine.createResidueMask(workingImage: undecodable),
        throwsA(isA<FormatException>()),
      );

      final mismatched = WorkingImage(
        bytes: image.encodePng(_solidImage(2, 2, 255)),
        metadata: VisionImageMetadata(
          format: VisionImageFormat.png,
          width: 3,
          height: 3,
        ),
        resolution: 3,
      );
      await expectLater(
        engine.createResidueMask(workingImage: mismatched),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

WorkingImage _workingImage(image.Image source, {VisionRect? contentRect}) {
  final metadata = VisionImageMetadata(
    format: VisionImageFormat.png,
    width: source.width,
    height: source.height,
  );
  return WorkingImage(
    bytes: image.encodePng(source),
    metadata: metadata,
    contentRect: contentRect,
    resolution: source.width,
  );
}

image.Image _solidImage(int width, int height, int luminance) {
  final result = image.Image(width: width, height: height, numChannels: 4);
  for (final pixel in result) {
    pixel.setRgba(luminance, luminance, luminance, 255);
  }
  return result;
}

void _setGray(image.Image target, int x, int y, int luminance) {
  target.setPixelRgba(x, y, luminance, luminance, luminance, 255);
}
