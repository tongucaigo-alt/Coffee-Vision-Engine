import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('VisionGlobalFeatures', () {
    test('stores physical measurements with value semantics', () {
      final first = _globalFeatures();
      final second = _globalFeatures();

      expect(first.residuePixelCount, 32);
      expect(first.contentResidueRatio, 0.123456789012345);
      expect(first.componentCount, 3);
      expect(first.candidateRelationCount, 6);
      expect(first.selectedRelationCount, 2);
      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(
        first.toString(),
        'VisionGlobalFeatures(residuePixelCount: 32, '
        'contentResidueRatio: 0.123456789012345, componentCount: 3, '
        'candidateRelationCount: 6, selectedRelationCount: 2)',
      );
    });

    test('rejects negative counts', () {
      expect(() => _globalFeatures(residuePixelCount: -1), throwsArgumentError);
      expect(() => _globalFeatures(componentCount: -1), throwsArgumentError);
      expect(
        () => _globalFeatures(candidateRelationCount: -1),
        throwsArgumentError,
      );
      expect(
        () => _globalFeatures(selectedRelationCount: -1),
        throwsArgumentError,
      );
    });

    test('rejects non-finite and out-of-range residue ratios', () {
      for (final value in [double.nan, double.infinity, -0.1, 1.1]) {
        expect(
          () => _globalFeatures(contentResidueRatio: value),
          throwsArgumentError,
        );
      }
    });

    test('rejects a selected count above the candidate count', () {
      expect(
        () => _globalFeatures(
          candidateRelationCount: 1,
          selectedRelationCount: 2,
        ),
        throwsArgumentError,
      );
    });
  });

  group('VisionRegionFeature', () {
    test('stores normalized physical measurements with value semantics', () {
      final first = _regionFeature(VisionRegionId.center, density: 0.75);
      final second = _regionFeature(VisionRegionId.center, density: 0.75);

      expect(first.regionId, VisionRegionId.center);
      expect(first.rect, _rectFor(VisionRegionId.center));
      expect(first.residueDensity, 0.75);
      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toString(), contains('residueDensity: 0.75'));
    });

    test('rejects zero-area geometry', () {
      expect(
        () => VisionRegionFeature(
          regionId: VisionRegionId.top,
          rect: VisionRect(left: 0.5, top: 0.0, right: 0.5, bottom: 1.0),
          residueDensity: 0.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite and out-of-range density', () {
      for (final value in [double.nan, double.negativeInfinity, -0.1, 1.1]) {
        expect(
          () => _regionFeature(VisionRegionId.top, density: value),
          throwsArgumentError,
        );
      }
    });
  });

  group('VisionFeatureSet M7B contract', () {
    test('canonicalizes and defensively freezes all six regions', () {
      final source = VisionRegionId.values.reversed
          .map(_regionFeature)
          .toList();
      final featureSet = VisionFeatureSet.withGlobalAndRegionalFeatures(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'cup-001',
        imageProvenance: _provenance(),
        globalFeatures: _globalFeatures(),
        regionFeatures: source,
      );

      source.clear();

      expect(featureSet.globalFeatures, _globalFeatures());
      expect(
        featureSet.regionFeatures.map((feature) => feature.regionId),
        VisionRegionId.values,
      );
      expect(featureSet.regionFeatures, hasLength(6));
      expect(featureSet.componentFeatures, isEmpty);
      expect(featureSet.edgeSelectionProfile, isNull);
      expect(featureSet.spatialRelationFeatures, isEmpty);
      expect(featureSet.graphStatistics, isNull);
      expect(featureSet.connectedStructureResult, isNull);
      expect(
        () => featureSet.regionFeatures.add(_regionFeature(VisionRegionId.top)),
        throwsUnsupportedError,
      );
    });

    test('rejects missing and duplicate canonical regions', () {
      expect(
        () => VisionFeatureSet.withGlobalAndRegionalFeatures(
          surfaceType: VisionSurfaceType.cup,
          imageProvenance: _provenance(),
          globalFeatures: _globalFeatures(),
          regionFeatures: VisionRegionId.values.skip(1).map(_regionFeature),
        ),
        throwsArgumentError,
      );

      final duplicate = VisionRegionId.values.map(_regionFeature).toList();
      duplicate[5] = _regionFeature(VisionRegionId.top);
      expect(
        () => VisionFeatureSet.withGlobalAndRegionalFeatures(
          surfaceType: VisionSurfaceType.cup,
          imageProvenance: _provenance(),
          globalFeatures: _globalFeatures(),
          regionFeatures: duplicate,
        ),
        throwsArgumentError,
      );
    });

    test('includes M7B fields in equality and hashCode', () {
      final first = _featureSet();
      final second = _featureSet();
      final changed = VisionFeatureSet.withGlobalAndRegionalFeatures(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'cup-001',
        imageProvenance: _provenance(),
        globalFeatures: _globalFeatures(selectedRelationCount: 1),
        regionFeatures: VisionRegionId.values.map(_regionFeature),
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(changed, isNot(first));
    });

    test('safe toString reports presence without exposing source id', () {
      final featureSet = _featureSet(sourceId: r'C:\private\cup.png');
      final text = featureSet.toString();

      expect(text, contains('globalFeaturesPresent: true'));
      expect(text, contains('regionFeatureCount: 6'));
      expect(text, isNot(contains(r'C:\private\cup.png')));
      expect(text, isNot(contains('symbol')));
      expect(text, isNot(contains('fortune')));
      expect(text, isNot(contains('confidence')));
    });
  });
}

VisionGlobalFeatures _globalFeatures({
  int residuePixelCount = 32,
  double contentResidueRatio = 0.123456789012345,
  int componentCount = 3,
  int candidateRelationCount = 6,
  int selectedRelationCount = 2,
}) {
  return VisionGlobalFeatures(
    residuePixelCount: residuePixelCount,
    contentResidueRatio: contentResidueRatio,
    componentCount: componentCount,
    candidateRelationCount: candidateRelationCount,
    selectedRelationCount: selectedRelationCount,
  );
}

VisionRegionFeature _regionFeature(VisionRegionId id, {double density = 0.25}) {
  return VisionRegionFeature(
    regionId: id,
    rect: _rectFor(id),
    residueDensity: density,
  );
}

VisionRect _rectFor(VisionRegionId id) {
  final index = VisionRegionId.values.indexOf(id);
  final left = index / 12;
  return VisionRect(left: left, top: 0.0, right: left + 1 / 12, bottom: 1.0);
}

VisionFeatureSet _featureSet({String? sourceId = 'cup-001'}) {
  return VisionFeatureSet.withGlobalAndRegionalFeatures(
    surfaceType: VisionSurfaceType.cup,
    sourceId: sourceId,
    imageProvenance: _provenance(),
    globalFeatures: _globalFeatures(),
    regionFeatures: VisionRegionId.values.map(_regionFeature),
  );
}

VisionFeatureImageProvenance _provenance() {
  return VisionFeatureImageProvenance(
    sourceFormat: VisionImageFormat.png,
    sourceWidth: 12,
    sourceHeight: 8,
    workingFormat: VisionImageFormat.png,
    workingWidth: 512,
    workingHeight: 512,
    workingResolution: 512,
    contentRect: VisionRect(left: 0.0, top: 0.125, right: 1.0, bottom: 0.875),
  );
}
