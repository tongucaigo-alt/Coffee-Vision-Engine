import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  const engine = CoffeeVisionEngine();

  group('VisionConnectedStructure', () {
    test('stores canonical immutable component ids and derived values', () {
      final structure = VisionConnectedStructure(
        id: 1,
        componentIds: [3, 1, 2],
        directedEdgeCount: 2,
      );

      expect(structure.id, 1);
      expect(structure.componentIds, [1, 2, 3]);
      expect(structure.componentCount, 3);
      expect(structure.directedEdgeCount, 2);
      expect(structure.isIsolated, isFalse);
      expect(() => structure.componentIds.add(4), throwsUnsupportedError);
    });

    test('derives isolated state only for one component with no edge', () {
      final structure = VisionConnectedStructure(
        id: 1,
        componentIds: const [7],
        directedEdgeCount: 0,
      );

      expect(structure.componentCount, 1);
      expect(structure.isIsolated, isTrue);
    });

    test('rejects invalid ids, component sets, and edge counts', () {
      expect(
        () => VisionConnectedStructure(
          id: 0,
          componentIds: const [1],
          directedEdgeCount: 0,
        ),
        throwsArgumentError,
      );
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
          componentIds: const [0],
          directedEdgeCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionConnectedStructure(
          id: 1,
          componentIds: const [1, 1],
          directedEdgeCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionConnectedStructure(
          id: 1,
          componentIds: const [1, 2],
          directedEdgeCount: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionConnectedStructure(
          id: 1,
          componentIds: const [1, 2],
          directedEdgeCount: 3,
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final first = VisionConnectedStructure(
        id: 1,
        componentIds: const [1, 2],
        directedEdgeCount: 1,
      );
      final second = VisionConnectedStructure(
        id: 1,
        componentIds: const [2, 1],
        directedEdgeCount: 1,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('componentCount: 2'));
      expect(first.toString(), contains('directedEdgeCount: 1'));
    });
  });

  group('VisionConnectedStructureResult', () {
    test('summarizes canonical structures and protects its list', () {
      final result = VisionConnectedStructureResult(
        structures: [
          VisionConnectedStructure(
            id: 2,
            componentIds: const [8],
            directedEdgeCount: 0,
          ),
          VisionConnectedStructure(
            id: 1,
            componentIds: const [2, 3],
            directedEdgeCount: 1,
          ),
        ],
      );

      expect(result.structures.map((structure) => structure.id), [1, 2]);
      expect(result.structureCount, 2);
      expect(result.largestStructureSize, 2);
      expect(result.isolatedStructureCount, 1);
      expect(() => result.structures.clear(), throwsUnsupportedError);
    });

    test('returns zero summaries for an empty result', () {
      final result = VisionConnectedStructureResult(structures: const []);

      expect(result.structures, isEmpty);
      expect(result.structureCount, 0);
      expect(result.largestStructureSize, 0);
      expect(result.isolatedStructureCount, 0);
    });

    test('rejects noncanonical ids and repeated component membership', () {
      expect(
        () => VisionConnectedStructureResult(
          structures: [
            VisionConnectedStructure(
              id: 2,
              componentIds: const [1],
              directedEdgeCount: 0,
            ),
          ],
        ),
        throwsArgumentError,
      );

      expect(
        () => VisionConnectedStructureResult(
          structures: [
            VisionConnectedStructure(
              id: 1,
              componentIds: const [1, 2],
              directedEdgeCount: 1,
            ),
            VisionConnectedStructure(
              id: 2,
              componentIds: const [2, 3],
              directedEdgeCount: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      VisionConnectedStructureResult create() {
        return VisionConnectedStructureResult(
          structures: [
            VisionConnectedStructure(
              id: 1,
              componentIds: const [1],
              directedEdgeCount: 0,
            ),
          ],
        );
      }

      final first = create();
      final second = create();
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('structureCount: 1'));
      expect(first.toString(), contains('isolatedStructureCount: 1'));
    });
  });

  group('CoffeeVisionEngine.analyzeConnectedStructures', () {
    test('returns a synchronous empty result for an empty graph', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [], const []),
      );

      expect(result, isA<VisionConnectedStructureResult>());
      expect(result.structures, isEmpty);
      expect(result.structureCount, 0);
      expect(result.largestStructureSize, 0);
      expect(result.isolatedStructureCount, 0);
    });

    test('returns one isolated structure for one component', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [7], const []),
      );

      expect(result.structureCount, 1);
      expect(result.structures.single.id, 1);
      expect(result.structures.single.componentIds, [7]);
      expect(result.structures.single.directedEdgeCount, 0);
      expect(result.structures.single.isIsolated, isTrue);
    });

    test('keeps multiple edge-free components as isolated structures', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [5, 1, 3], const []),
      );

      expect(result.structures.map((structure) => structure.componentIds), [
        [1],
        [3],
        [5],
      ]);
      expect(result.structures.map((structure) => structure.id), [1, 2, 3]);
      expect(result.isolatedStructureCount, 3);
    });

    test('one directed edge creates one weak structure', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [1, 2], const [(1, 2)]),
      );

      expect(result.structureCount, 1);
      expect(result.structures.single.componentIds, [1, 2]);
      expect(result.structures.single.directedEdgeCount, 1);
      expect(result.structures.single.isIsolated, isFalse);
    });

    test('reverse directed edge produces the same weak membership', () {
      final forward = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [1, 2], const [(1, 2)]),
      );
      final reverse = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [1, 2], const [(2, 1)]),
      );

      expect(reverse, forward);
    });

    test('bidirectional pair counts two directed edges', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [1, 2], const [(1, 2), (2, 1)]),
      );

      expect(result.structureCount, 1);
      expect(result.structures.single.componentIds, [1, 2]);
      expect(result.structures.single.directedEdgeCount, 2);
    });

    test('finds two independent weak structures', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [1, 2, 3, 4], const [(1, 2), (4, 3)]),
      );

      expect(result.structureCount, 2);
      expect(result.structures[0].componentIds, [1, 2]);
      expect(result.structures[1].componentIds, [3, 4]);
      expect(result.structures.map((structure) => structure.id), [1, 2]);
    });

    test('reports connected and isolated structures together', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(
          engine,
          const [1, 2, 3, 4, 5],
          const [(1, 2), (2, 3), (4, 5)],
        ),
      );

      expect(result.structures.map((structure) => structure.componentIds), [
        [1, 2, 3],
        [4, 5],
      ]);
      expect(result.largestStructureSize, 3);
      expect(result.isolatedStructureCount, 0);
    });

    test('keeps component and structure ordering deterministic', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(
          engine,
          const [9, 5, 3, 1, 7],
          const [(7, 9), (3, 1), (9, 5)],
        ),
      );

      expect(result.structures.map((structure) => structure.componentIds), [
        [1, 3],
        [5, 7, 9],
      ]);
      expect(result.structures.map((structure) => structure.id), [1, 2]);
    });

    test('relation input ordering does not change the result', () {
      const ascending = [(1, 2), (2, 3), (4, 5), (5, 4)];
      final descending = ascending.reversed.toList(growable: false);

      final first = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [1, 2, 3, 4, 5], ascending),
      );
      final second = engine.analyzeConnectedStructures(
        graph: _sparseGraph(engine, const [5, 4, 3, 2, 1], descending),
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('assigns every graph component exactly once', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(
          engine,
          const [1, 2, 3, 4, 5, 6],
          const [(1, 2), (2, 3), (5, 6)],
        ),
      );
      final assignedIds = result.structures
          .expand((structure) => structure.componentIds)
          .toList();

      expect(assignedIds, [1, 2, 3, 4, 5, 6]);
      expect(assignedIds.toSet().length, 6);
    });

    test('counts directed edges locally and derives summaries', () {
      final result = engine.analyzeConnectedStructures(
        graph: _sparseGraph(
          engine,
          const [1, 2, 3, 4, 5],
          const [(1, 2), (2, 1), (3, 4)],
        ),
      );

      expect(result.structureCount, 3);
      expect(
        result.structures.map((structure) => structure.directedEdgeCount),
        [2, 1, 0],
      );
      expect(result.largestStructureSize, 2);
      expect(result.isolatedStructureCount, 1);
    });

    test(
      'a strict full graph forms one weak structure for n greater than one',
      () {
        final graph = _fullGraph(engine, const [3, 1, 2]);
        final result = engine.analyzeConnectedStructures(graph: graph);

        expect(result.structureCount, 1);
        expect(result.structures.single.componentIds, [1, 2, 3]);
        expect(result.structures.single.directedEdgeCount, 6);
      },
    );

    test('does not mutate or replace graph components and relations', () {
      final graph = _sparseGraph(
        engine,
        const [1, 2, 3],
        const [(1, 2), (2, 3)],
      );
      final components = graph.components.toList(growable: false);
      final relations = graph.relations.toList(growable: false);
      final adjacency = {
        for (final entry in graph.adjacency.entries)
          entry.key: entry.value.toList(growable: false),
      };

      engine.analyzeConnectedStructures(graph: graph);

      expect(graph.components, orderedEquals(components));
      expect(graph.relations, orderedEquals(relations));
      expect(graph.adjacency, adjacency);
      for (var index = 0; index < components.length; index++) {
        expect(graph.components[index], same(components[index]));
      }
      for (var index = 0; index < relations.length; index++) {
        expect(graph.relations[index], same(relations[index]));
      }
    });
  });
}

VisionSpatialGraph _sparseGraph(
  CoffeeVisionEngine engine,
  List<int> componentIds,
  List<(int, int)> relationPairs,
) {
  final components = componentIds.map(_component).toList(growable: false);
  final relations = relationPairs
      .map((pair) => _relation(pair.$1, pair.$2))
      .toList(growable: false);
  return engine.createSparseSpatialGraph(
    componentResult: _componentResult(components),
    edgeSelectionResult: VisionEdgeSelectionResult(
      profile: const VisionEdgeSelectionProfile(),
      candidateRelations: relations,
      decisionRecords: [
        for (final relation in relations)
          VisionEdgeSelectionDecision(
            relation: relation,
            reason: VisionEdgeSelectionReason.selectedByPassThrough,
          ),
      ],
    ),
  );
}

VisionSpatialGraph _fullGraph(
  CoffeeVisionEngine engine,
  List<int> componentIds,
) {
  final components = componentIds.map(_component).toList(growable: false);
  final ids = componentIds.toSet().toList()..sort();
  return engine.createSpatialGraph(
    componentResult: _componentResult(components),
    relationResult: VisionComponentRelationResult(
      relations: [
        for (final sourceId in ids)
          for (final targetId in ids)
            if (sourceId != targetId) _relation(sourceId, targetId),
      ],
      nearestNeighborByComponentId: {
        for (final id in ids)
          id: ids.length == 1
              ? null
              : ids.firstWhere((candidate) => candidate != id),
      },
    ),
  );
}

VisionComponentResult _componentResult(List<VisionComponent> components) {
  return VisionComponentResult(
    imageSize: (width: 100, height: 100),
    totalResiduePixels: components.fold<int>(
      0,
      (total, component) => total + component.pixelCount,
    ),
    components: components,
  );
}

VisionComponent _component(int id) {
  final left = id / 100;
  final boundingBox = VisionRect(
    left: left,
    top: 0.1,
    right: left + 0.005,
    bottom: 0.2,
  );
  return VisionComponent(
    id: id,
    pixels: [id],
    boundingBox: boundingBox,
    centroid: boundingBox.center,
    areaRatio: 0.01,
  );
}

VisionComponentRelation _relation(int sourceId, int targetId) {
  return VisionComponentRelation(
    sourceComponentId: sourceId,
    targetComponentId: targetId,
    centroidDistance: (targetId - sourceId).abs() / 100,
    boundingBoxDistance: 0.0,
    relativeDirection: targetId > sourceId
        ? VisionRelativeDirection.right
        : VisionRelativeDirection.left,
    boundingBoxesTouch: false,
    boundingBoxesIntersect: true,
  );
}
