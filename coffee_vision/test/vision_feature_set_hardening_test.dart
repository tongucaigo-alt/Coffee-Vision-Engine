import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  group('M7E frozen public contract', () {
    test('keeps the exact approved VisionFeatureSet field inventory', () {
      final source = File(
        'lib/src/models/vision_feature_set.dart',
      ).readAsStringSync();
      final fieldNames = RegExp(
        r'^  final [^;\n]+ ([A-Za-z]\w*);$',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)).toList();

      expect(fieldNames, [
        'surfaceType',
        'sourceId',
        'imageProvenance',
        'globalFeatures',
        'regionFeatures',
        'componentFeatures',
        'edgeSelectionProfile',
        'spatialRelationFeatures',
        'graphStatistics',
        'connectedStructureResult',
      ]);
    });

    test('preserves the M7A, M7B, and M7C compatibility tiers', () async {
      final complete = await _features();

      final m7a = VisionFeatureSet(
        surfaceType: complete.surfaceType,
        sourceId: complete.sourceId,
        imageProvenance: complete.imageProvenance,
      );
      final m7b = VisionFeatureSet.withGlobalAndRegionalFeatures(
        surfaceType: complete.surfaceType,
        sourceId: complete.sourceId,
        imageProvenance: complete.imageProvenance,
        globalFeatures: complete.globalFeatures!,
        regionFeatures: complete.regionFeatures,
      );
      final m7c = VisionFeatureSet.withComponentFeatures(
        surfaceType: complete.surfaceType,
        sourceId: complete.sourceId,
        imageProvenance: complete.imageProvenance,
        globalFeatures: complete.globalFeatures!,
        regionFeatures: complete.regionFeatures,
        componentFeatures: complete.componentFeatures,
      );

      expect(m7a.globalFeatures, isNull);
      expect(m7a.regionFeatures, isEmpty);
      expect(m7b.componentFeatures, isEmpty);
      expect(m7b.edgeSelectionProfile, isNull);
      expect(m7c.componentFeatures, isNotEmpty);
      expect(m7c.spatialRelationFeatures, isEmpty);
      expect(m7c.graphStatistics, isNull);
      expect(m7c.connectedStructureResult, isNull);
    });

    test('public engine output is the complete M7D contract', () async {
      final features = await _features(sourceId: 'm7e-public-contract');

      expect(features.sourceId, 'm7e-public-contract');
      expect(features.globalFeatures, isNotNull);
      expect(
        features.regionFeatures.map((feature) => feature.regionId),
        VisionRegionId.values,
      );
      expect(features.componentFeatures, hasLength(2));
      expect(features.edgeSelectionProfile, isNotNull);
      expect(features.spatialRelationFeatures, hasLength(2));
      expect(features.graphStatistics, isNotNull);
      expect(features.connectedStructureResult, isNotNull);
    });

    test('all nested result collections are unmodifiable', () async {
      final features = await _features();
      final structure = features.connectedStructureResult!.structures.single;

      expect(() => features.regionFeatures.clear(), throwsUnsupportedError);
      expect(() => features.componentFeatures.clear(), throwsUnsupportedError);
      expect(
        () => features.spatialRelationFeatures.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => features.connectedStructureResult!.structures.clear(),
        throwsUnsupportedError,
      );
      expect(() => structure.componentIds.clear(), throwsUnsupportedError);
    });

    test('complete equality and hashCode remain collection-safe', () async {
      final first = await _features(sourceId: 'stable-key');
      final second = await _features(sourceId: 'stable-key');

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(<VisionFeatureSet>{first, second}, hasLength(1));
      expect(<VisionFeatureSet, String>{first: 'first'}[second], 'first');
    });

    test('engine-produced numeric values remain finite and in range', () async {
      final features = await _features();
      final provenance = features.imageProvenance;
      final global = features.globalFeatures!;

      _expectNormalizedRect(provenance.contentRect);
      expect(global.contentResidueRatio.isFinite, isTrue);
      expect(global.contentResidueRatio, inInclusiveRange(0.0, 1.0));
      expect(global.residuePixelCount, greaterThanOrEqualTo(0));
      expect(global.componentCount, greaterThanOrEqualTo(0));
      expect(global.candidateRelationCount, greaterThanOrEqualTo(0));
      expect(global.selectedRelationCount, greaterThanOrEqualTo(0));

      for (final region in features.regionFeatures) {
        _expectNormalizedRect(region.rect);
        expect(region.residueDensity.isFinite, isTrue);
        expect(region.residueDensity, inInclusiveRange(0.0, 1.0));
      }
      for (final component in features.componentFeatures) {
        _expectNormalizedRect(component.boundingBox);
        expect(component.centroid.x.isFinite, isTrue);
        expect(component.centroid.y.isFinite, isTrue);
        expect(component.width.isFinite, isTrue);
        expect(component.height.isFinite, isTrue);
        expect(component.aspectRatio.isFinite, isTrue);
        expect(component.areaRatio, inInclusiveRange(0.0, 1.0));
        expect(component.fillRatio, inInclusiveRange(0.0, 1.0));
        expect(component.residueShare, inInclusiveRange(0.0, 1.0));
      }
      for (final relation in features.spatialRelationFeatures) {
        expect(relation.centroidDistance.isFinite, isTrue);
        expect(relation.centroidDistance, greaterThanOrEqualTo(0.0));
        expect(relation.boundingBoxDistance.isFinite, isTrue);
        expect(relation.boundingBoxDistance, greaterThanOrEqualTo(0.0));
      }
      expect(features.graphStatistics!.averageDegree.isFinite, isTrue);
      expect(
        features.graphStatistics!.averageDegree,
        greaterThanOrEqualTo(0.0),
      );
    });

    test('invalid component and relation references remain rejected', () async {
      final features = await _features();
      final firstRelation = features.spatialRelationFeatures.first;
      final firstComponent = features.componentFeatures.first;

      expect(
        () => _rebuild(features, relations: [firstRelation]),
        throwsArgumentError,
      );
      expect(
        () => _rebuild(features, relations: [firstRelation, firstRelation]),
        throwsArgumentError,
      );
      expect(
        () => VisionComponentRelation(
          sourceComponentId: firstComponent.componentId,
          targetComponentId: firstComponent.componentId,
          centroidDistance: 0.0,
          boundingBoxDistance: 0.0,
          relativeDirection: VisionRelativeDirection.overlappingCenter,
          boundingBoxesTouch: false,
          boundingBoxesIntersect: true,
        ),
        throwsArgumentError,
      );

      final invalidNearest = VisionComponentFeature(
        componentId: firstComponent.componentId,
        pixelCount: firstComponent.pixelCount,
        boundingBox: firstComponent.boundingBox,
        centroid: firstComponent.centroid,
        width: firstComponent.width,
        height: firstComponent.height,
        aspectRatio: firstComponent.aspectRatio,
        areaRatio: firstComponent.areaRatio,
        fillRatio: firstComponent.fillRatio,
        touchesBorder: firstComponent.touchesBorder,
        residueShare: firstComponent.residueShare,
        nearestNeighborComponentId: 999,
      );
      expect(
        () => VisionFeatureSet.withComponentFeatures(
          surfaceType: features.surfaceType,
          sourceId: features.sourceId,
          imageProvenance: features.imageProvenance,
          globalFeatures: features.globalFeatures!,
          regionFeatures: features.regionFeatures,
          componentFeatures: [invalidNearest, features.componentFeatures.last],
        ),
        throwsArgumentError,
      );
    });

    test(
      'canonical identities and collection ordering are preserved',
      () async {
        final features = await _features();

        expect(
          features.regionFeatures.map((feature) => feature.regionId).toList(),
          VisionRegionId.values,
        );
        _expectSorted(
          features.componentFeatures.map((feature) => feature.componentId),
        );

        final relationKeys = features.spatialRelationFeatures
            .map(
              (feature) =>
                  feature.sourceComponentId * 1000000 +
                  feature.targetComponentId,
            )
            .toList();
        _expectSorted(relationKeys);

        final structures = features.connectedStructureResult!.structures;
        _expectSorted(
          structures.map((structure) => structure.componentIds.first),
        );
        for (final structure in structures) {
          _expectSorted(structure.componentIds);
        }
      },
    );

    test('zero-residue input keeps the canonical empty state', () async {
      final features = await _features(darkPixels: const []);

      expect(features.globalFeatures!.residuePixelCount, 0);
      expect(features.componentFeatures, isEmpty);
      expect(features.spatialRelationFeatures, isEmpty);
      expect(features.graphStatistics!.componentCount, 0);
      expect(features.graphStatistics!.relationCount, 0);
      expect(features.connectedStructureResult!.structures, isEmpty);
    });

    test('single component remains one isolated physical structure', () async {
      final features = await _features(darkPixels: const [(x: 3, y: 3)]);
      final component = features.componentFeatures.single;
      final structure = features.connectedStructureResult!.structures.single;

      expect(component.residueShare, 1.0);
      expect(component.nearestNeighborComponentId, isNull);
      expect(features.spatialRelationFeatures, isEmpty);
      expect(features.graphStatistics!.isolatedComponentCount, 1);
      expect(structure.componentIds, [component.componentId]);
      expect(structure.isIsolated, isTrue);
    });

    test(
      'cup and saucer context propagate without feature divergence',
      () async {
        final cup = await _features(
          surfaceType: VisionSurfaceType.cup,
          sourceId: 'cup-source',
        );
        final saucer = await _features(
          surfaceType: VisionSurfaceType.saucer,
          sourceId: 'saucer-source',
        );

        expect(cup.surfaceType, VisionSurfaceType.cup);
        expect(cup.sourceId, 'cup-source');
        expect(saucer.surfaceType, VisionSurfaceType.saucer);
        expect(saucer.sourceId, 'saucer-source');
        expect(saucer.imageProvenance, cup.imageProvenance);
        expect(saucer.globalFeatures, cup.globalFeatures);
        expect(saucer.regionFeatures, cup.regionFeatures);
        expect(saucer.componentFeatures, cup.componentFeatures);
        expect(saucer.spatialRelationFeatures, cup.spatialRelationFeatures);
        expect(saucer.graphStatistics, cup.graphStatistics);
        expect(saucer.connectedStructureResult, cup.connectedStructureResult);
      },
    );

    test('three repeated runs are exactly deterministic', () async {
      final input = _input(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'deterministic-source',
        darkPixels: _twoComponents,
      );
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );

      final results = <VisionFeatureSet>[
        await engine.analyzeFeatures(input),
        await engine.analyzeFeatures(input),
        await engine.analyzeFeatures(input),
      ];

      expect(results.toSet(), hasLength(1));
      expect(results[1].hashCode, results[0].hashCode);
      expect(results[2].hashCode, results[0].hashCode);
    });

    test(
      'analyzeFeatures delegates once and legacy engine methods stay separate',
      () {
        final source = File(
          'lib/src/coffee_vision_engine.dart',
        ).readAsStringSync();
        final detailedBlock = _sourceBlock(
          source,
          'Future<VisionPipelineResult> analyzeDetailed',
          'Future<VisionFeatureSet> analyzeFeatures',
        );
        final featureBlock = _sourceBlock(
          source,
          'Future<VisionFeatureSet> analyzeFeatures',
          'Future<VisionObservation> analyze',
        );
        final observationBlock = source.substring(
          source.indexOf('Future<VisionObservation> analyze'),
        );

        expect(detailedBlock, contains('_VisionPipeline'));
        expect(detailedBlock, contains('.analyze('));
        expect(featureBlock, contains('VisionFeatureExtractor().analyze'));
        expect(
          RegExp(r'analyzeDetailed\(').allMatches(featureBlock),
          hasLength(1),
        );
        expect(observationBlock, contains('prepareWorkingImage(input)'));
        expect(observationBlock, contains('confidence: 0.0'));
      },
    );

    test('M5 and FeatureSet source boundaries remain frozen', () {
      final featureSources = [
        'lib/src/models/vision_feature_set.dart',
        'lib/src/models/vision_feature_image_provenance.dart',
        'lib/src/models/vision_global_features.dart',
        'lib/src/models/vision_region_feature.dart',
        'lib/src/models/vision_component_feature.dart',
        'lib/src/models/vision_spatial_relation_feature.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final declarationLines = featureSources
          .split('\n')
          .where(
            (line) =>
                line.startsWith('  final ') ||
                RegExp(r'^  [A-Za-z].* get [A-Za-z]').hasMatch(line),
          )
          .join('\n')
          .toLowerCase();

      for (final forbidden in [
        'symbol',
        'semantic',
        'fortune',
        'confidence',
        'quality',
        'meaning',
        'interpretation',
        'prediction',
      ]) {
        expect(declarationLines, isNot(contains(forbidden)), reason: forbidden);
      }

      final pipelineResultSource = File(
        'lib/src/models/vision_pipeline_result.dart',
      ).readAsStringSync();
      expect(pipelineResultSource, isNot(contains('VisionFeatureSet')));

      final validationSource = Directory('tool/validation')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(validationSource, contains('analyzeDetailed('));
      expect(validationSource, isNot(contains('analyzeFeatures(')));
    });
  });
}

const _twoComponents = [(x: 1, y: 1), (x: 6, y: 6)];

Future<VisionFeatureSet> _features({
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
  String? sourceId,
  Iterable<({int x, int y})> darkPixels = _twoComponents,
}) {
  return const CoffeeVisionEngine(
    config: VisionConfig(workingResolution: 8),
  ).analyzeFeatures(
    _input(
      surfaceType: surfaceType,
      sourceId: sourceId,
      darkPixels: darkPixels,
    ),
  );
}

VisionImageInput _input({
  required VisionSurfaceType surfaceType,
  required String? sourceId,
  required Iterable<({int x, int y})> darkPixels,
}) {
  final source = image.Image(width: 8, height: 8, numChannels: 4);
  final darkPixelSet = darkPixels.toSet();
  for (final pixel in source) {
    final value = darkPixelSet.contains((x: pixel.x, y: pixel.y)) ? 0 : 255;
    pixel.setRgba(value, value, value, 255);
  }
  return VisionImageInput(
    imageBytes: Uint8List.fromList(image.encodePng(source)),
    surfaceType: surfaceType,
    sourceId: sourceId,
  );
}

VisionFeatureSet _rebuild(
  VisionFeatureSet source, {
  required Iterable<VisionSpatialRelationFeature> relations,
}) {
  return VisionFeatureSet.withSpatialAndConnectivityFeatures(
    surfaceType: source.surfaceType,
    sourceId: source.sourceId,
    imageProvenance: source.imageProvenance,
    globalFeatures: source.globalFeatures!,
    regionFeatures: source.regionFeatures,
    componentFeatures: source.componentFeatures,
    edgeSelectionProfile: source.edgeSelectionProfile!,
    spatialRelationFeatures: relations,
    graphStatistics: source.graphStatistics!,
    connectedStructureResult: source.connectedStructureResult!,
  );
}

void _expectNormalizedRect(VisionRect rect) {
  for (final value in [rect.left, rect.top, rect.right, rect.bottom]) {
    expect(value.isFinite, isTrue);
    expect(value, inInclusiveRange(0.0, 1.0));
  }
  expect(rect.width, greaterThan(0.0));
  expect(rect.height, greaterThan(0.0));
}

void _expectSorted(Iterable<int> values) {
  final actual = values.toList();
  final sorted = [...actual]..sort();
  expect(actual, sorted);
}

String _sourceBlock(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return source.substring(start, end);
}
