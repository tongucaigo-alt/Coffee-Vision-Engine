import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('VisionComponent', () {
    test('stores validated geometry and derives pixelCount', () {
      final component = _component(id: 1, pixels: [0, 1], areaRatio: 0.5);

      expect(component.id, 1);
      expect(component.pixelCount, 2);
      expect(component.pixels, [0, 1]);
      expect(component.boundingBox, _fullRect());
      expect(component.centroid, VisionPoint(x: 0.5, y: 0.5));
      expect(component.areaRatio, 0.5);
      expect(component.width, 1.0);
      expect(component.height, 1.0);
      expect(component.aspectRatio, 1.0);
    });

    test('keeps the legacy constructor usable without guessing features', () {
      final component = _component(id: 1, pixels: [0], areaRatio: 0.25);

      expect(component.width, 1.0);
      expect(component.height, 1.0);
      expect(component.aspectRatio, 1.0);
      expect(
        () => component.fillRatio,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('VisionComponent.fromDetection'),
          ),
        ),
      );
      expect(
        () => component.touchesBorder,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('VisionComponent.fromDetection'),
          ),
        ),
      );
    });

    test('defensively protects its pixel representation', () {
      final source = <int>[0, 1];
      final component = _component(id: 1, pixels: source, areaRatio: 0.5);

      source[0] = 9;
      final returned = component.pixels;
      returned[0] = 9;

      expect(component.pixels, [0, 1]);
    });

    test('rejects invalid ids, pixels, and area ratios', () {
      expect(
        () => _component(id: 0, pixels: [0], areaRatio: 0.5),
        throwsArgumentError,
      );
      expect(
        () => _component(id: 1, pixels: [], areaRatio: 0.5),
        throwsArgumentError,
      );
      expect(
        () => _component(id: 1, pixels: [-1], areaRatio: 0.5),
        throwsArgumentError,
      );
      expect(
        () => _component(id: 1, pixels: [0, 0], areaRatio: 0.5),
        throwsArgumentError,
      );
      expect(
        () => _component(id: 1, pixels: [0], areaRatio: 0.0),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final first = _component(id: 1, pixels: [0, 1], areaRatio: 0.5);
      final second = _component(id: 1, pixels: [0, 1], areaRatio: 0.5);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('pixelCount: 2'));
    });

    test('validates detection dimensions and keeps feature equality', () {
      final first = _detectedComponent(
        pixels: [0, 1],
        imageWidth: 2,
        imageHeight: 1,
      );
      final second = _detectedComponent(
        pixels: [0, 1],
        imageWidth: 2,
        imageHeight: 1,
      );
      final legacy = _component(id: 1, pixels: [0, 1], areaRatio: 1.0);

      expect(first.fillRatio, 1.0);
      expect(first.touchesBorder, isTrue);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(legacy));

      expect(
        () => _detectedComponent(pixels: [0], imageWidth: 0, imageHeight: 1),
        throwsArgumentError,
      );
      expect(
        () => _detectedComponent(pixels: [4], imageWidth: 2, imageHeight: 2),
        throwsArgumentError,
      );
    });
  });

  group('VisionComponentResult', () {
    test('derives counts and keeps the component list immutable', () {
      final component = _component(id: 1, pixels: [0], areaRatio: 0.25);
      final source = <VisionComponent>[component];
      final result = VisionComponentResult(
        imageSize: (width: 2, height: 2),
        totalResiduePixels: 1,
        components: source,
      );

      source.clear();
      expect(result.imageSize, (width: 2, height: 2));
      expect(result.componentCount, 1);
      expect(result.totalResiduePixels, 1);
      expect(result.components, [component]);
      expect(() => result.components.add(component), throwsUnsupportedError);
    });

    test('rejects invalid image sizes and inconsistent residue totals', () {
      final component = _component(id: 1, pixels: [0], areaRatio: 0.25);

      expect(
        () => VisionComponentResult(
          imageSize: (width: 0, height: 2),
          totalResiduePixels: 0,
          components: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionComponentResult(
          imageSize: (width: 2, height: 2),
          totalResiduePixels: 2,
          components: [component],
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final component = _component(id: 1, pixels: [0], areaRatio: 0.25);
      final first = VisionComponentResult(
        imageSize: (width: 2, height: 2),
        totalResiduePixels: 1,
        components: [component],
      );
      final second = VisionComponentResult(
        imageSize: (width: 2, height: 2),
        totalResiduePixels: 1,
        components: [component],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('componentCount: 1'));
    });
  });

  group('CoffeeVisionEngine.detectComponents', () {
    const engine = CoffeeVisionEngine();

    test('returns a Future and an empty result for an empty mask', () async {
      final future = engine.detectComponents(mask: _mask(3, 2, const []));

      expect(future, isA<Future<VisionComponentResult>>());
      final result = await future;
      expect(result.imageSize, (width: 3, height: 2));
      expect(result.componentCount, 0);
      expect(result.totalResiduePixels, 0);
      expect(result.components, isEmpty);
    });

    test(
      'calculates single-pixel geometry from pixel-cell boundaries',
      () async {
        final result = await engine.detectComponents(mask: _mask(4, 2, [5]));
        final component = result.components.single;

        expect(component.id, 1);
        expect(component.pixelCount, 1);
        expect(
          component.boundingBox,
          VisionRect(left: 0.25, top: 0.5, right: 0.5, bottom: 1.0),
        );
        expect(component.centroid, VisionPoint(x: 0.375, y: 0.75));
        expect(component.areaRatio, 1 / 8);
        expect(component.width, 0.25);
        expect(component.height, 0.5);
        expect(component.aspectRatio, 0.5);
        expect(component.fillRatio, 1.0);
        expect(component.touchesBorder, isTrue);
      },
    );

    test('calculates vertical and horizontal line features', () async {
      final vertical = (await engine.detectComponents(
        mask: _mask(5, 5, [7, 12, 17]),
      )).components.single;
      final horizontal = (await engine.detectComponents(
        mask: _mask(5, 5, [11, 12, 13]),
      )).components.single;

      expect(vertical.width, closeTo(0.2, 1e-12));
      expect(vertical.height, closeTo(0.6, 1e-12));
      expect(vertical.aspectRatio, closeTo(1 / 3, 1e-12));
      expect(vertical.fillRatio, 1.0);
      expect(vertical.touchesBorder, isFalse);

      expect(horizontal.width, closeTo(0.6, 1e-12));
      expect(horizontal.height, closeTo(0.2, 1e-12));
      expect(horizontal.aspectRatio, closeTo(3.0, 1e-12));
      expect(horizontal.fillRatio, 1.0);
      expect(horizontal.touchesBorder, isFalse);
    });

    test('calculates filled and hollow rectangle fill ratios', () async {
      final filled = (await engine.detectComponents(
        mask: _mask(5, 5, [6, 7, 11, 12]),
      )).components.single;
      final hollow = (await engine.detectComponents(
        mask: _mask(5, 5, [6, 7, 8, 11, 13, 16, 17, 18]),
      )).components.single;

      expect(filled.width, closeTo(0.4, 1e-12));
      expect(filled.height, closeTo(0.4, 1e-12));
      expect(filled.aspectRatio, 1.0);
      expect(filled.fillRatio, 1.0);
      expect(hollow.fillRatio, closeTo(8 / 9, 1e-12));
    });

    test(
      'detects every image border and excludes a center component',
      () async {
        for (final index in [10, 14, 2, 22]) {
          final component = (await engine.detectComponents(
            mask: _mask(5, 5, [index]),
          )).components.single;
          expect(component.touchesBorder, isTrue);
        }

        final center = (await engine.detectComponents(
          mask: _mask(5, 5, [12]),
        )).components.single;
        expect(center.touchesBorder, isFalse);
      },
    );

    test(
      'keeps diagonally touching pixels in one 8-connected component',
      () async {
        final result = await engine.detectComponents(
          mask: _mask(3, 3, [0, 4, 8]),
        );

        expect(result.componentCount, 1);
        expect(result.components.single.pixels, [0, 4, 8]);
      },
    );

    test('orders components only by row-major discovery', () async {
      final result = await engine.detectComponents(
        mask: _mask(6, 3, [4, 12, 16]),
      );

      expect(result.componentCount, 3);
      expect(result.components.map((component) => component.id), [1, 2, 3]);
      expect(result.components.map((component) => component.pixels.single), [
        4,
        12,
        16,
      ]);
    });

    test('handles a large component without recursive traversal', () async {
      const size = 64;
      final residuePixels = List<int>.generate(size * size, (index) => index);

      final result = await engine.detectComponents(
        mask: _mask(size, size, residuePixels),
      );
      final component = result.components.single;

      expect(component.pixelCount, size * size);
      expect(component.boundingBox, _fullRect());
      expect(component.centroid, VisionPoint(x: 0.5, y: 0.5));
      expect(component.areaRatio, 1.0);
      expect(component.width, 1.0);
      expect(component.height, 1.0);
      expect(component.aspectRatio, 1.0);
      expect(component.fillRatio, 1.0);
      expect(component.touchesBorder, isTrue);
    });

    test('uses the specified bounding-box and centroid formulas', () async {
      final result = await engine.detectComponents(
        mask: _mask(5, 4, [6, 7, 13]),
      );
      final component = result.components.single;

      expect(
        component.boundingBox,
        VisionRect(left: 0.2, top: 0.25, right: 0.8, bottom: 0.75),
      );
      expect(component.centroid.x, closeTo(0.5, 1e-12));
      expect(component.centroid.y, closeTo(5.5 / 12, 1e-12));
      expect(component.areaRatio, 3 / 20);
    });

    test('assigns every residue pixel to exactly one component', () async {
      final residuePixels = [0, 1, 6, 14, 19, 24];
      final result = await engine.detectComponents(
        mask: _mask(5, 5, residuePixels),
      );
      final assignedPixels =
          result.components.expand((component) => component.pixels).toList()
            ..sort();

      expect(result.totalResiduePixels, residuePixels.length);
      expect(assignedPixels, residuePixels);
      expect(assignedPixels.toSet(), hasLength(residuePixels.length));
    });

    test(
      'produces deterministic components and row-major pixel lists',
      () async {
        final mask = _mask(4, 4, [1, 4, 5, 6, 9, 15]);

        final first = await engine.detectComponents(mask: mask);
        final second = await engine.detectComponents(mask: mask);

        expect(second, first);
        expect(first.components.first.pixels, [1, 4, 5, 6, 9]);
        expect(first.components.last.pixels, [15]);
      },
    );
  });
}

VisionComponent _component({
  required int id,
  required Iterable<int> pixels,
  required double areaRatio,
}) {
  return VisionComponent(
    id: id,
    pixels: pixels,
    boundingBox: _fullRect(),
    centroid: VisionPoint(x: 0.5, y: 0.5),
    areaRatio: areaRatio,
  );
}

VisionComponent _detectedComponent({
  required Iterable<int> pixels,
  required int imageWidth,
  required int imageHeight,
}) {
  return VisionComponent.fromDetection(
    id: 1,
    pixels: pixels,
    boundingBox: _fullRect(),
    centroid: VisionPoint(x: 0.5, y: 0.5),
    areaRatio: imageWidth > 0 && imageHeight > 0
        ? pixels.length / (imageWidth * imageHeight)
        : 0.5,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

VisionRect _fullRect() {
  return VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0);
}

ResidueMask _mask(int width, int height, Iterable<int> residueIndices) {
  final pixels = Uint8List(width * height);
  var residuePixelCount = 0;
  for (final index in residueIndices) {
    pixels[index] = 1;
    residuePixelCount++;
  }
  return ResidueMask(
    width: width,
    height: height,
    pixels: pixels,
    residueRatio: residuePixelCount / pixels.length,
  );
}
