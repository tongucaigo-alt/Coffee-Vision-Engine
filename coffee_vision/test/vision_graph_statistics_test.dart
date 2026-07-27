import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  const engine = CoffeeVisionEngine();

  group('VisionGraphStatistics', () {
    test('stores immutable aggregate values', () {
      final statistics = VisionGraphStatistics(
        componentCount: 3,
        relationCount: 6,
        isolatedComponentCount: 0,
        minDegree: 2,
        maxDegree: 2,
        averageDegree: 2.0,
      );

      expect(statistics.componentCount, 3);
      expect(statistics.relationCount, 6);
      expect(statistics.isolatedComponentCount, 0);
      expect(statistics.minDegree, 2);
      expect(statistics.maxDegree, 2);
      expect(statistics.averageDegree, 2.0);
    });

    test('rejects invalid counts, ranges, and averages', () {
      expect(() => _statistics(componentCount: -1), throwsArgumentError);
      expect(() => _statistics(relationCount: -1), throwsArgumentError);
      expect(() => _statistics(isolatedComponentCount: 2), throwsArgumentError);
      expect(
        () => _statistics(minDegree: 2, maxDegree: 1, averageDegree: 1.5),
        throwsArgumentError,
      );
      expect(() => _statistics(averageDegree: double.nan), throwsArgumentError);
      expect(
        () => _statistics(averageDegree: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => _statistics(
          componentCount: 0,
          relationCount: 1,
          isolatedComponentCount: 0,
          minDegree: 0,
          maxDegree: 0,
          averageDegree: 0.0,
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final first = _statistics();
      final second = _statistics();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('componentCount: 1'));
      expect(first.toString(), contains('averageDegree: 0.0'));
    });
  });

  group('CoffeeVisionEngine.analyzeGraphStatistics', () {
    test('returns synchronous zero statistics for an empty graph', () {
      final graph = _graph(engine, const []);
      final statistics = engine.analyzeGraphStatistics(graph: graph);

      expect(statistics, isA<VisionGraphStatistics>());
      expect(statistics.componentCount, 0);
      expect(statistics.relationCount, 0);
      expect(statistics.isolatedComponentCount, 0);
      expect(statistics.minDegree, 0);
      expect(statistics.maxDegree, 0);
      expect(statistics.averageDegree, 0.0);
    });

    test('reports one isolated component with zero degree', () {
      final statistics = engine.analyzeGraphStatistics(
        graph: _graph(engine, [_component(7)]),
      );

      expect(statistics.componentCount, 1);
      expect(statistics.relationCount, 0);
      expect(statistics.isolatedComponentCount, 1);
      expect(statistics.minDegree, 0);
      expect(statistics.maxDegree, 0);
      expect(statistics.averageDegree, 0.0);
    });

    test('summarizes two-component outgoing degrees', () {
      final statistics = engine.analyzeGraphStatistics(
        graph: _graph(engine, [_component(2), _component(1)]),
      );

      expect(statistics.componentCount, 2);
      expect(statistics.relationCount, 2);
      expect(statistics.isolatedComponentCount, 0);
      expect(statistics.minDegree, 1);
      expect(statistics.maxDegree, 1);
      expect(statistics.averageDegree, 1.0);
    });

    test('summarizes three-component outgoing degrees', () {
      final statistics = engine.analyzeGraphStatistics(
        graph: _graph(engine, [_component(3), _component(1), _component(2)]),
      );

      expect(statistics.componentCount, 3);
      expect(statistics.relationCount, 6);
      expect(statistics.isolatedComponentCount, 0);
      expect(statistics.minDegree, 2);
      expect(statistics.maxDegree, 2);
      expect(statistics.averageDegree, 2.0);
    });

    test('is deterministic across component input order', () {
      final ascending = [_component(1), _component(2), _component(3)];
      final descending = ascending.reversed.toList();

      expect(
        engine.analyzeGraphStatistics(graph: _graph(engine, ascending)),
        engine.analyzeGraphStatistics(graph: _graph(engine, descending)),
      );
    });

    test('does not replace or mutate graph data', () {
      final graph = _graph(engine, [_component(1), _component(2)]);
      final components = graph.components.toList(growable: false);
      final relations = graph.relations.toList(growable: false);

      engine.analyzeGraphStatistics(graph: graph);

      expect(graph.components, orderedEquals(components));
      expect(graph.relations, orderedEquals(relations));
      for (var index = 0; index < components.length; index++) {
        expect(graph.components[index], same(components[index]));
      }
      for (var index = 0; index < relations.length; index++) {
        expect(graph.relations[index], same(relations[index]));
      }
    });
  });
}

VisionGraphStatistics _statistics({
  int componentCount = 1,
  int relationCount = 0,
  int isolatedComponentCount = 1,
  int minDegree = 0,
  int maxDegree = 0,
  double averageDegree = 0.0,
}) {
  return VisionGraphStatistics(
    componentCount: componentCount,
    relationCount: relationCount,
    isolatedComponentCount: isolatedComponentCount,
    minDegree: minDegree,
    maxDegree: maxDegree,
    averageDegree: averageDegree,
  );
}

VisionSpatialGraph _graph(
  CoffeeVisionEngine engine,
  List<VisionComponent> components,
) {
  final ids = components.map((component) => component.id).toSet().toList()
    ..sort();
  final componentResult = VisionComponentResult(
    imageSize: (width: 100, height: 100),
    totalResiduePixels: components.fold<int>(
      0,
      (total, component) => total + component.pixelCount,
    ),
    components: components,
  );
  final relationResult = VisionComponentRelationResult(
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
  );
  return engine.createSpatialGraph(
    componentResult: componentResult,
    relationResult: relationResult,
  );
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
  final boundingBox = VisionRect(
    left: left,
    top: 0.1,
    right: left + 0.05,
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
