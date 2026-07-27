import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('VisionFeatureImageProvenance', () {
    test('stores validated immutable image metadata', () {
      final provenance = _provenance();

      expect(provenance.sourceFormat, VisionImageFormat.png);
      expect(provenance.sourceWidth, 12);
      expect(provenance.sourceHeight, 8);
      expect(provenance.workingFormat, VisionImageFormat.png);
      expect(provenance.workingWidth, 512);
      expect(provenance.workingHeight, 512);
      expect(provenance.workingResolution, 512);
      expect(
        provenance.contentRect,
        VisionRect(left: 0.0, top: 0.125, right: 1.0, bottom: 0.875),
      );
    });

    test('rejects non-positive dimensions and resolution', () {
      expect(() => _provenance(sourceWidth: 0), throwsArgumentError);
      expect(() => _provenance(sourceHeight: -1), throwsArgumentError);
      expect(() => _provenance(workingWidth: 0), throwsArgumentError);
      expect(() => _provenance(workingHeight: -1), throwsArgumentError);
      expect(() => _provenance(workingResolution: 0), throwsArgumentError);
    });

    test('requires square working dimensions matching resolution', () {
      expect(() => _provenance(workingWidth: 256), throwsArgumentError);
      expect(() => _provenance(workingHeight: 256), throwsArgumentError);
    });

    test('rejects a content rectangle with zero area', () {
      expect(
        () => _provenance(
          contentRect: VisionRect(left: 0.5, top: 0.0, right: 0.5, bottom: 1.0),
        ),
        throwsArgumentError,
      );
      expect(
        () => _provenance(
          contentRect: VisionRect(left: 0.0, top: 0.5, right: 1.0, bottom: 0.5),
        ),
        throwsArgumentError,
      );
    });

    test('supports value equality, hashCode, and stable field order', () {
      final first = _provenance();
      final second = _provenance();

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(
        first.toString(),
        'VisionFeatureImageProvenance('
        'sourceFormat: VisionImageFormat.png, sourceSize: 12x8, '
        'workingFormat: VisionImageFormat.png, workingSize: 512x512, '
        'workingResolution: 512, '
        'contentRect: VisionRect(left: 0.0, top: 0.125, right: 1.0, '
        'bottom: 0.875))',
      );
    });
  });

  group('VisionFeatureSet', () {
    test('keeps the M7A metadata-only constructor compatible', () {
      final featureSet = VisionFeatureSet(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'cup-001',
        imageProvenance: _provenance(),
      );

      expect(featureSet.surfaceType, VisionSurfaceType.cup);
      expect(featureSet.sourceId, 'cup-001');
      expect(featureSet.imageProvenance, _provenance());
      expect(featureSet.globalFeatures, isNull);
      expect(featureSet.regionFeatures, isEmpty);
      expect(featureSet.componentFeatures, isEmpty);
      expect(featureSet.edgeSelectionProfile, isNull);
      expect(featureSet.spatialRelationFeatures, isEmpty);
      expect(featureSet.graphStatistics, isNull);
      expect(featureSet.connectedStructureResult, isNull);
      expect(
        () => featureSet.regionFeatures.add(
          VisionRegionFeature(
            regionId: VisionRegionId.top,
            rect: VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
            residueDensity: 0.0,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => featureSet.componentFeatures.add(
          VisionComponentFeature(
            componentId: 1,
            pixelCount: 1,
            boundingBox: VisionRect(
              left: 0.0,
              top: 0.0,
              right: 1.0,
              bottom: 1.0,
            ),
            centroid: VisionPoint(x: 0.5, y: 0.5),
            width: 1.0,
            height: 1.0,
            aspectRatio: 1.0,
            areaRatio: 1.0,
            fillRatio: 1.0,
            touchesBorder: true,
            residueShare: 1.0,
            nearestNeighborComponentId: null,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('supports a null source id', () {
      final featureSet = VisionFeatureSet(
        surfaceType: VisionSurfaceType.saucer,
        imageProvenance: _provenance(),
      );

      expect(featureSet.sourceId, isNull);
    });

    test('supports value equality and hashCode', () {
      final first = VisionFeatureSet(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'same',
        imageProvenance: _provenance(),
      );
      final second = VisionFeatureSet(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'same',
        imageProvenance: _provenance(),
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('safe toString preserves field order without exposing source id', () {
      const sensitiveSourceId = r'C:\private\cup-image.png';
      final featureSet = VisionFeatureSet(
        surfaceType: VisionSurfaceType.cup,
        sourceId: sensitiveSourceId,
        imageProvenance: _provenance(),
      );

      final text = featureSet.toString();
      expect(text, startsWith('VisionFeatureSet(surfaceType: '));
      expect(text, contains('sourceIdPresent: true'));
      expect(text, isNot(contains(sensitiveSourceId)));
      expect(text, isNot(contains('bytes')));
      expect(text, isNot(contains('confidence')));
      expect(text, isNot(contains('symbol')));
      expect(text, isNot(contains('fortune')));
    });
  });
}

VisionFeatureImageProvenance _provenance({
  int sourceWidth = 12,
  int sourceHeight = 8,
  int workingWidth = 512,
  int workingHeight = 512,
  int workingResolution = 512,
  VisionRect? contentRect,
}) {
  return VisionFeatureImageProvenance(
    sourceFormat: VisionImageFormat.png,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    workingFormat: VisionImageFormat.png,
    workingWidth: workingWidth,
    workingHeight: workingHeight,
    workingResolution: workingResolution,
    contentRect:
        contentRect ??
        VisionRect(left: 0.0, top: 0.125, right: 1.0, bottom: 0.875),
  );
}
