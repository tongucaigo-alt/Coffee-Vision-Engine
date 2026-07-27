import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('VisionComponentFeature', () {
    test('stores direct physical values with value semantics', () {
      final first = _componentFeature(
        componentId: 7,
        pixelCount: 20,
        residuePixelCount: 40,
        nearestNeighborComponentId: 11,
      );
      final second = _componentFeature(
        componentId: 7,
        pixelCount: 20,
        residuePixelCount: 40,
        nearestNeighborComponentId: 11,
      );

      expect(first.componentId, 7);
      expect(first.pixelCount, 20);
      expect(first.boundingBox, _box());
      expect(first.centroid, _box().center);
      expect(first.width, _box().width);
      expect(first.height, _box().height);
      expect(first.aspectRatio, _box().width / _box().height);
      expect(first.areaRatio, 0.125);
      expect(first.fillRatio, 0.625);
      expect(first.touchesBorder, isFalse);
      expect(first.residueShare, 0.5);
      expect(first.nearestNeighborComponentId, 11);
      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toString(), contains('componentId: 7'));
      expect(first.toString(), isNot(contains('pixels:')));
      expect(first.toString(), isNot(contains('symbol')));
      expect(first.toString(), isNot(contains('fortune')));
    });

    test('rejects invalid identities, counts, and nearest neighbors', () {
      expect(() => _componentFeature(componentId: 0), throwsArgumentError);
      expect(() => _componentFeature(pixelCount: 0), throwsArgumentError);
      expect(
        () => _componentFeature(nearestNeighborComponentId: 1),
        throwsArgumentError,
      );
      expect(
        () => _componentFeature(nearestNeighborComponentId: -1),
        throwsArgumentError,
      );
    });

    test('rejects degenerate geometry and an outside centroid', () {
      expect(
        () => _componentFeature(
          boundingBox: VisionRect(left: 0.5, top: 0.0, right: 0.5, bottom: 1.0),
        ),
        throwsArgumentError,
      );
      expect(
        () => _componentFeature(centroid: VisionPoint(x: 0.9, y: 0.9)),
        throwsArgumentError,
      );
    });

    test('rejects non-finite and non-positive measurements', () {
      for (final value in [double.nan, double.infinity, 0.0, -0.1]) {
        expect(() => _componentFeature(width: value), throwsArgumentError);
        expect(() => _componentFeature(height: value), throwsArgumentError);
        expect(
          () => _componentFeature(aspectRatio: value),
          throwsArgumentError,
        );
      }
      for (final value in [
        double.nan,
        double.negativeInfinity,
        0.0,
        -0.1,
        1.1,
      ]) {
        expect(() => _componentFeature(areaRatio: value), throwsArgumentError);
        expect(() => _componentFeature(fillRatio: value), throwsArgumentError);
        expect(
          () => _componentFeature(residueShare: value),
          throwsArgumentError,
        );
      }
    });

    test('validates stored geometry fields without deriving replacements', () {
      expect(() => _componentFeature(width: 0.3), throwsArgumentError);
      expect(() => _componentFeature(height: 0.3), throwsArgumentError);
      expect(() => _componentFeature(aspectRatio: 2.0), throwsArgumentError);
    });
  });

  group('VisionFeatureSet M7C contract', () {
    test('preserves IDs and canonicalizes only by ascending component ID', () {
      final source = [
        _componentFeature(
          componentId: 10,
          pixelCount: 20,
          residuePixelCount: 60,
          nearestNeighborComponentId: 7,
        ),
        _componentFeature(
          componentId: 2,
          pixelCount: 30,
          residuePixelCount: 60,
          nearestNeighborComponentId: 7,
        ),
        _componentFeature(
          componentId: 7,
          pixelCount: 10,
          residuePixelCount: 60,
          nearestNeighborComponentId: 2,
        ),
      ];
      final featureSet = _featureSet(
        globalFeatures: _globalFeatures(
          residuePixelCount: 60,
          componentCount: 3,
        ),
        componentFeatures: source,
      );

      source.clear();

      expect(
        featureSet.componentFeatures.map((feature) => feature.componentId),
        [2, 7, 10],
      );
      expect(
        featureSet.componentFeatures.map((feature) => feature.pixelCount),
        [30, 10, 20],
        reason: 'component ordering must not use size or pixel count',
      );
      expect(
        () => featureSet.componentFeatures.add(
          _componentFeature(componentId: 20, nearestNeighborComponentId: 2),
        ),
        throwsUnsupportedError,
      );
      expect(featureSet.edgeSelectionProfile, isNull);
      expect(featureSet.spatialRelationFeatures, isEmpty);
      expect(featureSet.graphStatistics, isNull);
      expect(featureSet.connectedStructureResult, isNull);
    });

    test('supports an empty residue and component state', () {
      final featureSet = _featureSet(
        globalFeatures: _globalFeatures(
          residuePixelCount: 0,
          componentCount: 0,
        ),
        componentFeatures: const [],
      );

      expect(featureSet.componentFeatures, isEmpty);
    });

    test('supports one component with full share and no nearest neighbor', () {
      final featureSet = _featureSet(
        globalFeatures: _globalFeatures(
          residuePixelCount: 12,
          componentCount: 1,
        ),
        componentFeatures: [
          _componentFeature(
            componentId: 9,
            pixelCount: 12,
            residuePixelCount: 12,
          ),
        ],
      );

      expect(featureSet.componentFeatures.single.componentId, 9);
      expect(featureSet.componentFeatures.single.residueShare, 1.0);
      expect(
        featureSet.componentFeatures.single.nearestNeighborComponentId,
        isNull,
      );
    });

    test('rejects duplicate IDs and cross-collection inconsistencies', () {
      final first = _componentFeature(
        componentId: 2,
        pixelCount: 10,
        residuePixelCount: 20,
        nearestNeighborComponentId: 7,
      );
      final second = _componentFeature(
        componentId: 7,
        pixelCount: 10,
        residuePixelCount: 20,
        nearestNeighborComponentId: 2,
      );

      expect(
        () => _featureSet(
          globalFeatures: _globalFeatures(
            residuePixelCount: 20,
            componentCount: 2,
          ),
          componentFeatures: [first, first],
        ),
        throwsArgumentError,
      );
      expect(
        () => _featureSet(
          globalFeatures: _globalFeatures(
            residuePixelCount: 20,
            componentCount: 1,
          ),
          componentFeatures: [first, second],
        ),
        throwsArgumentError,
      );
      expect(
        () => _featureSet(
          globalFeatures: _globalFeatures(
            residuePixelCount: 21,
            componentCount: 2,
          ),
          componentFeatures: [first, second],
        ),
        throwsArgumentError,
      );
      expect(
        () => _featureSet(
          globalFeatures: _globalFeatures(
            residuePixelCount: 20,
            componentCount: 2,
          ),
          componentFeatures: [
            first,
            _componentFeature(
              componentId: 7,
              pixelCount: 10,
              residuePixelCount: 20,
              nearestNeighborComponentId: 99,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects rounded or otherwise altered residue shares', () {
      expect(
        () => _featureSet(
          globalFeatures: _globalFeatures(
            residuePixelCount: 3,
            componentCount: 1,
          ),
          componentFeatures: [
            _componentFeature(
              componentId: 4,
              pixelCount: 3,
              residuePixelCount: 3,
              residueShare: 0.999,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('includes component features in equality and safe toString', () {
      final first = _featureSet(
        globalFeatures: _globalFeatures(
          residuePixelCount: 12,
          componentCount: 1,
        ),
        componentFeatures: [
          _componentFeature(
            componentId: 9,
            pixelCount: 12,
            residuePixelCount: 12,
          ),
        ],
      );
      final second = _featureSet(
        globalFeatures: _globalFeatures(
          residuePixelCount: 12,
          componentCount: 1,
        ),
        componentFeatures: [
          _componentFeature(
            componentId: 9,
            pixelCount: 12,
            residuePixelCount: 12,
          ),
        ],
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toString(), contains('componentFeatureCount: 1'));
      expect(first.toString(), isNot(contains('pixels')));
    });
  });
}

VisionComponentFeature _componentFeature({
  int componentId = 1,
  int pixelCount = 10,
  int residuePixelCount = 20,
  VisionRect? boundingBox,
  VisionPoint? centroid,
  double? width,
  double? height,
  double? aspectRatio,
  double areaRatio = 0.125,
  double fillRatio = 0.625,
  bool touchesBorder = false,
  double? residueShare,
  int? nearestNeighborComponentId,
}) {
  final box = boundingBox ?? _box();
  final componentWidth = width ?? box.width;
  final componentHeight = height ?? box.height;
  return VisionComponentFeature(
    componentId: componentId,
    pixelCount: pixelCount,
    boundingBox: box,
    centroid: centroid ?? box.center,
    width: componentWidth,
    height: componentHeight,
    aspectRatio: aspectRatio ?? componentWidth / componentHeight,
    areaRatio: areaRatio,
    fillRatio: fillRatio,
    touchesBorder: touchesBorder,
    residueShare: residueShare ?? pixelCount / residuePixelCount,
    nearestNeighborComponentId: nearestNeighborComponentId,
  );
}

VisionFeatureSet _featureSet({
  required VisionGlobalFeatures globalFeatures,
  required Iterable<VisionComponentFeature> componentFeatures,
}) {
  return VisionFeatureSet.withComponentFeatures(
    surfaceType: VisionSurfaceType.cup,
    imageProvenance: _provenance(),
    globalFeatures: globalFeatures,
    regionFeatures: VisionRegionId.values.map(_regionFeature),
    componentFeatures: componentFeatures,
  );
}

VisionGlobalFeatures _globalFeatures({
  required int residuePixelCount,
  required int componentCount,
}) {
  return VisionGlobalFeatures(
    residuePixelCount: residuePixelCount,
    contentResidueRatio: residuePixelCount == 0 ? 0.0 : 0.25,
    componentCount: componentCount,
    candidateRelationCount: componentCount * (componentCount - 1),
    selectedRelationCount: componentCount * (componentCount - 1),
  );
}

VisionRegionFeature _regionFeature(VisionRegionId id) {
  final index = VisionRegionId.values.indexOf(id);
  final left = index / 12;
  return VisionRegionFeature(
    regionId: id,
    rect: VisionRect(left: left, top: 0.0, right: left + 1 / 12, bottom: 1.0),
    residueDensity: 0.0,
  );
}

VisionFeatureImageProvenance _provenance() {
  return VisionFeatureImageProvenance(
    sourceFormat: VisionImageFormat.png,
    sourceWidth: 8,
    sourceHeight: 8,
    workingFormat: VisionImageFormat.png,
    workingWidth: 8,
    workingHeight: 8,
    workingResolution: 8,
    contentRect: VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
  );
}

VisionRect _box() {
  return VisionRect(left: 0.1, top: 0.2, right: 0.5, bottom: 0.6);
}
