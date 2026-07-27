import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  const engine = CoffeeVisionEngine();

  group('VisionEdgeSelectionProfile', () {
    test('defaults to an explicit pass-through profile', () {
      const profile = VisionEdgeSelectionProfile();

      expect(profile.maxCentroidDistance, isNull);
      expect(profile.maxBoundingBoxDistance, isNull);
      expect(profile.requireBoundingBoxTouch, isFalse);
      expect(profile.maxOutgoingPerSource, isNull);
      expect(profile.isPassThrough, isTrue);
    });

    test('accepts zero-valued active filters', () {
      const profile = VisionEdgeSelectionProfile(
        maxCentroidDistance: 0.0,
        maxBoundingBoxDistance: 0.0,
        maxOutgoingPerSource: 0,
      );

      expect(profile.isPassThrough, isFalse);
    });

    test('rejects invalid distances and outgoing limits', () {
      expect(
        () => VisionEdgeSelectionProfile(maxCentroidDistance: -0.1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () =>
            VisionEdgeSelectionProfile(maxBoundingBoxDistance: double.infinity),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VisionEdgeSelectionProfile(maxCentroidDistance: double.nan),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VisionEdgeSelectionProfile(maxOutgoingPerSource: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      const first = VisionEdgeSelectionProfile(
        maxCentroidDistance: 0.4,
        requireBoundingBoxTouch: true,
      );
      const second = VisionEdgeSelectionProfile(
        maxCentroidDistance: 0.4,
        requireBoundingBoxTouch: true,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('maxCentroidDistance: 0.4'));
    });
  });

  group('VisionEdgeSelectionDecision and result', () {
    test('derives selected state and directed ids from the relation', () {
      final relation = _relation(1, 2);
      final selected = VisionEdgeSelectionDecision(
        relation: relation,
        reason: VisionEdgeSelectionReason.selectedByPassThrough,
      );
      final rejected = VisionEdgeSelectionDecision(
        relation: relation,
        reason: VisionEdgeSelectionReason.rejectedByOutgoingLimit,
      );

      expect(selected.sourceComponentId, 1);
      expect(selected.targetComponentId, 2);
      expect(selected.selected, isTrue);
      expect(rejected.selected, isFalse);
    });

    test('canonicalizes records and derives selected relation identities', () {
      final forward = _relation(1, 2);
      final reverse = _relation(2, 1);
      final result = VisionEdgeSelectionResult(
        profile: const VisionEdgeSelectionProfile(),
        candidateRelations: [reverse, forward],
        decisionRecords: [
          VisionEdgeSelectionDecision(
            relation: reverse,
            reason: VisionEdgeSelectionReason.selectedByPassThrough,
          ),
          VisionEdgeSelectionDecision(
            relation: forward,
            reason: VisionEdgeSelectionReason.selectedByPassThrough,
          ),
        ],
      );

      expect(_pairsOfDecisions(result.decisionRecords), [(1, 2), (2, 1)]);
      expect(_pairsOfRelations(result.selectedRelations), [(1, 2), (2, 1)]);
      expect(result.selectedRelations[0], same(forward));
      expect(result.selectedRelations[1], same(reverse));
      expect(() => result.decisionRecords.clear(), throwsUnsupportedError);
      expect(() => result.selectedRelations.clear(), throwsUnsupportedError);
    });

    test('rejects missing, duplicate, and extra decisions', () {
      final forward = _relation(1, 2);
      final reverse = _relation(2, 1);
      final forwardDecision = VisionEdgeSelectionDecision(
        relation: forward,
        reason: VisionEdgeSelectionReason.selectedByPassThrough,
      );
      final reverseDecision = VisionEdgeSelectionDecision(
        relation: reverse,
        reason: VisionEdgeSelectionReason.selectedByPassThrough,
      );

      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [forward, reverse],
          decisionRecords: [forwardDecision],
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [forward, forward],
          decisionRecords: [forwardDecision],
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [forward, reverse],
          decisionRecords: [forwardDecision, forwardDecision],
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [forward],
          decisionRecords: [forwardDecision, reverseDecision],
        ),
        throwsArgumentError,
      );
    });

    test('rejects cloned relation instances and inconsistent reasons', () {
      final candidate = _relation(1, 2);
      final clone = _relation(1, 2);

      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [candidate],
          decisionRecords: [
            VisionEdgeSelectionDecision(
              relation: clone,
              reason: VisionEdgeSelectionReason.selectedByPassThrough,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(),
          candidateRelations: [candidate],
          decisionRecords: [
            VisionEdgeSelectionDecision(
              relation: candidate,
              reason: VisionEdgeSelectionReason.rejectedByCentroidDistance,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VisionEdgeSelectionResult(
          profile: const VisionEdgeSelectionProfile(maxCentroidDistance: 1.0),
          candidateRelations: [candidate],
          decisionRecords: [
            VisionEdgeSelectionDecision(
              relation: candidate,
              reason: VisionEdgeSelectionReason.selectedByPassThrough,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('keeps equality, hashCode, and toString consistent', () {
      final relation = _relation(1, 2);
      VisionEdgeSelectionResult create() => VisionEdgeSelectionResult(
        profile: const VisionEdgeSelectionProfile(),
        candidateRelations: [relation],
        decisionRecords: [
          VisionEdgeSelectionDecision(
            relation: relation,
            reason: VisionEdgeSelectionReason.selectedByPassThrough,
          ),
        ],
      );

      final first = create();
      final second = create();
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('candidateCount: 1'));
    });
  });

  group('CoffeeVisionEngine.selectEdges', () {
    test(
      'pass-through produces one selected decision per directed candidate',
      () {
        final input = _fullRelationResult([3, 1, 2]);
        final result = engine.selectEdges(relationResult: input);

        expect(result.decisionRecords, hasLength(6));
        expect(result.selectedRelations, hasLength(6));
        expect(
          result.decisionRecords.every(
            (decision) =>
                decision.selected &&
                decision.reason ==
                    VisionEdgeSelectionReason.selectedByPassThrough,
          ),
          isTrue,
        );
        expect(_pairsOfDecisions(result.decisionRecords), [
          (1, 2),
          (1, 3),
          (2, 1),
          (2, 3),
          (3, 1),
          (3, 2),
        ]);
        for (var index = 0; index < input.relations.length; index++) {
          expect(
            result.decisionRecords[index].relation,
            same(input.relations[index]),
          );
        }
      },
    );

    test('uses inclusive distance thresholds', () {
      final input = _fullRelationResult(
        [1, 2],
        overrides: {
          '1-2': const _RelationValues(centroid: 0.5, boundingBox: 0.25),
          '2-1': const _RelationValues(centroid: 0.5001, boundingBox: 0.25),
        },
      );
      final result = engine.selectEdges(
        relationResult: input,
        profile: const VisionEdgeSelectionProfile(
          maxCentroidDistance: 0.5,
          maxBoundingBoxDistance: 0.25,
        ),
      );

      expect(_decision(result, 1, 2).selected, isTrue);
      expect(
        _decision(result, 2, 1).reason,
        VisionEdgeSelectionReason.rejectedByCentroidDistance,
      );
    });

    test('records the first failed geometric filter', () {
      final input = _fullRelationResult(
        [1, 2],
        overrides: {
          '1-2': const _RelationValues(centroid: 0.6, boundingBox: 0.6),
          '2-1': const _RelationValues(centroid: 0.4, boundingBox: 0.6),
        },
      );
      final result = engine.selectEdges(
        relationResult: input,
        profile: const VisionEdgeSelectionProfile(
          maxCentroidDistance: 0.5,
          maxBoundingBoxDistance: 0.5,
          requireBoundingBoxTouch: true,
        ),
      );

      expect(
        _decision(result, 1, 2).reason,
        VisionEdgeSelectionReason.rejectedByCentroidDistance,
      );
      expect(
        _decision(result, 2, 1).reason,
        VisionEdgeSelectionReason.rejectedByBoundingBoxDistance,
      );
    });

    test('treats literal touch as distinct from intersection', () {
      final input = _fullRelationResult(
        [1, 2],
        overrides: {
          '1-2': const _RelationValues(touch: true),
          '2-1': const _RelationValues(intersect: true),
        },
      );
      final result = engine.selectEdges(
        relationResult: input,
        profile: const VisionEdgeSelectionProfile(
          requireBoundingBoxTouch: true,
        ),
      );

      expect(_decision(result, 1, 2).selected, isTrue);
      expect(
        _decision(result, 2, 1).reason,
        VisionEdgeSelectionReason.rejectedByBoundingBoxTouch,
      );
    });

    test('applies zero outgoing limit after geometric filters', () {
      final result = engine.selectEdges(
        relationResult: _fullRelationResult([1, 2]),
        profile: const VisionEdgeSelectionProfile(maxOutgoingPerSource: 0),
      );

      expect(result.selectedRelations, isEmpty);
      expect(
        result.decisionRecords.every(
          (decision) =>
              decision.reason ==
              VisionEdgeSelectionReason.rejectedByOutgoingLimit,
        ),
        isTrue,
      );
    });

    test('uses centroid, bbox, then target id for outgoing ties', () {
      final result = engine.selectEdges(
        relationResult: _fullRelationResult(
          [1, 2, 3, 4, 5],
          overrides: {
            '1-2': const _RelationValues(centroid: 0.1, boundingBox: 0.9),
            '1-3': const _RelationValues(centroid: 0.2, boundingBox: 0.1),
            '1-4': const _RelationValues(centroid: 0.2, boundingBox: 0.2),
            '1-5': const _RelationValues(centroid: 0.2, boundingBox: 0.1),
          },
        ),
        profile: const VisionEdgeSelectionProfile(maxOutgoingPerSource: 3),
      );

      expect(
        result.selectedRelations
            .where((relation) => relation.sourceComponentId == 1)
            .map((relation) => relation.targetComponentId),
        [2, 3, 5],
      );
      expect(
        _decision(result, 1, 4).reason,
        VisionEdgeSelectionReason.rejectedByOutgoingLimit,
      );
    });

    test('evaluates opposite directions independently', () {
      final result = engine.selectEdges(
        relationResult: _fullRelationResult(
          [1, 2],
          overrides: {
            '1-2': const _RelationValues(centroid: 0.4),
            '2-1': const _RelationValues(centroid: 0.6),
          },
        ),
        profile: const VisionEdgeSelectionProfile(maxCentroidDistance: 0.5),
      );

      expect(_decision(result, 1, 2).selected, isTrue);
      expect(_decision(result, 2, 1).selected, isFalse);
    });

    test('rejects incomplete full candidate input', () {
      final partial = VisionComponentRelationResult(
        relations: [_relation(1, 2)],
        nearestNeighborByComponentId: const {1: 2, 2: 1},
      );

      expect(
        () => engine.selectEdges(relationResult: partial),
        throwsArgumentError,
      );
    });

    test('does not mutate the relation result or profile', () {
      final input = _fullRelationResult([1, 2, 3]);
      const profile = VisionEdgeSelectionProfile(maxOutgoingPerSource: 1);
      final beforeRelations = input.relations.toList(growable: false);
      final beforeNearest = Map<int, int?>.from(
        input.nearestNeighborByComponentId,
      );

      engine.selectEdges(relationResult: input, profile: profile);

      expect(input.relations, orderedEquals(beforeRelations));
      expect(input.nearestNeighborByComponentId, beforeNearest);
      expect(
        profile,
        const VisionEdgeSelectionProfile(maxOutgoingPerSource: 1),
      );
    });
  });
}

VisionEdgeSelectionDecision _decision(
  VisionEdgeSelectionResult result,
  int sourceId,
  int targetId,
) {
  return result.decisionRecords.singleWhere(
    (decision) =>
        decision.sourceComponentId == sourceId &&
        decision.targetComponentId == targetId,
  );
}

List<(int, int)> _pairsOfDecisions(
  Iterable<VisionEdgeSelectionDecision> decisions,
) => [
  for (final decision in decisions)
    (decision.sourceComponentId, decision.targetComponentId),
];

List<(int, int)> _pairsOfRelations(
  Iterable<VisionComponentRelation> relations,
) => [
  for (final relation in relations)
    (relation.sourceComponentId, relation.targetComponentId),
];

VisionComponentRelationResult _fullRelationResult(
  List<int> componentIds, {
  Map<String, _RelationValues> overrides = const {},
}) {
  final ids = componentIds.toSet().toList()..sort();
  return VisionComponentRelationResult(
    relations: [
      for (final sourceId in ids)
        for (final targetId in ids)
          if (sourceId != targetId)
            _relation(
              sourceId,
              targetId,
              values: overrides['$sourceId-$targetId'],
            ),
    ],
    nearestNeighborByComponentId: {
      for (final id in ids)
        id: ids.length == 1
            ? null
            : ids.firstWhere((candidate) => candidate != id),
    },
  );
}

VisionComponentRelation _relation(
  int sourceId,
  int targetId, {
  _RelationValues? values,
}) {
  final resolved = values ?? const _RelationValues();
  return VisionComponentRelation(
    sourceComponentId: sourceId,
    targetComponentId: targetId,
    centroidDistance: resolved.centroid,
    boundingBoxDistance: resolved.boundingBox,
    relativeDirection: targetId > sourceId
        ? VisionRelativeDirection.right
        : VisionRelativeDirection.left,
    boundingBoxesTouch: resolved.touch,
    boundingBoxesIntersect: resolved.intersect,
  );
}

final class _RelationValues {
  const _RelationValues({
    this.centroid = 0.25,
    this.boundingBox = 0.1,
    this.touch = false,
    this.intersect = false,
  });

  final double centroid;
  final double boundingBox;
  final bool touch;
  final bool intersect;
}
