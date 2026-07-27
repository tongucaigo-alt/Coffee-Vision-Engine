import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  const engine = CoffeeVisionEngine();

  group('VisionAnalysisRegion', () {
    test('is immutable data with consistent equality and hashCode', () {
      final first = VisionAnalysisRegion(
        id: VisionRegionId.top,
        rect: VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1 / 3),
        surfaceType: VisionSurfaceType.cup,
      );
      final second = VisionAnalysisRegion(
        id: VisionRegionId.top,
        rect: VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1 / 3),
        surfaceType: VisionSurfaceType.cup,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'VisionAnalysisRegion(id: VisionRegionId.top, '
        'rect: VisionRect(left: 0.0, top: 0.0, right: 1.0, '
        'bottom: 0.3333333333333333), surfaceType: VisionSurfaceType.cup)',
      );
    });
  });

  group('CoffeeVisionEngine.createAnalysisRegions', () {
    test('returns six unique regions in deterministic order', () {
      final regions = engine.createAnalysisRegions(
        workingImage: _workingImage(),
        surfaceType: VisionSurfaceType.cup,
      );

      expect(regions.map((region) => region.id), [
        VisionRegionId.top,
        VisionRegionId.middle,
        VisionRegionId.bottom,
        VisionRegionId.left,
        VisionRegionId.center,
        VisionRegionId.right,
      ]);
      expect(regions.map((region) => region.id).toSet(), hasLength(6));
    });

    test('divides a full-frame content rect into equal overlapping bands', () {
      final regions = _byId(
        engine.createAnalysisRegions(
          workingImage: _workingImage(),
          surfaceType: VisionSurfaceType.cup,
        ),
      );

      _expectRect(regions[VisionRegionId.top]!.rect, 0, 0, 1, 1 / 3);
      _expectRect(regions[VisionRegionId.middle]!.rect, 0, 1 / 3, 1, 2 / 3);
      _expectRect(regions[VisionRegionId.bottom]!.rect, 0, 2 / 3, 1, 1);
      _expectRect(regions[VisionRegionId.left]!.rect, 0, 0, 1 / 3, 1);
      _expectRect(regions[VisionRegionId.center]!.rect, 1 / 3, 0, 2 / 3, 1);
      _expectRect(regions[VisionRegionId.right]!.rect, 2 / 3, 0, 1, 1);
    });

    test('keeps every region inside a padded content rect', () {
      final contentRect = VisionRect(
        left: 0.2,
        top: 0.1,
        right: 0.8,
        bottom: 0.9,
      );
      final regions = engine.createAnalysisRegions(
        workingImage: _workingImage(contentRect: contentRect),
        surfaceType: VisionSurfaceType.cup,
      );

      for (final region in regions) {
        expect(region.rect.left, greaterThanOrEqualTo(contentRect.left));
        expect(region.rect.top, greaterThanOrEqualTo(contentRect.top));
        expect(region.rect.right, lessThanOrEqualTo(contentRect.right));
        expect(region.rect.bottom, lessThanOrEqualTo(contentRect.bottom));
      }
    });

    test('tiles the content rect within each band direction', () {
      final contentRect = VisionRect(
        left: 0.2,
        top: 0.1,
        right: 0.8,
        bottom: 0.9,
      );
      final regions = _byId(
        engine.createAnalysisRegions(
          workingImage: _workingImage(contentRect: contentRect),
          surfaceType: VisionSurfaceType.cup,
        ),
      );
      final top = regions[VisionRegionId.top]!.rect;
      final middle = regions[VisionRegionId.middle]!.rect;
      final bottom = regions[VisionRegionId.bottom]!.rect;
      final left = regions[VisionRegionId.left]!.rect;
      final center = regions[VisionRegionId.center]!.rect;
      final right = regions[VisionRegionId.right]!.rect;

      expect(top.top, contentRect.top);
      expect(top.bottom, closeTo(middle.top, 1e-12));
      expect(middle.bottom, closeTo(bottom.top, 1e-12));
      expect(bottom.bottom, contentRect.bottom);
      expect(left.left, contentRect.left);
      expect(left.right, closeTo(center.left, 1e-12));
      expect(center.right, closeTo(right.left, 1e-12));
      expect(right.right, contentRect.right);
    });

    test('uses the same geometry API for cup and saucer', () {
      final image = _workingImage();
      final cupRegions = engine.createAnalysisRegions(
        workingImage: image,
        surfaceType: VisionSurfaceType.cup,
      );
      final saucerRegions = engine.createAnalysisRegions(
        workingImage: image,
        surfaceType: VisionSurfaceType.saucer,
      );

      expect(
        saucerRegions.map((region) => region.rect),
        cupRegions.map((region) => region.rect),
      );
      expect(
        cupRegions.every(
          (region) => region.surfaceType == VisionSurfaceType.cup,
        ),
        isTrue,
      );
      expect(
        saucerRegions.every(
          (region) => region.surfaceType == VisionSurfaceType.saucer,
        ),
        isTrue,
      );
    });

    test('is independent from working-image resolution', () {
      final contentRect = VisionRect(
        left: 0.125,
        top: 0.25,
        right: 0.875,
        bottom: 0.75,
      );
      final lowResolution = engine.createAnalysisRegions(
        workingImage: _workingImage(contentRect: contentRect, resolution: 256),
        surfaceType: VisionSurfaceType.cup,
      );
      final highResolution = engine.createAnalysisRegions(
        workingImage: _workingImage(contentRect: contentRect, resolution: 1024),
        surfaceType: VisionSurfaceType.cup,
      );

      expect(
        highResolution.map((region) => region.rect),
        lowResolution.map((region) => region.rect),
      );
    });

    test('returns an unmodifiable result list', () {
      final regions = engine.createAnalysisRegions(
        workingImage: _workingImage(),
        surfaceType: VisionSurfaceType.cup,
      );

      expect(() => regions.add(regions.first), throwsUnsupportedError);
    });

    test('uses contentRect from the public preparation pipeline', () async {
      final bytes = await File('test/fixtures/valid_2x3.png').readAsBytes();
      final workingImage = await engine.prepareWorkingImage(
        VisionImageInput(
          imageBytes: bytes,
          surfaceType: VisionSurfaceType.saucer,
        ),
      );
      final regions = engine.createAnalysisRegions(
        workingImage: workingImage,
        surfaceType: VisionSurfaceType.saucer,
      );

      for (final region in regions) {
        expect(
          region.rect.left,
          greaterThanOrEqualTo(workingImage.contentRect.left),
        );
        expect(
          region.rect.right,
          lessThanOrEqualTo(workingImage.contentRect.right),
        );
      }
    });
  });
}

WorkingImage _workingImage({VisionRect? contentRect, int resolution = 512}) {
  final metadata = VisionImageMetadata(
    format: VisionImageFormat.png,
    width: resolution,
    height: resolution,
  );
  return WorkingImage(
    bytes: Uint8List.fromList([1]),
    metadata: metadata,
    contentRect: contentRect,
    resolution: resolution,
  );
}

Map<VisionRegionId, VisionAnalysisRegion> _byId(
  List<VisionAnalysisRegion> regions,
) {
  return {for (final region in regions) region.id: region};
}

void _expectRect(
  VisionRect rect,
  double left,
  double top,
  double right,
  double bottom,
) {
  expect(rect.left, closeTo(left, 1e-12));
  expect(rect.top, closeTo(top, 1e-12));
  expect(rect.right, closeTo(right, 1e-12));
  expect(rect.bottom, closeTo(bottom, 1e-12));
}
