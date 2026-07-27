import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeRecord', () {
    test('canonicalizes constraints by approved key order', () {
      final topology = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 1,
        maximum: 4,
      );
      final geometry = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryWidth,
        minimum: 0.1,
        maximum: 0.8,
      );

      final record = KnowledgeRecord(
        id: 'record-17',
        constraints: [topology, geometry],
      );

      expect(record.id, 'record-17');
      expect(record.constraints, [geometry, topology]);
    });

    test('rejects empty and surrounding-whitespace IDs', () {
      final constraint = _widthConstraint();

      expect(
        () => KnowledgeRecord(id: '', constraints: [constraint]),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeRecord(id: ' record ', constraints: [constraint]),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeRecord(id: '   ', constraints: [constraint]),
        throwsArgumentError,
      );
    });

    test('rejects empty and duplicate constraint keys', () {
      expect(
        () => KnowledgeRecord(id: 'empty', constraints: const []),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeRecord(
          id: 'duplicate',
          constraints: [_widthConstraint(), _widthConstraint()],
        ),
        throwsArgumentError,
      );
    });

    test('defensively preserves an immutable constraint collection', () {
      final mutable = <KnowledgeConstraint>[_widthConstraint()];
      final record = KnowledgeRecord(id: 'immutable', constraints: mutable);
      mutable.clear();

      expect(record.constraints, hasLength(1));
      expect(() => record.constraints.clear(), throwsUnsupportedError);
    });

    test('value equality is independent of caller collection order', () {
      final width = _widthConstraint();
      final topology = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 1,
        maximum: 3,
      );
      final first = KnowledgeRecord(
        id: 'stable',
        constraints: [width, topology],
      );
      final second = KnowledgeRecord(
        id: 'stable',
        constraints: [topology, width],
      );
      final different = KnowledgeRecord(
        id: 'different',
        constraints: [width, topology],
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(different, isNot(first));
      expect(<KnowledgeRecord>{first, second, different}, hasLength(2));
    });

    test('toString exposes only opaque identity and physical count', () {
      final text = KnowledgeRecord(
        id: 'opaque-1',
        constraints: [_widthConstraint()],
      ).toString();

      expect(text, contains('opaque-1'));
      expect(text, contains('constraintCount: 1'));
      expect(text, isNot(contains('symbol')));
      expect(text, isNot(contains('interpretation')));
    });
  });
}

KnowledgeConstraint _widthConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.1,
    maximum: 0.9,
  );
}
