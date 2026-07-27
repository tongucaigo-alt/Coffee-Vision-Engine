import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('VisionComponentRelation', () {
    test('stores validated immutable relation values', () {
      final relation = _modelRelation();

      expect(relation.sourceComponentId, 1);
      expect(relation.targetComponentId, 2);
      expect(relation.centroidDistance, 0.5);
      expect(relation.boundingBoxDistance, 0.25);
      expect(relation.relativeDirection, VisionRelativeDirection.right);
      expect(relation.boundingBoxesTouch, isFalse);
      expect(relation.boundingBoxesIntersect, isFalse);
    });

    test(
      'rejects self relations, invalid distances, and conflicting flags',
      () {
        expect(
          () => _modelRelation(sourceId: 1, targetId: 1),
          throwsArgumentError,
        );
        expect(
          () => _modelRelation(centroidDistance: double.nan),
          throwsArgumentError,
        );
        expect(
          () => _modelRelation(
            boundingBoxesTouch: true,
            boundingBoxesIntersect: true,
          ),
          throwsArgumentError,
        );
      },
    );

    test('keeps equality, hashCode, and toString consistent', () {
      final first = _modelRelation();
      final second = _modelRelation();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('sourceComponentId: 1'));
    });
  });

  group('VisionComponentRelationResult', () {
    test('sorts and defensively protects relations and nearest neighbors', () {
      final relationSource = <VisionComponentRelation>[
        _modelRelation(sourceId: 2, targetId: 1),
        _modelRelation(sourceId: 1, targetId: 2),
      ];
      final nearestSource = <int, int?>{2: 1, 1: 2};
      final result = VisionComponentRelationResult(
        relations: relationSource,
        nearestNeighborByComponentId: nearestSource,
      );

      relationSource.clear();
      nearestSource.clear();
      expect(result.relations.map((relation) => relation.sourceComponentId), [
        1,
        2,
      ]);
      expect(result.nearestNeighborByComponentId.keys, [1, 2]);
      expect(
        () => result.relations.add(_modelRelation()),
        throwsUnsupportedError,
      );
      expect(
        () => result.nearestNeighborByComponentId[1] = null,
        throwsUnsupportedError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final first = VisionComponentRelationResult(
        relations: [_modelRelation(), _modelRelation(sourceId: 2, targetId: 1)],
        nearestNeighborByComponentId: const {1: 2, 2: 1},
      );
      final second = VisionComponentRelationResult(
        relations: [_modelRelation(sourceId: 2, targetId: 1), _modelRelation()],
        nearestNeighborByComponentId: const {2: 1, 1: 2},
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('relationCount: 2'));
    });
  });

  group('CoffeeVisionEngine.analyzeComponentRelations', () {
    const engine = CoffeeVisionEngine();

    test('returns a Future and empty output for no components', () async {
      final future = engine.analyzeComponentRelations(
        componentResult: _componentResult(const []),
      );

      expect(future, isA<Future<VisionComponentRelationResult>>());
      final result = await future;
      expect(result.relations, isEmpty);
      expect(result.nearestNeighborByComponentId, isEmpty);
    });

    test('returns null nearest neighbor for one component', () async {
      final result = await engine.analyzeComponentRelations(
        componentResult: _componentResult([
          _component(7, _rect(0.4, 0.4, 0.6, 0.6)),
        ]),
      );

      expect(result.relations, isEmpty);
      expect(result.nearestNeighborByComponentId, {7: null});
    });

    test(
      'creates directed horizontal relations and raw centroid distance',
      () async {
        final result = await _analyze(engine, [
          _component(1, _rect(0.1, 0.4, 0.2, 0.5)),
          _component(2, _rect(0.6, 0.4, 0.7, 0.5)),
        ]);
        final forward = _relation(result, 1, 2);
        final reverse = _relation(result, 2, 1);

        expect(result.relations, hasLength(2));
        expect(forward.centroidDistance, closeTo(0.5, 1e-12));
        expect(forward.boundingBoxDistance, closeTo(0.4, 1e-12));
        expect(forward.relativeDirection, VisionRelativeDirection.right);
        expect(reverse.relativeDirection, VisionRelativeDirection.left);
        expect(result.nearestNeighborByComponentId, {1: 2, 2: 1});
      },
    );

    test('creates directed vertical relations', () async {
      final result = await _analyze(engine, [
        _component(1, _rect(0.4, 0.1, 0.5, 0.2)),
        _component(2, _rect(0.4, 0.7, 0.5, 0.8)),
      ]);

      expect(
        _relation(result, 1, 2).relativeDirection,
        VisionRelativeDirection.below,
      );
      expect(
        _relation(result, 2, 1).relativeDirection,
        VisionRelativeDirection.above,
      );
    });

    test(
      'uses the horizontal direction when diagonal axis deltas tie',
      () async {
        final result = await _analyze(engine, [
          _component(
            1,
            _rect(0.1, 0.1, 0.3, 0.3),
            centroid: VisionPoint(x: 0.2, y: 0.2),
          ),
          _component(
            2,
            _rect(0.5, 0.5, 0.7, 0.7),
            centroid: VisionPoint(x: 0.6, y: 0.6),
          ),
        ]);

        expect(
          _relation(result, 1, 2).relativeDirection,
          VisionRelativeDirection.right,
        );
        expect(
          _relation(result, 2, 1).relativeDirection,
          VisionRelativeDirection.left,
        );
      },
    );

    test('uses epsilon only to identify overlapping centers', () async {
      final result = await _analyze(engine, [
        _component(
          1,
          _rect(0.1, 0.1, 0.8, 0.8),
          centroid: VisionPoint(x: 0.5, y: 0.5),
        ),
        _component(
          2,
          _rect(0.2, 0.2, 0.9, 0.9),
          centroid: VisionPoint(x: 0.5 + 5e-13, y: 0.5 - 5e-13),
        ),
      ]);

      expect(
        _relation(result, 1, 2).relativeDirection,
        VisionRelativeDirection.overlappingCenter,
      );
    });

    test('distinguishes intersecting and edge-touching boxes', () async {
      final intersecting = await _analyze(engine, [
        _component(1, _rect(0.1, 0.1, 0.5, 0.5)),
        _component(2, _rect(0.4, 0.4, 0.8, 0.8)),
      ]);
      final touching = await _analyze(engine, [
        _component(1, _rect(0.1, 0.1, 0.3, 0.3)),
        _component(2, _rect(0.3, 0.15, 0.5, 0.25)),
      ]);

      final intersection = _relation(intersecting, 1, 2);
      expect(intersection.boundingBoxesIntersect, isTrue);
      expect(intersection.boundingBoxesTouch, isFalse);
      expect(intersection.boundingBoxDistance, 0.0);

      final contact = _relation(touching, 1, 2);
      expect(contact.boundingBoxesIntersect, isFalse);
      expect(contact.boundingBoxesTouch, isTrue);
      expect(contact.boundingBoxDistance, 0.0);
    });

    test('calculates diagonal minimum bounding-box distance', () async {
      final result = await _analyze(engine, [
        _component(1, _rect(0.1, 0.1, 0.2, 0.2)),
        _component(2, _rect(0.4, 0.5, 0.6, 0.7)),
      ]);
      final relation = _relation(result, 1, 2);

      expect(relation.boundingBoxesTouch, isFalse);
      expect(relation.boundingBoxesIntersect, isFalse);
      expect(relation.boundingBoxDistance, closeTo(0.36055512754639896, 1e-12));
    });

    test(
      'selects the lower target id for exact nearest-distance ties',
      () async {
        final result = await _analyze(engine, [
          _component(
            10,
            _rect(0.45, 0.45, 0.55, 0.55),
            centroid: VisionPoint(x: 0.5, y: 0.5),
          ),
          _component(
            3,
            _rect(0.7, 0.45, 0.8, 0.55),
            centroid: VisionPoint(x: 0.75, y: 0.5),
          ),
          _component(
            2,
            _rect(0.2, 0.45, 0.3, 0.55),
            centroid: VisionPoint(x: 0.25, y: 0.5),
          ),
        ]);

        expect(result.nearestNeighborByComponentId[10], 2);
      },
    );

    test('sorts directed pairs and never creates self relations', () async {
      final result = await _analyze(engine, [
        _component(3, _rect(0.7, 0.7, 0.8, 0.8)),
        _component(1, _rect(0.1, 0.1, 0.2, 0.2)),
        _component(2, _rect(0.4, 0.4, 0.5, 0.5)),
      ]);

      expect(
        result.relations
            .map(
              (relation) =>
                  (relation.sourceComponentId, relation.targetComponentId),
            )
            .toList(),
        [(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2)],
      );
      expect(
        result.relations.every(
          (relation) =>
              relation.sourceComponentId != relation.targetComponentId,
        ),
        isTrue,
      );
    });

    test('rejects duplicate component ids', () async {
      final componentResult = _componentResult([
        _component(1, _rect(0.1, 0.1, 0.2, 0.2)),
        _component(1, _rect(0.7, 0.7, 0.8, 0.8)),
      ]);

      await expectLater(
        engine.analyzeComponentRelations(componentResult: componentResult),
        throwsArgumentError,
      );
    });
  });
}

VisionComponentRelation _modelRelation({
  int sourceId = 1,
  int targetId = 2,
  double centroidDistance = 0.5,
  double boundingBoxDistance = 0.25,
  bool boundingBoxesTouch = false,
  bool boundingBoxesIntersect = false,
}) {
  return VisionComponentRelation(
    sourceComponentId: sourceId,
    targetComponentId: targetId,
    centroidDistance: centroidDistance,
    boundingBoxDistance: boundingBoxDistance,
    relativeDirection: VisionRelativeDirection.right,
    boundingBoxesTouch: boundingBoxesTouch,
    boundingBoxesIntersect: boundingBoxesIntersect,
  );
}

Future<VisionComponentRelationResult> _analyze(
  CoffeeVisionEngine engine,
  List<VisionComponent> components,
) {
  return engine.analyzeComponentRelations(
    componentResult: _componentResult(components),
  );
}

VisionComponentRelation _relation(
  VisionComponentRelationResult result,
  int sourceId,
  int targetId,
) {
  return result.relations.singleWhere(
    (relation) =>
        relation.sourceComponentId == sourceId &&
        relation.targetComponentId == targetId,
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

VisionComponent _component(
  int id,
  VisionRect boundingBox, {
  VisionPoint? centroid,
}) {
  return VisionComponent(
    id: id,
    pixels: [id],
    boundingBox: boundingBox,
    centroid: centroid ?? boundingBox.center,
    areaRatio: 0.01,
  );
}

VisionRect _rect(double left, double top, double right, double bottom) {
  return VisionRect(left: left, top: top, right: right, bottom: bottom);
}
