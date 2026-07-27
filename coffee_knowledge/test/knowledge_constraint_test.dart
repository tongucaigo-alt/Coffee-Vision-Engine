import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeConstraint', () {
    test('keeps the approved field vocabulary in canonical order', () {
      expect(KnowledgeConstraintKey.values, [
        KnowledgeConstraintKey.geometryLeft,
        KnowledgeConstraintKey.geometryTop,
        KnowledgeConstraintKey.geometryRight,
        KnowledgeConstraintKey.geometryBottom,
        KnowledgeConstraintKey.geometryCentroidX,
        KnowledgeConstraintKey.geometryCentroidY,
        KnowledgeConstraintKey.geometryWidth,
        KnowledgeConstraintKey.geometryHeight,
        KnowledgeConstraintKey.geometryAspectRatio,
        KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
        KnowledgeConstraintKey.topologyNodeCount,
        KnowledgeConstraintKey.topologyDirectedEdgeCount,
        KnowledgeConstraintKey.topologyIsIsolated,
      ]);
    });

    test('creates finite inclusive double ranges', () {
      final constraint = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryCentroidX,
        minimum: 0.25,
        maximum: 0.75,
      );

      expect(constraint.kind, KnowledgeConstraintKind.doubleRange);
      expect(constraint.minimumDouble, 0.25);
      expect(constraint.maximumDouble, 0.75);
      expect(constraint.minimumInteger, isNull);
      expect(constraint.expectedBoolean, isNull);
    });

    test('supports normalized extent and positive aspect-ratio ranges', () {
      expect(
        KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryWidth,
          minimum: 0.0,
          maximum: 1.0,
        ),
        isA<KnowledgeConstraint>(),
      );
      expect(
        KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryAspectRatio,
          minimum: 0.0,
          maximum: 12.0,
        ),
        isA<KnowledgeConstraint>(),
      );
    });

    test('rejects non-finite, reversed, and out-of-domain double ranges', () {
      expect(
        () => KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryLeft,
          minimum: double.nan,
          maximum: 1.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryLeft,
          minimum: 0.8,
          maximum: 0.2,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryCentroidY,
          minimum: -0.1,
          maximum: 0.5,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryHeight,
          minimum: 0.0,
          maximum: 0.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.geometryAspectRatio,
          minimum: 0.0,
          maximum: 0.0,
        ),
        throwsArgumentError,
      );
    });

    test('creates integer ranges and represents exact integers', () {
      final range = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 2,
        maximum: 5,
      );
      final exact = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyDirectedEdgeCount,
        minimum: 4,
        maximum: 4,
      );

      expect(range.kind, KnowledgeConstraintKind.integerRange);
      expect(range.minimumInteger, 2);
      expect(range.maximumInteger, 5);
      expect(exact.minimumInteger, exact.maximumInteger);
    });

    test('rejects reversed and invalid integer domains', () {
      expect(
        () => KnowledgeConstraint.integerRange(
          key: KnowledgeConstraintKey.topologyNodeCount,
          minimum: 3,
          maximum: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.integerRange(
          key: KnowledgeConstraintKey.topologyNodeCount,
          minimum: 0,
          maximum: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.integerRange(
          key: KnowledgeConstraintKey.topologyDirectedEdgeCount,
          minimum: -1,
          maximum: 2,
        ),
        throwsArgumentError,
      );
    });

    test('creates exact boolean constraints', () {
      final border = KnowledgeConstraint.booleanEquals(
        key: KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
        expected: true,
      );
      final isolated = KnowledgeConstraint.booleanEquals(
        key: KnowledgeConstraintKey.topologyIsIsolated,
        expected: false,
      );

      expect(border.kind, KnowledgeConstraintKind.booleanEquals);
      expect(border.expectedBoolean, isTrue);
      expect(isolated.expectedBoolean, isFalse);
    });

    test('rejects key and constraint-type mismatches', () {
      expect(
        () => KnowledgeConstraint.doubleRange(
          key: KnowledgeConstraintKey.topologyNodeCount,
          minimum: 1.0,
          maximum: 2.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.integerRange(
          key: KnowledgeConstraintKey.geometryWidth,
          minimum: 1,
          maximum: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeConstraint.booleanEquals(
          key: KnowledgeConstraintKey.geometryLeft,
          expected: true,
        ),
        throwsArgumentError,
      );
    });

    test('supports deterministic equality, hashCode, and safe toString', () {
      final first = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryAspectRatio,
        minimum: 0.5,
        maximum: 2.0,
      );
      final second = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryAspectRatio,
        minimum: 0.5,
        maximum: 2.0,
      );
      final different = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryAspectRatio,
        minimum: 0.5,
        maximum: 3.0,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(different, isNot(first));
      expect(<KnowledgeConstraint>{first, second, different}, hasLength(2));
      expect(first.toString(), contains('geometryAspectRatio'));
      expect(first.toString(), isNot(contains('meaning')));
    });
  });
}
