import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:coffee_vision/src/vision_feature_extractor.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  group('CoffeeVisionEngine.analyzeFeatures', () {
    test('returns cup context and PNG provenance', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 4,
        height: 2,
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'cup-sample',
      );

      final result = await engine.analyzeFeatures(input);

      expect(result.surfaceType, VisionSurfaceType.cup);
      expect(result.sourceId, 'cup-sample');
      expect(result.imageProvenance.sourceFormat, VisionImageFormat.png);
      expect(result.imageProvenance.sourceWidth, 4);
      expect(result.imageProvenance.sourceHeight, 2);
      expect(result.imageProvenance.workingFormat, VisionImageFormat.png);
      expect(result.imageProvenance.workingWidth, 8);
      expect(result.imageProvenance.workingHeight, 8);
      expect(result.imageProvenance.workingResolution, 8);
      expect(result.imageProvenance.contentRect.left, 0.0);
      expect(result.imageProvenance.contentRect.top, 0.25);
      expect(result.imageProvenance.contentRect.right, 1.0);
      expect(result.imageProvenance.contentRect.bottom, 0.75);
      expect(result.globalFeatures, isNotNull);
      expect(result.regionFeatures, hasLength(6));
      expect(result.componentFeatures, isEmpty);
      expect(result.edgeSelectionProfile, isNotNull);
      expect(result.spatialRelationFeatures, isEmpty);
      expect(result.graphStatistics, isNotNull);
      expect(result.connectedStructureResult, isNotNull);
      expect(
        result.regionFeatures.map((feature) => feature.regionId),
        VisionRegionId.values,
      );
    });

    test('preserves saucer context, null source id, and JPEG format', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 6),
      );
      final input = _input(
        width: 2,
        height: 4,
        surfaceType: VisionSurfaceType.saucer,
        jpeg: true,
      );

      final result = await engine.analyzeFeatures(input);

      expect(result.surfaceType, VisionSurfaceType.saucer);
      expect(result.sourceId, isNull);
      expect(result.imageProvenance.sourceFormat, VisionImageFormat.jpeg);
      expect(result.imageProvenance.workingFormat, VisionImageFormat.jpeg);
      expect(result.imageProvenance.workingWidth, 6);
      expect(result.imageProvenance.workingHeight, 6);
      expect(result.imageProvenance.workingResolution, 6);
      expect(result.globalFeatures, isNotNull);
      expect(result.regionFeatures, hasLength(6));
      expect(result.componentFeatures, isEmpty);
      expect(result.edgeSelectionProfile, isNotNull);
      expect(result.spatialRelationFeatures, isEmpty);
      expect(result.graphStatistics, isNotNull);
      expect(result.connectedStructureResult, isNotNull);
    });

    test('returns deterministic equal feature sets', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 4,
        height: 2,
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'deterministic',
      );

      final first = await engine.analyzeFeatures(input);
      final second = await engine.analyzeFeatures(input);

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('does not mutate source bytes', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 4,
        height: 2,
        surfaceType: VisionSurfaceType.cup,
      );
      final originalBytes = input.imageBytes;

      await engine.analyzeFeatures(input);

      expect(input.imageBytes, originalBytes);
    });

    test('matches extraction from the existing detailed result', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 4,
        height: 2,
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'same-pipeline',
      );

      final detailed = await engine.analyzeDetailed(input);
      final expected = const VisionFeatureExtractor().extract(detailed);
      final actual = await engine.analyzeFeatures(input);

      expect(actual, expected);
    });

    test('projects exact global, regional, and component values', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 8,
        height: 8,
        surfaceType: VisionSurfaceType.cup,
        darkPixels: const [(x: 1, y: 1), (x: 6, y: 6)],
      );
      final detailed = await engine.analyzeDetailed(input);

      final features = const VisionFeatureExtractor().extract(detailed);
      final global = features.globalFeatures!;

      expect(global.residuePixelCount, detailed.residueMask.residuePixelCount);
      expect(global.contentResidueRatio, detailed.residueMask.residueRatio);
      expect(global.componentCount, detailed.componentResult.componentCount);
      expect(
        global.candidateRelationCount,
        detailed.edgeSelectionResult.decisionRecords.length,
      );
      expect(
        global.selectedRelationCount,
        detailed.edgeSelectionResult.selectedRelations.length,
      );

      final regionsById = {
        for (final region in detailed.analysisRegions) region.id: region,
      };
      final densitiesById = {
        for (final density in detailed.regionDensities)
          density.regionId: density,
      };
      for (final feature in features.regionFeatures) {
        expect(feature.rect, regionsById[feature.regionId]!.rect);
        expect(
          feature.residueDensity,
          densitiesById[feature.regionId]!.density,
        );
      }

      final componentsById = {
        for (final component in detailed.componentResult.components)
          component.id: component,
      };
      expect(
        features.componentFeatures.map((feature) => feature.componentId),
        componentsById.keys.toList()..sort(),
      );
      for (final feature in features.componentFeatures) {
        final component = componentsById[feature.componentId]!;
        expect(feature.componentId, component.id);
        expect(feature.pixelCount, component.pixelCount);
        expect(feature.boundingBox, same(component.boundingBox));
        expect(feature.centroid, same(component.centroid));
        expect(feature.width, component.width);
        expect(feature.height, component.height);
        expect(feature.aspectRatio, component.aspectRatio);
        expect(feature.areaRatio, component.areaRatio);
        expect(feature.fillRatio, component.fillRatio);
        expect(feature.touchesBorder, component.touchesBorder);
        expect(
          feature.residueShare,
          component.pixelCount / detailed.residueMask.residuePixelCount,
        );
        expect(
          feature.nearestNeighborComponentId,
          detailed.relationResult.nearestNeighborByComponentId[component.id],
        );
      }
      expect(
        features.componentFeatures.fold<double>(
          0.0,
          (total, feature) => total + feature.residueShare,
        ),
        closeTo(1.0, 1e-12),
      );
    });

    test('canonicalizes shuffled pipeline region collections by id', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final detailed = await engine.analyzeDetailed(
        _input(width: 4, height: 2, surfaceType: VisionSurfaceType.cup),
      );
      final shuffled = _copyResult(
        detailed,
        analysisRegions: detailed.analysisRegions.reversed,
        regionDensities: detailed.regionDensities.reversed,
      );

      final features = const VisionFeatureExtractor().extract(shuffled);

      expect(
        features.regionFeatures.map((feature) => feature.regionId),
        VisionRegionId.values,
      );
    });

    test('rejects missing, duplicate, and mismatched region records', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final detailed = await engine.analyzeDetailed(
        _input(width: 4, height: 2, surfaceType: VisionSurfaceType.cup),
      );
      final duplicateRegions = detailed.analysisRegions.take(5).toList()
        ..add(detailed.analysisRegions.first);
      final mismatchedDensity = detailed.regionDensities.first;
      final mismatchedDensities = <VisionRegionDensity>[
        VisionRegionDensity(
          regionId: mismatchedDensity.regionId,
          surfaceType: VisionSurfaceType.saucer,
          density: mismatchedDensity.density,
        ),
        ...detailed.regionDensities.skip(1),
      ];

      expect(
        () => const VisionFeatureExtractor().extract(
          _copyResult(detailed, analysisRegions: duplicateRegions),
        ),
        throwsStateError,
      );
      expect(
        () => const VisionFeatureExtractor().extract(
          _copyResult(
            detailed,
            regionDensities: detailed.regionDensities.skip(1),
          ),
        ),
        throwsStateError,
      );
      expect(
        () => const VisionFeatureExtractor().extract(
          _copyResult(detailed, regionDensities: mismatchedDensities),
        ),
        throwsStateError,
      );
    });

    test('preserves the existing empty-residue pipeline behavior', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );

      final features = await engine.analyzeFeatures(
        _input(width: 4, height: 2, surfaceType: VisionSurfaceType.saucer),
      );
      final global = features.globalFeatures!;

      expect(global.residuePixelCount, 0);
      expect(global.contentResidueRatio, 0.0);
      expect(global.componentCount, 0);
      expect(global.candidateRelationCount, 0);
      expect(global.selectedRelationCount, 0);
      expect(features.regionFeatures, hasLength(6));
      expect(
        features.regionFeatures.map((feature) => feature.residueDensity),
        everyElement(0.0),
      );
      expect(features.componentFeatures, isEmpty);
    });

    test('projects one component with full share and no neighbor', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );

      final features = await engine.analyzeFeatures(
        _input(
          width: 8,
          height: 8,
          surfaceType: VisionSurfaceType.cup,
          darkPixels: const [(x: 3, y: 3)],
        ),
      );

      expect(features.componentFeatures, hasLength(1));
      expect(features.componentFeatures.single.residueShare, 1.0);
      expect(
        features.componentFeatures.single.nearestNeighborComponentId,
        isNull,
      );
    });

    test('keeps analyze and analyzeDetailed behavior unchanged', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 4,
        height: 2,
        surfaceType: VisionSurfaceType.saucer,
      );
      final detailedBefore = await engine.analyzeDetailed(input);

      await engine.analyzeFeatures(input);

      final detailedAfter = await engine.analyzeDetailed(input);
      final observation = await engine.analyze(input);
      expect(detailedAfter, detailedBefore);
      expect(observation.surfaceType, VisionSurfaceType.saucer);
      expect(observation.confidence, 0.0);
      expect(
        observation.notes,
        contains(
          'Image metadata analysis completed; further Coffee Vision analysis '
          'is not implemented.',
        ),
      );
    });
  });

  group('VisionFeatureExtractor internal orchestration', () {
    test('invokes the supplied detailed pipeline exactly once', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final input = _input(
        width: 4,
        height: 2,
        surfaceType: VisionSurfaceType.cup,
      );
      const profile = VisionEdgeSelectionProfile(maxOutgoingPerSource: 0);
      var invocationCount = 0;
      VisionEdgeSelectionProfile? observedProfile;

      final result = await const VisionFeatureExtractor().analyze(
        input: input,
        edgeSelectionProfile: profile,
        pipelineRunner: (pipelineInput, pipelineProfile) {
          invocationCount++;
          observedProfile = pipelineProfile;
          return engine.analyzeDetailed(
            pipelineInput,
            edgeSelectionProfile: pipelineProfile,
          );
        },
      );

      expect(invocationCount, 1);
      expect(observedProfile, profile);
      expect(result.surfaceType, VisionSurfaceType.cup);
      expect(result.globalFeatures, isNotNull);
      expect(result.regionFeatures, hasLength(6));
      expect(result.componentFeatures, isEmpty);
      expect(result.edgeSelectionProfile, same(profile));
      expect(result.spatialRelationFeatures, isEmpty);
      expect(result.graphStatistics, isNotNull);
      expect(result.connectedStructureResult, isNotNull);
    });

    test('rejects missing nearest-neighbor entries', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final detailed = await engine.analyzeDetailed(
        _input(
          width: 8,
          height: 8,
          surfaceType: VisionSurfaceType.cup,
          darkPixels: const [(x: 1, y: 1), (x: 6, y: 6)],
        ),
      );
      final firstId = detailed.componentResult.components.first.id;
      final incompleteRelations = VisionComponentRelationResult(
        relations: const [],
        nearestNeighborByComponentId: {firstId: null},
      );
      final emptyEdges = VisionEdgeSelectionResult(
        profile: const VisionEdgeSelectionProfile(),
        candidateRelations: const [],
        decisionRecords: const [],
      );

      expect(
        () => const VisionFeatureExtractor().extract(
          _copyResult(
            detailed,
            relationResult: incompleteRelations,
            edgeSelectionResult: emptyEdges,
          ),
        ),
        throwsStateError,
      );
    });

    test('rejects legacy components without detection metadata', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final detailed = await engine.analyzeDetailed(
        _input(
          width: 8,
          height: 8,
          surfaceType: VisionSurfaceType.cup,
          darkPixels: const [(x: 3, y: 3)],
        ),
      );
      final detected = detailed.componentResult.components.single;
      final legacy = VisionComponent(
        id: detected.id,
        pixels: List<int>.generate(detected.pixelCount, (index) => index),
        boundingBox: detected.boundingBox,
        centroid: detected.centroid,
        areaRatio: detected.areaRatio,
      );
      final legacyResult = VisionComponentResult(
        imageSize: detailed.componentResult.imageSize,
        totalResiduePixels: detailed.componentResult.totalResiduePixels,
        components: [legacy],
      );

      expect(
        () => const VisionFeatureExtractor().extract(
          _copyResult(detailed, componentResult: legacyResult),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing detection metadata'),
          ),
        ),
      );
    });

    test('contains no image or analysis recomputation entry points', () {
      final source = File(
        'lib/src/vision_feature_extractor.dart',
      ).readAsStringSync();

      for (final forbidden in [
        '.pixels',
        'decodeImage',
        'ResiduePixelClassifier',
        'analyzeRegionDensities(',
        'createResidueMask(',
        'detectComponents(',
        'analyzeComponentRelations(',
        'selectEdges(',
        'createSpatialGraph(',
        'createSparseSpatialGraph(',
        'analyzeGraphStatistics(',
        'analyzeConnectedStructures(',
        'ComponentRelationAnalyzer',
        'EdgeSelector',
        'SpatialGraphOrganizer',
        'GraphStatisticsAnalyzer',
        'ConnectedStructureAnalyzer',
        'component.boundingBox.width',
        'component.boundingBox.height',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(
        RegExp(
          r'residueShare:\s*component\.pixelCount\s*/\s*'
          r'globalFeatures\.residuePixelCount',
        ).hasMatch(source),
        isTrue,
      );
    });
  });
}

VisionImageInput _input({
  required int width,
  required int height,
  required VisionSurfaceType surfaceType,
  String? sourceId,
  bool jpeg = false,
  Iterable<({int x, int y})> darkPixels = const [],
}) {
  final source = image.Image(width: width, height: height, numChannels: 4);
  final darkPixelSet = darkPixels.toSet();
  for (final pixel in source) {
    final value = darkPixelSet.contains((x: pixel.x, y: pixel.y)) ? 0 : 255;
    pixel.setRgba(value, value, value, 255);
  }
  final encoded = jpeg ? image.encodeJpg(source) : image.encodePng(source);
  return VisionImageInput(
    imageBytes: Uint8List.fromList(encoded),
    surfaceType: surfaceType,
    sourceId: sourceId,
  );
}

VisionPipelineResult _copyResult(
  VisionPipelineResult source, {
  Iterable<VisionAnalysisRegion>? analysisRegions,
  Iterable<VisionRegionDensity>? regionDensities,
  VisionComponentResult? componentResult,
  VisionComponentRelationResult? relationResult,
  VisionEdgeSelectionResult? edgeSelectionResult,
}) {
  return VisionPipelineResult(
    surfaceType: source.surfaceType,
    sourceId: source.sourceId,
    workingImage: source.workingImage,
    analysisRegions: analysisRegions ?? source.analysisRegions,
    regionDensities: regionDensities ?? source.regionDensities,
    residueMask: source.residueMask,
    componentResult: componentResult ?? source.componentResult,
    relationResult: relationResult ?? source.relationResult,
    edgeSelectionResult: edgeSelectionResult ?? source.edgeSelectionResult,
    spatialGraph: source.spatialGraph,
    graphStatistics: source.graphStatistics,
    connectedStructureResult: source.connectedStructureResult,
  );
}
