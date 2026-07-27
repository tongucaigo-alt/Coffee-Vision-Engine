import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  group('VisionRegionDensity', () {
    test('accepts inclusive density boundaries', () {
      final empty = VisionRegionDensity(
        regionId: VisionRegionId.top,
        surfaceType: VisionSurfaceType.cup,
        density: 0.0,
      );
      final full = VisionRegionDensity(
        regionId: VisionRegionId.bottom,
        surfaceType: VisionSurfaceType.saucer,
        density: 1.0,
      );

      expect(empty.density, 0.0);
      expect(full.density, 1.0);
    });

    test('rejects invalid density values', () {
      for (final density in [-0.01, 1.01, double.nan, double.infinity]) {
        expect(
          () => VisionRegionDensity(
            regionId: VisionRegionId.center,
            surfaceType: VisionSurfaceType.cup,
            density: density,
          ),
          throwsArgumentError,
        );
      }
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final first = VisionRegionDensity(
        regionId: VisionRegionId.left,
        surfaceType: VisionSurfaceType.cup,
        density: 0.25,
      );
      final second = VisionRegionDensity(
        regionId: VisionRegionId.left,
        surfaceType: VisionSurfaceType.cup,
        density: 0.25,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'VisionRegionDensity(regionId: VisionRegionId.left, '
        'surfaceType: VisionSurfaceType.cup, density: 0.25)',
      );
    });
  });

  group('CoffeeVisionEngine.analyzeRegionDensities', () {
    const engine = CoffeeVisionEngine();

    test('returns a Future and an unmodifiable deterministic list', () async {
      final workingImage = _workingImage(_solidImage(6, 6, 255));
      final future = engine.analyzeRegionDensities(
        workingImage: workingImage,
        surfaceType: VisionSurfaceType.cup,
      );

      expect(future, isA<Future<List<VisionRegionDensity>>>());
      final densities = await future;
      expect(densities.map((result) => result.regionId), VisionRegionId.values);
      expect(() => densities.add(densities.first), throwsUnsupportedError);
    });

    test('returns zero density for a uniform white image', () async {
      final densities = await _analyze(
        engine,
        _workingImage(_solidImage(6, 6, 255)),
      );

      expect(densities.values, everyElement(0.0));
    });

    test('documents zero density for a uniform black image', () async {
      final densities = await _analyze(
        engine,
        _workingImage(_solidImage(6, 6, 0)),
      );

      expect(densities.values, everyElement(0.0));
    });

    test(
      'uses the global 75th percentile reference for every region',
      () async {
        final source = _solidImage(6, 6, 255);
        for (var y = 0; y < source.height; y++) {
          for (var x = 0; x < 2; x++) {
            _setGray(source, x, y, 100);
          }
        }

        final densities = await _analyze(engine, _workingImage(source));

        expect(densities[VisionRegionId.left], 1.0);
        expect(densities[VisionRegionId.center], 0.0);
        expect(densities[VisionRegionId.right], 0.0);
        expect(densities[VisionRegionId.top], closeTo(1 / 3, 1e-12));
        expect(densities[VisionRegionId.middle], closeTo(1 / 3, 1e-12));
        expect(densities[VisionRegionId.bottom], closeTo(1 / 3, 1e-12));
      },
    );

    test('includes difference 32 and excludes difference 31', () async {
      final source = _solidImage(6, 6, 255);
      for (var y = 0; y < source.height; y++) {
        _setGray(source, 4, y, 223);
        _setGray(source, 5, y, 224);
      }

      final densities = await _analyze(engine, _workingImage(source));

      expect(densities[VisionRegionId.right], 0.5);
      expect(densities[VisionRegionId.top], closeTo(1 / 6, 1e-12));
      expect(densities[VisionRegionId.middle], closeTo(1 / 6, 1e-12));
      expect(densities[VisionRegionId.bottom], closeTo(1 / 6, 1e-12));
    });

    test(
      'maps dark pixels to overlapping horizontal and vertical bands',
      () async {
        final source = _solidImage(6, 6, 255);
        for (var y = 0; y < 2; y++) {
          for (var x = 0; x < source.width; x++) {
            _setGray(source, x, y, 0);
          }
        }

        final densities = await _analyze(engine, _workingImage(source));

        expect(densities[VisionRegionId.top], 1.0);
        expect(densities[VisionRegionId.middle], 0.0);
        expect(densities[VisionRegionId.bottom], 0.0);
        expect(densities[VisionRegionId.left], closeTo(1 / 3, 1e-12));
        expect(densities[VisionRegionId.center], closeTo(1 / 3, 1e-12));
        expect(densities[VisionRegionId.right], closeTo(1 / 3, 1e-12));
      },
    );

    test('excludes adaptive padding from the global reference', () async {
      final source = _solidImage(6, 6, 255);
      for (var y = 1; y < 5; y++) {
        for (var x = 1; x < 5; x++) {
          _setGray(source, x, y, 100);
        }
      }
      final contentRect = VisionRect(
        left: 1 / 6,
        top: 1 / 6,
        right: 5 / 6,
        bottom: 5 / 6,
      );

      final densities = await _analyze(
        engine,
        _workingImage(source, contentRect: contentRect),
      );

      expect(densities.values, everyElement(0.0));
    });

    test(
      'preserves surface type while keeping the same numeric results',
      () async {
        final workingImage = _workingImage(_solidImage(6, 6, 255));
        final cup = await engine.analyzeRegionDensities(
          workingImage: workingImage,
          surfaceType: VisionSurfaceType.cup,
        );
        final saucer = await engine.analyzeRegionDensities(
          workingImage: workingImage,
          surfaceType: VisionSurfaceType.saucer,
        );

        expect(
          cup.map((result) => result.density),
          saucer.map((r) => r.density),
        );
        expect(
          cup.every((result) => result.surfaceType == VisionSurfaceType.cup),
          isTrue,
        );
        expect(
          saucer.every(
            (result) => result.surfaceType == VisionSurfaceType.saucer,
          ),
          isTrue,
        );
      },
    );

    test('handles 1x1 and 2x2 images without invalid densities', () async {
      for (final size in [1, 2]) {
        final results = await engine.analyzeRegionDensities(
          workingImage: _workingImage(_solidImage(size, size, 255)),
          surfaceType: VisionSurfaceType.cup,
        );

        expect(results, hasLength(6));
        expect(
          results.every(
            (result) =>
                result.density.isFinite &&
                result.density >= 0.0 &&
                result.density <= 1.0,
          ),
          isTrue,
        );
      }
    });

    test('decodes both PNG and JPEG working images', () async {
      final source = _solidImage(6, 6, 255);

      final png = await engine.analyzeRegionDensities(
        workingImage: _workingImage(source),
        surfaceType: VisionSurfaceType.cup,
      );
      final jpeg = await engine.analyzeRegionDensities(
        workingImage: _workingImage(source, format: VisionImageFormat.jpeg),
        surfaceType: VisionSurfaceType.cup,
      );

      expect(png, hasLength(6));
      expect(jpeg, hasLength(6));
    });

    test('rejects undecodable working-image bytes', () async {
      final metadata = VisionImageMetadata(
        format: VisionImageFormat.png,
        width: 2,
        height: 2,
      );
      final workingImage = WorkingImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: metadata,
        resolution: 2,
      );

      await expectLater(
        engine.analyzeRegionDensities(
          workingImage: workingImage,
          surfaceType: VisionSurfaceType.cup,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects decoded dimensions that differ from metadata', () async {
      final source = _solidImage(2, 2, 255);
      final metadata = VisionImageMetadata(
        format: VisionImageFormat.png,
        width: 3,
        height: 3,
      );
      final workingImage = WorkingImage(
        bytes: image.encodePng(source),
        metadata: metadata,
        resolution: 3,
      );

      await expectLater(
        engine.analyzeRegionDensities(
          workingImage: workingImage,
          surfaceType: VisionSurfaceType.cup,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('metadata'),
          ),
        ),
      );
    });

    test('rejects a content rect that covers no decoded pixels', () async {
      final workingImage = _workingImage(
        _solidImage(2, 2, 255),
        contentRect: VisionRect(left: 0.5, top: 0.5, right: 0.5, bottom: 0.5),
      );

      await expectLater(
        engine.analyzeRegionDensities(
          workingImage: workingImage,
          surfaceType: VisionSurfaceType.cup,
        ),
        throwsArgumentError,
      );
    });

    test('does not modify WorkingImage byte data', () async {
      final workingImage = _workingImage(_solidImage(6, 6, 255));
      final before = workingImage.bytes;

      await engine.analyzeRegionDensities(
        workingImage: workingImage,
        surfaceType: VisionSurfaceType.cup,
      );

      expect(workingImage.bytes, before);
    });

    test('reuses output from the public preparation pipeline', () async {
      const preparedEngine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 6),
      );
      final source = _solidImage(6, 6, 255);
      final workingImage = await preparedEngine.prepareWorkingImage(
        VisionImageInput(
          imageBytes: image.encodePng(source),
          surfaceType: VisionSurfaceType.cup,
        ),
      );

      final results = await preparedEngine.analyzeRegionDensities(
        workingImage: workingImage,
        surfaceType: VisionSurfaceType.cup,
      );

      expect(results, hasLength(6));
      expect(results.map((result) => result.density), everyElement(0.0));
    });
  });
}

Future<Map<VisionRegionId, double>> _analyze(
  CoffeeVisionEngine engine,
  WorkingImage workingImage,
) async {
  final results = await engine.analyzeRegionDensities(
    workingImage: workingImage,
    surfaceType: VisionSurfaceType.cup,
  );
  return {for (final result in results) result.regionId: result.density};
}

WorkingImage _workingImage(
  image.Image source, {
  VisionImageFormat format = VisionImageFormat.png,
  VisionRect? contentRect,
}) {
  final bytes = switch (format) {
    VisionImageFormat.jpeg => image.encodeJpg(source, quality: 100),
    VisionImageFormat.png => image.encodePng(source),
  };
  final metadata = VisionImageMetadata(
    format: format,
    width: source.width,
    height: source.height,
  );
  return WorkingImage(
    bytes: bytes,
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
