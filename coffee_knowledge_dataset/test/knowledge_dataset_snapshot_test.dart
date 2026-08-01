import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:test/test.dart';

void main() {
  KnowledgeRecord record(String id) => KnowledgeRecord(
    id: id,
    constraints: [
      KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 1,
        maximum: 2,
      ),
    ],
  );

  group('KnowledgeDatasetSnapshot', () {
    test('canonicalizes and defensively freezes active records', () {
      final source = [record('record-b'), record('record-a')];
      final snapshot = KnowledgeDatasetSnapshot(
        schemaVersion: '1.0',
        datasetVersion: 'kds-test',
        activeRecords: source,
        totalRecordCount: 3,
      );
      source.clear();

      expect(snapshot.activeRecords.map((item) => item.id), [
        'record-a',
        'record-b',
      ]);
      expect(snapshot.disabledRecordCount, 1);
      expect(
        () => snapshot.activeRecords.add(record('record-c')),
        throwsUnsupportedError,
      );
    });

    test('supports deterministic equality, hashCode, and safe toString', () {
      final first = KnowledgeDatasetSnapshot(
        schemaVersion: '1.0',
        datasetVersion: 'kds-test',
        activeRecords: [record('record-b'), record('record-a')],
        totalRecordCount: 2,
      );
      final second = KnowledgeDatasetSnapshot(
        schemaVersion: '1.0',
        datasetVersion: 'kds-test',
        activeRecords: [record('record-a'), record('record-b')],
        totalRecordCount: 2,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect({first, second}, hasLength(1));
      expect(first.toString(), contains('activeRecordCount: 2'));
      expect(first.toString(), isNot(contains('KnowledgeConstraint')));
    });

    test('rejects invalid versions, counts, and duplicate IDs', () {
      expect(
        () => KnowledgeDatasetSnapshot(
          schemaVersion: '2.0',
          datasetVersion: 'kds-test',
          activeRecords: const [],
          totalRecordCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeDatasetSnapshot(
          schemaVersion: '1.0',
          datasetVersion: ' kds-test',
          activeRecords: const [],
          totalRecordCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeDatasetSnapshot(
          schemaVersion: '1.0',
          datasetVersion: 'kds-test',
          activeRecords: [record('same'), record('same')],
          totalRecordCount: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeDatasetSnapshot(
          schemaVersion: '1.0',
          datasetVersion: 'kds-test',
          activeRecords: [record('record-a')],
          totalRecordCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
