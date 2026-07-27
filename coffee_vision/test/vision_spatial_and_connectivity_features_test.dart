import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:coffee_vision/src/vision_feature_extractor.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  group('VisionSpatialRelationFeature', () {
    test('is a deterministic immutable view of an existing decision', () {
      final relation = VisionComponentRelation(
        sourceComponentId: 3,
        targetComponentId: 7,
        centroidDistance: 0.375,
        boundingBoxDistance: 0.125,
        relativeDirection: VisionRelativeDirection.right,
        boundingBoxesTouch: false,
        boundingBoxesIntersect: true,
      );
      final decision = VisionEdgeSelectionDecision(
        relation: relation,
        reason: VisionEdgeSelectionReason.selectedByActiveFilters,
      );

      final first = VisionSpatialRelationFeature.fromDecision(decision);
      final second = VisionSpatialRelationFeature.fromDecision(decision);

      expect(first.sourceComponentId, 3);
      expect(first.targetComponentId, 7);
      expect(first.centroidDistance, 0.375);
      expect(first.boundingBoxDistance, 0.125);
      expect(first.relativeDirection, VisionRelativeDirection.right);
      expect(first.boundingBoxesTouch, isFalse);
      expect(first.boundingBoxesIntersect, isTrue);
      expect(first.selected, isTrue);
      expect(
        first.selectionReason,
        VisionEdgeSelectionReason.selectedByActiveFilters,
      );
      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toString(), contains('sourceComponentId: 3'));
      expect(first.toString(), isNot(contains('symbol')));
      expect(first.toString(), isNot(contains('fortune')));
    });

    test(
      'preserves rejected selection provenance without reinterpretation',
      () {
        final feature = VisionSpatialRelationFeature.fromDecision(
          VisionEdgeSelectionDecision(
            relation: VisionComponentRelation(
              sourceComponentId: 2,
              targetComponentId: 5,
              centroidDistance: 0.51,
              boundingBoxDistance: 0.25,
              relativeDirection: VisionRelativeDirection.below,
              boundingBoxesTouch: false,
              boundingBoxesIntersect: false,
            ),
            reason: VisionEdgeSelectionReason.rejectedByCentroidDistance,
          ),
        );

        expect(feature.selected, isFalse);
        expect(
          feature.selectionReason,
          VisionEdgeSelectionReason.rejectedByCentroidDistance,
        );
        expect(feature.centroidDistance, 0.51);
        expect(feature.boundingBoxDistance, 0.25);
      },
    );

    test('source relation validation rejects invalid geometry and IDs', () {
      expect(
        () => VisionComponentRelation(
          sourceComponentId: 1,
          targetComponentId: 1,
          centroidDistance: 0.0,
          boundingBoxDistance: 0.0,
          relativeDirection: VisionRelativeDirection.overlappingCenter,
          boundingBoxesTouch: false,
          boundingBoxesIntersect: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionComponentRelation(
          sourceComponentId: 1,
          targetComponentId: 2,
          centroidDistance: double.nan,
          boundingBoxDistance: 0.0,
          relativeDirection: VisionRelativeDirection.right,
          boundingBoxesTouch: false,
          boundingBoxesIntersect: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionComponentRelation(
          sourceComponentId: 1,
          targetComponentId: 2,
          centroidDistance: 0.0,
          boundingBoxDistance: double.infinity,
          relativeDirection: VisionRelativeDirection.right,
          boundingBoxesTouch: false,
          boundingBoxesIntersect: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('VisionFeatureSet M7D contract', () {
    test(
      'projects every relation decision and reuses aggregate results',
      () async {
        const engine = CoffeeVisionEngine(
          config: VisionConfig(workingResolution: 8),
        );
        final detailed = await engine.analyzeDetailed(_twoComponentInput());

        final features = const VisionFeatureExtractor().extract(detailed);

        expect(
          features.edgeSelectionProfile,
          same(detailed.edgeSelectionResult.profile),
        );
        expect(features.graphStatistics, same(detailed.graphStatistics));
        expect(
          features.connectedStructureResult,
          same(detailed.connectedStructureResult),
        );
        expect(
          features.spatialRelationFeatures,
          hasLength(detailed.edgeSelectionResult.decisionRecords.length),
        );
        for (
          var index = 0;
          index < detailed.edgeSelectionResult.decisionRecords.length;
          index++
        ) {
          final decision = detailed.edgeSelectionResult.decisionRecords[index];
          final feature = features.spatialRelationFeatures[index];
          expect(feature.sourceComponentId, decision.sourceComponentId);
          expect(feature.targetComponentId, decision.targetComponentId);
          expect(feature.centroidDistance, decision.relation.centroidDistance);
          expect(
            feature.boundingBoxDistance,
            decision.relation.boundingBoxDistance,
          );
          expect(
            feature.relativeDirection,
            decision.relation.relativeDirection,
          );
          expect(
            feature.boundingBoxesTouch,
            decision.relation.boundingBoxesTouch,
          );
          expect(
            feature.boundingBoxesIntersect,
            decision.relation.boundingBoxesIntersect,
          );
          expect(feature.selected, decision.selected);
          expect(feature.selectionReason, decision.reason);
        }
      },
    );

    test('canonicalizes relations by canonical IDs and is immutable', () async {
      final features = await _twoComponentFeatures();
      final mutableRelations = features.spatialRelationFeatures.reversed
          .toList();

      final reordered = VisionFeatureSet.withSpatialAndConnectivityFeatures(
        surfaceType: features.surfaceType,
        sourceId: features.sourceId,
        imageProvenance: features.imageProvenance,
        globalFeatures: features.globalFeatures!,
        regionFeatures: features.regionFeatures,
        componentFeatures: features.componentFeatures,
        edgeSelectionProfile: features.edgeSelectionProfile!,
        spatialRelationFeatures: mutableRelations,
        graphStatistics: features.graphStatistics!,
        connectedStructureResult: features.connectedStructureResult!,
      );
      mutableRelations.clear();

      expect(
        reordered.spatialRelationFeatures
            .map(
              (feature) =>
                  (feature.sourceComponentId, feature.targetComponentId),
            )
            .toList(),
        [(1, 2), (2, 1)],
      );
      expect(
        () => reordered.spatialRelationFeatures.clear(),
        throwsUnsupportedError,
      );
      expect(reordered, features);
      expect(reordered.hashCode, features.hashCode);
    });

    test(
      'rejects duplicate and missing component relation references',
      () async {
        final features = await _twoComponentFeatures();
        final first = features.spatialRelationFeatures.first;
        final unknownReference = VisionSpatialRelationFeature.fromDecision(
          VisionEdgeSelectionDecision(
            relation: VisionComponentRelation(
              sourceComponentId: first.sourceComponentId,
              targetComponentId: 999,
              centroidDistance: first.centroidDistance,
              boundingBoxDistance: first.boundingBoxDistance,
              relativeDirection: first.relativeDirection,
              boundingBoxesTouch: first.boundingBoxesTouch,
              boundingBoxesIntersect: first.boundingBoxesIntersect,
            ),
            reason: first.selectionReason,
          ),
        );

        expect(
          () => _rebuild(features, spatialRelations: [first, first]),
          throwsArgumentError,
        );
        expect(
          () => _rebuild(
            features,
            spatialRelations: [
              unknownReference,
              features.spatialRelationFeatures.last,
            ],
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects selection reasons inconsistent with the profile', () async {
      final features = await _twoComponentFeatures();

      expect(
        () => _rebuild(
          features,
          profile: const VisionEdgeSelectionProfile(maxOutgoingPerSource: 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects inconsistent graph and structure aggregates', () async {
      final features = await _twoComponentFeatures();
      final firstComponentId = features.componentFeatures.first.componentId;

      expect(
        () => _rebuild(
          features,
          graphStatistics: VisionGraphStatistics(
            componentCount: 2,
            relationCount: 1,
            isolatedComponentCount: 1,
            minDegree: 0,
            maxDegree: 1,
            averageDegree: 0.5,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => _rebuild(
          features,
          connectedStructureResult: VisionConnectedStructureResult(
            structures: [
              VisionConnectedStructure(
                id: 1,
                componentIds: [firstComponentId],
                directedEdgeCount: 0,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'preserves complete rejected decisions when no edge is selected',
      () async {
        const engine = CoffeeVisionEngine(
          config: VisionConfig(workingResolution: 8),
        );
        const profile = VisionEdgeSelectionProfile(maxOutgoingPerSource: 0);
        final features = await engine.analyzeFeatures(
          _twoComponentInput(),
          edgeSelectionProfile: profile,
        );

        expect(features.edgeSelectionProfile, profile);
        expect(features.spatialRelationFeatures, hasLength(2));
        expect(
          features.spatialRelationFeatures.map((feature) => feature.selected),
          everyElement(isFalse),
        );
        expect(
          features.spatialRelationFeatures.map(
            (feature) => feature.selectionReason,
          ),
          everyElement(VisionEdgeSelectionReason.rejectedByOutgoingLimit),
        );
        expect(features.graphStatistics!.componentCount, 2);
        expect(features.graphStatistics!.relationCount, 0);
        expect(features.graphStatistics!.isolatedComponentCount, 2);
        expect(features.connectedStructureResult!.structureCount, 2);
        expect(features.connectedStructureResult!.isolatedStructureCount, 2);
      },
    );

    test('supports the canonical zero-component empty state', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final features = await engine.analyzeFeatures(
        _input(darkPixels: const []),
      );

      expect(features.componentFeatures, isEmpty);
      expect(features.edgeSelectionProfile, isNotNull);
      expect(features.spatialRelationFeatures, isEmpty);
      expect(features.graphStatistics!.componentCount, 0);
      expect(features.graphStatistics!.relationCount, 0);
      expect(features.connectedStructureResult!.structures, isEmpty);
    });

    test('supports one isolated canonical component', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final features = await engine.analyzeFeatures(
        _input(darkPixels: const [(x: 3, y: 3)]),
      );

      expect(features.componentFeatures, hasLength(1));
      expect(features.spatialRelationFeatures, isEmpty);
      expect(features.graphStatistics!.componentCount, 1);
      expect(features.graphStatistics!.relationCount, 0);
      expect(features.graphStatistics!.isolatedComponentCount, 1);
      final structure = features.connectedStructureResult!.structures.single;
      expect(structure.componentIds, [
        features.componentFeatures.single.componentId,
      ]);
      expect(structure.isIsolated, isTrue);
    });

    test('is deterministic for cup and saucer surfaces', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 8),
      );
      final cupInput = _twoComponentInput();
      final saucerInput = _input(
        surfaceType: VisionSurfaceType.saucer,
        darkPixels: const [(x: 1, y: 1), (x: 6, y: 6)],
      );

      final cupFirst = await engine.analyzeFeatures(cupInput);
      final cupSecond = await engine.analyzeFeatures(cupInput);
      final saucer = await engine.analyzeFeatures(saucerInput);

      expect(cupSecond, cupFirst);
      expect(cupSecond.hashCode, cupFirst.hashCode);
      expect(cupFirst.surfaceType, VisionSurfaceType.cup);
      expect(saucer.surfaceType, VisionSurfaceType.saucer);
      expect(saucer.spatialRelationFeatures, cupFirst.spatialRelationFeatures);
    });

    test('extractor contains no spatial or connectivity recomputation', () {
      final source = File(
        'lib/src/vision_feature_extractor.dart',
      ).readAsStringSync();

      for (final forbidden in [
        '.pixels',
        'decodeImage',
        'ComponentRelationAnalyzer',
        'EdgeSelector',
        'SpatialGraphOrganizer',
        'GraphStatisticsAnalyzer',
        'ConnectedStructureAnalyzer',
        'analyzeComponentRelations(',
        'selectEdges(',
        'createSpatialGraph(',
        'createSparseSpatialGraph(',
        'analyzeGraphStatistics(',
        'analyzeConnectedStructures(',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(
        source,
        contains('pipelineResult.edgeSelectionResult.decisionRecords.map'),
      );
      expect(
        source,
        contains('graphStatistics: pipelineResult.graphStatistics'),
      );
      expect(
        source,
        contains(
          'connectedStructureResult: '
          'pipelineResult.connectedStructureResult',
        ),
      );
    });
  });
}

Future<VisionFeatureSet> _twoComponentFeatures() {
  return const CoffeeVisionEngine(
    config: VisionConfig(workingResolution: 8),
  ).analyzeFeatures(_twoComponentInput());
}

VisionImageInput _twoComponentInput() {
  return _input(darkPixels: const [(x: 1, y: 1), (x: 6, y: 6)]);
}

VisionImageInput _input({
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
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
  );
}

VisionFeatureSet _rebuild(
  VisionFeatureSet source, {
  VisionEdgeSelectionProfile? profile,
  Iterable<VisionSpatialRelationFeature>? spatialRelations,
  VisionGraphStatistics? graphStatistics,
  VisionConnectedStructureResult? connectedStructureResult,
}) {
  return VisionFeatureSet.withSpatialAndConnectivityFeatures(
    surfaceType: source.surfaceType,
    sourceId: source.sourceId,
    imageProvenance: source.imageProvenance,
    globalFeatures: source.globalFeatures!,
    regionFeatures: source.regionFeatures,
    componentFeatures: source.componentFeatures,
    edgeSelectionProfile: profile ?? source.edgeSelectionProfile!,
    spatialRelationFeatures: spatialRelations ?? source.spatialRelationFeatures,
    graphStatistics: graphStatistics ?? source.graphStatistics!,
    connectedStructureResult:
        connectedStructureResult ?? source.connectedStructureResult!,
  );
}
