import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  const engine = CoffeeVisionEngine();

  group('CoffeeVisionEngine.createSpatialGraph', () {
    test('organizes empty results without inventing data', () {
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult(const []),
        relationResult: _relationResult(const []),
      );

      expect(graph.components, isEmpty);
      expect(graph.relations, isEmpty);
      expect(graph.adjacency, isEmpty);
    });

    test('organizes a single component with zero outgoing degree', () {
      final component = _component(7);
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult([component]),
        relationResult: _relationResult([component]),
      );

      expect(graph.components.single, same(component));
      expect(graph.relations, isEmpty);
      expect(graph.adjacency, {7: <int>[]});
      expect(graph.neighborIdsOf(7), isEmpty);
      expect(graph.degreeOf(7), 0);
    });

    test('creates complete directed adjacency for two components', () {
      final components = [_component(2), _component(1)];
      final relationResult = _relationResult(components);
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult(components),
        relationResult: relationResult,
      );

      expect(graph.components.map((component) => component.id), [1, 2]);
      expect(graph.adjacency, {
        1: [2],
        2: [1],
      });
      expect(graph.degreeOf(1), 1);
      expect(graph.degreeOf(2), 1);
    });

    test('sparse graph accepts an empty selected relation set', () {
      final components = [_component(2), _component(1)];
      final graph = engine.createSparseSpatialGraph(
        componentResult: _componentResult(components),
        edgeSelectionResult: VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: const [],
          decisionRecords: const [],
        ),
      );

      expect(graph.components.map((component) => component.id), [1, 2]);
      expect(graph.relations, isEmpty);
      expect(graph.adjacency, {1: <int>[], 2: <int>[]});
    });

    test('sparse graph preserves one-way selected relation identity', () {
      final relation = _relation(1, 2);
      final graph = engine.createSparseSpatialGraph(
        componentResult: _componentResult([_component(1), _component(2)]),
        edgeSelectionResult: VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [relation],
          decisionRecords: [
            VisionEdgeSelectionDecision(
              relation: relation,
              reason: VisionEdgeSelectionReason.selectedByPassThrough,
            ),
          ],
        ),
      );

      expect(graph.relations.single, same(relation));
      expect(graph.adjacency, {
        1: [2],
        2: <int>[],
      });
    });

    test('sparse graph rejects selected relations with unknown ids', () {
      final relation = _relation(1, 3);
      final selection = VisionEdgeSelectionResult(
        profile: const VisionEdgeSelectionProfile(),
        candidateRelations: [relation],
        decisionRecords: [
          VisionEdgeSelectionDecision(
            relation: relation,
            reason: VisionEdgeSelectionReason.selectedByPassThrough,
          ),
        ],
      );

      expect(
        () => engine.createSparseSpatialGraph(
          componentResult: _componentResult([_component(1), _component(2)]),
          edgeSelectionResult: selection,
        ),
        throwsArgumentError,
      );
    });

    test('indexes every three-component relation exactly once', () {
      final components = [_component(3), _component(1), _component(2)];
      final relationResult = _relationResult(components);
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult(components),
        relationResult: relationResult,
      );

      expect(
        graph.relations
            .map(
              (relation) =>
                  (relation.sourceComponentId, relation.targetComponentId),
            )
            .toList(),
        [(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2)],
      );
      expect(graph.adjacency, {
        1: [2, 3],
        2: [1, 3],
        3: [1, 2],
      });
      expect(
        graph.adjacency.values.fold<int>(
          0,
          (total, neighbors) => total + neighbors.length,
        ),
        graph.relations.length,
      );
    });

    test('preserves existing component and relation objects', () {
      final components = [_component(1), _component(2)];
      final relationResult = _relationResult(components);
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult(components),
        relationResult: relationResult,
      );

      expect(graph.components[0], same(components[0]));
      expect(graph.components[1], same(components[1]));
      for (final graphRelation in graph.relations) {
        final sourceRelation = relationResult.relations.singleWhere(
          (relation) =>
              relation.sourceComponentId == graphRelation.sourceComponentId &&
              relation.targetComponentId == graphRelation.targetComponentId,
        );
        expect(graphRelation, same(sourceRelation));
      }
    });

    test('produces equal canonical graphs from different component order', () {
      final ascending = [_component(1), _component(2), _component(3)];
      final descending = ascending.reversed.toList();
      final first = engine.createSpatialGraph(
        componentResult: _componentResult(ascending),
        relationResult: _relationResult(ascending),
      );
      final second = engine.createSpatialGraph(
        componentResult: _componentResult(descending),
        relationResult: _relationResult(descending),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('protects outer and nested collections from mutation', () {
      final components = [_component(1), _component(2)];
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult(components),
        relationResult: _relationResult(components),
      );

      expect(() => graph.components.clear(), throwsUnsupportedError);
      expect(() => graph.relations.clear(), throwsUnsupportedError);
      expect(() => graph.adjacency[1] = const [], throwsUnsupportedError);
      expect(() => graph.adjacency[1]!.add(3), throwsUnsupportedError);
      expect(() => graph.neighborIdsOf(1).clear(), throwsUnsupportedError);
    });

    test('rejects unknown component queries', () {
      final graph = engine.createSpatialGraph(
        componentResult: _componentResult(const []),
        relationResult: _relationResult(const []),
      );

      expect(() => graph.neighborIdsOf(99), throwsArgumentError);
      expect(() => graph.degreeOf(99), throwsArgumentError);
    });

    test('rejects duplicate component ids', () {
      final components = [_component(1), _component(1)];

      expect(
        () => engine.createSpatialGraph(
          componentResult: _componentResult(components),
          relationResult: VisionComponentRelationResult(
            relations: const [],
            nearestNeighborByComponentId: const {1: null},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects nearest-neighbor keys that differ from component ids', () {
      final components = [_component(1), _component(2)];
      final relations = _relationsFor(components);
      final relationResult = VisionComponentRelationResult(
        relations: relations,
        nearestNeighborByComponentId: const {1: 2, 2: 1, 3: null},
      );

      expect(
        () => engine.createSpatialGraph(
          componentResult: _componentResult(components),
          relationResult: relationResult,
        ),
        throwsArgumentError,
      );
    });

    test('rejects incomplete directed relation sets', () {
      final components = [_component(1), _component(2)];
      final relationResult = VisionComponentRelationResult(
        relations: [_relation(1, 2)],
        nearestNeighborByComponentId: const {1: 2, 2: 1},
      );

      expect(
        () => engine.createSpatialGraph(
          componentResult: _componentResult(components),
          relationResult: relationResult,
        ),
        throwsArgumentError,
      );
    });

    test('rejects relations referencing components outside the result', () {
      final components = [_component(1), _component(2)];
      final relationResult = VisionComponentRelationResult(
        relations: [_relation(1, 3), _relation(3, 1)],
        nearestNeighborByComponentId: const {1: 3, 2: 1, 3: 1},
      );

      expect(
        () => engine.createSpatialGraph(
          componentResult: _componentResult(components),
          relationResult: relationResult,
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and count-only toString consistent', () {
      final components = [_component(1), _component(2)];
      final first = engine.createSpatialGraph(
        componentResult: _componentResult(components),
        relationResult: _relationResult(components),
      );
      final second = engine.createSpatialGraph(
        componentResult: _componentResult(components),
        relationResult: _relationResult(components),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'VisionSpatialGraph(componentCount: 2, relationCount: 2)',
      );
    });
  });
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

VisionComponentRelationResult _relationResult(
  List<VisionComponent> components,
) {
  final ids = components.map((component) => component.id).toSet().toList()
    ..sort();
  return VisionComponentRelationResult(
    relations: _relationsFor(components),
    nearestNeighborByComponentId: {
      for (final id in ids)
        id: ids.length == 1
            ? null
            : ids.firstWhere((candidate) => candidate != id),
    },
  );
}

List<VisionComponentRelation> _relationsFor(List<VisionComponent> components) {
  final ids = components.map((component) => component.id).toSet().toList()
    ..sort();
  return [
    for (final sourceId in ids)
      for (final targetId in ids)
        if (sourceId != targetId) _relation(sourceId, targetId),
  ];
}

VisionComponentRelation _relation(int sourceId, int targetId) {
  return VisionComponentRelation(
    sourceComponentId: sourceId,
    targetComponentId: targetId,
    centroidDistance: (targetId - sourceId).abs() / 10,
    boundingBoxDistance: 0.0,
    relativeDirection: targetId > sourceId
        ? VisionRelativeDirection.right
        : VisionRelativeDirection.left,
    boundingBoxesTouch: false,
    boundingBoxesIntersect: true,
  );
}

VisionComponent _component(int id) {
  final left = id / 10;
  final right = left + 0.05;
  final boundingBox = VisionRect(
    left: left,
    top: 0.1,
    right: right,
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
