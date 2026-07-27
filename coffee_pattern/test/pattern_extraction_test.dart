import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('M8B connected-structure extraction', () {
    test('keeps a complete zero-structure FeatureSet empty', () async {
      final features = _features(structures: const []);

      final result = await const PatternEngine().analyzePatterns(features);

      expect(result.surfaceType, PatternSurfaceType.cup);
      expect(result.candidates, isEmpty);
    });

    test('projects one isolated component with complete evidence', () async {
      final features = _features(
        structures: const [
          [1],
        ],
      );

      final result = await const PatternEngine().analyzePatterns(features);

      expect(result.candidates, hasLength(1));
      expect(result.candidates.single.id, 1);
      expect(result.candidates.single.geometry, isNotNull);
      expect(
        result.candidates.single.topology,
        PatternTopology(nodeCount: 1, directedEdgeCount: 0),
      );
      expect(result.candidates.single.topology!.isIsolated, isTrue);
      expect(result.candidates.single.evidence, [
        PatternEvidence.componentFeature(1),
        PatternEvidence.connectedStructure(1),
      ]);
    });

    test('projects every isolated structure exactly once', () async {
      final features = _features(
        structures: const [
          [1],
          [2],
          [3],
        ],
      );

      final result = await const PatternEngine().analyzePatterns(features);

      expect(result.candidates.map((candidate) => candidate.id), [1, 2, 3]);
      expect(
        result.candidates.map(
          (candidate) => candidate.evidence.first.componentId,
        ),
        [1, 2, 3],
      );
      expect(
        result.candidates.map((candidate) => candidate.topology!.isIsolated),
        everyElement(isTrue),
      );
    });

    test(
      'projects one multi-component structure without information loss',
      () async {
        final features = _features(
          structures: const [
            [7, 11, 19],
          ],
        );

        final result = await const PatternEngine().analyzePatterns(features);

        expect(result.candidates, hasLength(1));
        expect(
          result.candidates.single.topology,
          PatternTopology(nodeCount: 3, directedEdgeCount: 6),
        );
        expect(result.candidates.single.topology!.isIsolated, isFalse);
        expect(result.candidates.single.evidence, [
          PatternEvidence.componentFeature(7),
          PatternEvidence.componentFeature(11),
          PatternEvidence.componentFeature(19),
          PatternEvidence.connectedStructure(1),
        ]);
        final geometry = result.candidates.single.geometry!;
        expect(geometry.left, closeTo(0.05, 1e-12));
        expect(geometry.top, closeTo(0.1, 1e-12));
        expect(geometry.right, closeTo(0.3, 1e-12));
        expect(geometry.bottom, closeTo(0.15, 1e-12));
        expect(geometry.centroidX, closeTo(0.175, 1e-12));
        expect(geometry.centroidY, closeTo(0.125, 1e-12));
      },
    );

    test('uses residue pixel counts for the canonical centroid', () async {
      final features = _features(
        structures: const [
          [1, 2],
        ],
        pixelCounts: const {1: 1, 2: 3},
        boundingBoxes: {
          1: VisionRect(left: 0.1, top: 0.1, right: 0.2, bottom: 0.2),
          2: VisionRect(left: 0.6, top: 0.4, right: 0.8, bottom: 0.8),
        },
      );

      final result = await const PatternEngine().analyzePatterns(features);
      final geometry = result.candidates.single.geometry!;

      expect(geometry.left, 0.1);
      expect(geometry.top, 0.1);
      expect(geometry.right, 0.8);
      expect(geometry.bottom, 0.8);
      expect(geometry.centroidX, closeTo(0.5625, 1e-12));
      expect(geometry.centroidY, closeTo(0.4875, 1e-12));
      expect(geometry.width, closeTo(0.7, 1e-12));
      expect(geometry.height, closeTo(0.7, 1e-12));
      expect(geometry.aspectRatio, closeTo(1.0, 1e-12));
    });

    test('reports only working-image boundary contact', () async {
      final border = _features(
        structures: const [
          [1],
        ],
        boundingBoxes: {
          1: VisionRect(left: 0.0, top: 0.2, right: 0.2, bottom: 0.4),
        },
      );
      final interior = _features(
        structures: const [
          [1],
        ],
        boundingBoxes: {
          1: VisionRect(left: 0.1, top: 0.2, right: 0.2, bottom: 0.4),
        },
      );
      const engine = PatternEngine();

      final borderResult = await engine.analyzePatterns(border);
      final interiorResult = await engine.analyzePatterns(interior);

      expect(
        borderResult.candidates.single.geometry!.touchesWorkingImageBorder,
        isTrue,
      );
      expect(
        interiorResult.candidates.single.geometry!.touchesWorkingImageBorder,
        isFalse,
      );
    });

    test('projects multiple disjoint structures without overlap', () async {
      final features = _features(
        structures: const [
          [1, 3],
          [8],
          [13, 21],
        ],
      );

      final result = await const PatternEngine().analyzePatterns(features);

      expect(result.candidates, hasLength(3));
      expect(_componentEvidence(result.candidates[0]), [1, 3]);
      expect(_componentEvidence(result.candidates[1]), [8]);
      expect(_componentEvidence(result.candidates[2]), [13, 21]);
      expect(result.candidates.expand(_componentEvidence).toSet(), {
        1,
        3,
        8,
        13,
        21,
      });
    });

    test('is independent of caller collection iteration order', () async {
      final canonical = _features(
        structures: const [
          [1, 4],
          [7],
        ],
      );
      final reordered = _features(
        structures: const [
          [1, 4],
          [7],
        ],
        reverseInputs: true,
      );
      const engine = PatternEngine();

      final first = await engine.analyzePatterns(canonical);
      final second = await engine.analyzePatterns(reordered);

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(
        second.candidates.map((candidate) => candidate.geometry),
        first.candidates.map((candidate) => candidate.geometry),
      );
      expect(
        second.candidates.map((candidate) => candidate.topology),
        first.candidates.map((candidate) => candidate.topology),
      );
    });

    test(
      'preserves non-contiguous component and canonical structure IDs',
      () async {
        final features = _features(
          structures: const [
            [4, 20],
            [99],
          ],
        );

        final result = await const PatternEngine().analyzePatterns(features);

        expect(result.candidates.map((candidate) => candidate.id), [1, 2]);
        expect(_componentEvidence(result.candidates[0]), [4, 20]);
        expect(_componentEvidence(result.candidates[1]), [99]);
      },
    );

    test('propagates cup, saucer, and optional source identity', () async {
      final cup = await const PatternEngine().analyzePatterns(
        _features(
          structures: const [
            [1],
          ],
          sourceId: 'cup-source',
        ),
      );
      final saucer = await const PatternEngine().analyzePatterns(
        _features(
          structures: const [
            [1],
          ],
          surfaceType: VisionSurfaceType.saucer,
        ),
      );

      expect(cup.surfaceType, PatternSurfaceType.cup);
      expect(cup.sourceId, 'cup-source');
      expect(saucer.surfaceType, PatternSurfaceType.saucer);
      expect(saucer.sourceId, isNull);
      expect(saucer.candidates.single.geometry, cup.candidates.single.geometry);
      expect(saucer.candidates.single.topology, cup.candidates.single.topology);
    });

    test('is deterministic, immutable, and collection-safe', () async {
      final features = _features(
        structures: const [
          [1, 2],
          [5],
        ],
      );
      const engine = PatternEngine();

      final first = await engine.analyzePatterns(features);
      final second = await engine.analyzePatterns(features);
      final third = await engine.analyzePatterns(features);

      expect(second, first);
      expect(third, first);
      expect(second.hashCode, first.hashCode);
      expect(<PatternAnalysisResult>{first, second, third}, hasLength(1));
      expect(() => first.candidates.clear(), throwsUnsupportedError);
      expect(
        () => first.candidates.first.evidence.clear(),
        throwsUnsupportedError,
      );
    });

    test('Vision rejects zero-member and duplicate-member structures', () {
      expect(
        () => VisionConnectedStructure(
          id: 1,
          componentIds: const [],
          directedEdgeCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionConnectedStructure(
          id: 1,
          componentIds: const [2, 2],
          directedEdgeCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('Vision rejects overlapping structure membership', () {
      expect(
        () => VisionConnectedStructureResult(
          structures: [
            VisionConnectedStructure(
              id: 1,
              componentIds: const [1, 2],
              directedEdgeCount: 2,
            ),
            VisionConnectedStructure(
              id: 2,
              componentIds: const [2, 3],
              directedEdgeCount: 2,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'complete FeatureSet rejects missing and unknown member references',
      () {
        expect(
          () => _features(
            structures: const [
              [1],
            ],
            componentIds: const [1, 2],
          ),
          throwsArgumentError,
        );
        expect(
          () => _features(
            structures: const [
              [1, 2],
            ],
            componentIds: const [1],
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

List<int> _componentEvidence(PatternCandidate candidate) {
  return candidate.evidence
      .where(
        (evidence) => evidence.kind == PatternEvidenceKind.componentFeature,
      )
      .map((evidence) => evidence.componentId!)
      .toList(growable: false);
}

VisionFeatureSet _features({
  required List<List<int>> structures,
  List<int>? componentIds,
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
  String? sourceId,
  bool reverseInputs = false,
  Map<int, int> pixelCounts = const {},
  Map<int, VisionRect> boundingBoxes = const {},
}) {
  final canonicalStructures =
      structures.map((members) => members.toList()..sort()).toList()
        ..sort((first, second) => first.first.compareTo(second.first));
  final resolvedComponentIds =
      componentIds?.toList() ??
      canonicalStructures.expand((members) => members).toSet().toList();
  resolvedComponentIds.sort();
  final totalResiduePixels = resolvedComponentIds.fold<int>(
    0,
    (total, componentId) => total + (pixelCounts[componentId] ?? 1),
  );

  final componentToStructure = <int, int>{};
  for (var index = 0; index < canonicalStructures.length; index++) {
    for (final componentId in canonicalStructures[index]) {
      componentToStructure[componentId] = index;
    }
  }

  final components = <VisionComponentFeature>[];
  for (var index = 0; index < resolvedComponentIds.length; index++) {
    final componentId = resolvedComponentIds[index];
    final left = 0.05 + index * 0.1;
    final rect =
        boundingBoxes[componentId] ??
        VisionRect(left: left, top: 0.1, right: left + 0.05, bottom: 0.15);
    final pixelCount = pixelCounts[componentId] ?? 1;
    components.add(
      VisionComponentFeature(
        componentId: componentId,
        pixelCount: pixelCount,
        boundingBox: rect,
        centroid: rect.center,
        width: rect.width,
        height: rect.height,
        aspectRatio: rect.width / rect.height,
        areaRatio: 0.01,
        fillRatio: 1.0,
        touchesBorder:
            rect.left == 0.0 ||
            rect.top == 0.0 ||
            rect.right == 1.0 ||
            rect.bottom == 1.0,
        residueShare: pixelCount / totalResiduePixels,
        nearestNeighborComponentId: resolvedComponentIds.length == 1
            ? null
            : resolvedComponentIds.firstWhere((id) => id != componentId),
      ),
    );
  }

  final profile = const VisionEdgeSelectionProfile(maxCentroidDistance: 0.5);
  final relations = <VisionSpatialRelationFeature>[];
  final outgoingDegrees = <int, int>{
    for (final componentId in resolvedComponentIds) componentId: 0,
  };
  for (final sourceId in resolvedComponentIds) {
    for (final targetId in resolvedComponentIds) {
      if (sourceId == targetId) continue;
      final selected =
          componentToStructure[sourceId] != null &&
          componentToStructure[sourceId] == componentToStructure[targetId];
      if (selected) outgoingDegrees[sourceId] = outgoingDegrees[sourceId]! + 1;
      relations.add(
        VisionSpatialRelationFeature.fromDecision(
          VisionEdgeSelectionDecision(
            relation: VisionComponentRelation(
              sourceComponentId: sourceId,
              targetComponentId: targetId,
              centroidDistance: selected ? 0.25 : 0.75,
              boundingBoxDistance: selected ? 0.1 : 0.5,
              relativeDirection: sourceId < targetId
                  ? VisionRelativeDirection.right
                  : VisionRelativeDirection.left,
              boundingBoxesTouch: false,
              boundingBoxesIntersect: false,
            ),
            reason: selected
                ? VisionEdgeSelectionReason.selectedByActiveFilters
                : VisionEdgeSelectionReason.rejectedByCentroidDistance,
          ),
        ),
      );
    }
  }

  final structureModels = <VisionConnectedStructure>[
    for (var index = 0; index < canonicalStructures.length; index++)
      VisionConnectedStructure(
        id: index + 1,
        componentIds: reverseInputs
            ? canonicalStructures[index].reversed
            : canonicalStructures[index],
        directedEdgeCount:
            canonicalStructures[index].length *
            (canonicalStructures[index].length - 1),
      ),
  ];

  final componentInput = reverseInputs
      ? components.reversed.toList(growable: false)
      : components;
  final relationInput = reverseInputs
      ? relations.reversed.toList(growable: false)
      : relations;
  final structureInput = reverseInputs
      ? structureModels.reversed.toList(growable: false)
      : structureModels;

  final degrees = outgoingDegrees.values.toList();
  final selectedRelationCount = degrees.fold<int>(
    0,
    (total, degree) => total + degree,
  );
  final minimumDegree = degrees.isEmpty
      ? 0
      : degrees.reduce((first, second) => first < second ? first : second);
  final maximumDegree = degrees.isEmpty
      ? 0
      : degrees.reduce((first, second) => first > second ? first : second);

  return VisionFeatureSet.withSpatialAndConnectivityFeatures(
    surfaceType: surfaceType,
    sourceId: sourceId,
    imageProvenance: VisionFeatureImageProvenance(
      sourceFormat: VisionImageFormat.png,
      sourceWidth: 8,
      sourceHeight: 8,
      workingFormat: VisionImageFormat.png,
      workingWidth: 8,
      workingHeight: 8,
      workingResolution: 8,
      contentRect: VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
    ),
    globalFeatures: VisionGlobalFeatures(
      residuePixelCount: totalResiduePixels,
      contentResidueRatio: resolvedComponentIds.isEmpty ? 0.0 : 0.1,
      componentCount: resolvedComponentIds.length,
      candidateRelationCount:
          resolvedComponentIds.length * (resolvedComponentIds.length - 1),
      selectedRelationCount: selectedRelationCount,
    ),
    regionFeatures: [
      for (final regionId in VisionRegionId.values)
        VisionRegionFeature(
          regionId: regionId,
          rect: VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
          residueDensity: 0.0,
        ),
    ],
    componentFeatures: componentInput,
    edgeSelectionProfile: profile,
    spatialRelationFeatures: relationInput,
    graphStatistics: VisionGraphStatistics(
      componentCount: resolvedComponentIds.length,
      relationCount: selectedRelationCount,
      isolatedComponentCount: degrees.where((degree) => degree == 0).length,
      minDegree: minimumDegree,
      maxDegree: maximumDegree,
      averageDegree: degrees.isEmpty
          ? 0.0
          : selectedRelationCount / degrees.length,
    ),
    connectedStructureResult: VisionConnectedStructureResult(
      structures: structureInput,
    ),
  );
}
