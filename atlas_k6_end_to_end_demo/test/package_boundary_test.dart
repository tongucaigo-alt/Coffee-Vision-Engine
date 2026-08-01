import 'dart:io';

import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Atlas K6 integration boundary', () {
    test('bundled dataset is byte-identical to frozen kds-001', () {
      final bundled = File(
        'assets/kds-001/knowledge_dataset.json',
      ).readAsBytesSync();
      final frozen = File(
        '../coffee_knowledge_dataset/datasets/kds-001/knowledge_dataset.json',
      ).readAsBytesSync();

      expect(bundled, orderedEquals(frozen));
      final snapshot = const KnowledgeDatasetParser().parse(
        String.fromCharCodes(bundled),
      );
      expect(snapshot.datasetVersion, 'kds-001');
      expect(snapshot.activeRecords, hasLength(1));
    });

    test('controller composes only the approved public engine chain', () {
      final source = File(
        'lib/src/integration/atlas_k6_controller.dart',
      ).readAsStringSync();

      expect(source, contains('analyzeFeatures'));
      expect(source, contains('analyzePatterns'));
      expect(source, contains('KnowledgeRecordCollectionMatcher'));
      expect(source, isNot(contains('analyzeDetailed')));
      expect(source, isNot(contains('VisionPipelineResult')));
      expect(source, isNot(contains('ConstraintEvaluator')));
      expect(source, isNot(contains('KnowledgeRecordEvaluator')));
      expect(source, isNot(contains('KnowledgeRecordMatchDecider')));
    });

    test('integration never writes or deletes capture files', () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(sources, isNot(contains('writeAsBytes')));
      expect(sources, isNot(contains('writeAsString')));
      expect(sources, isNot(contains('.delete(')));
      expect(sources, isNot(contains('FileMode')));
    });

    test('contains no semantic, scoring, interpretation, or AI behavior', () {
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync().toLowerCase())
          .join('\n');

      for (final forbidden in [
        'symbol',
        'fortune',
        'meaning',
        'interpretation',
        'confidence',
        'ranking',
        'openai',
      ]) {
        expect(
          RegExp('\\b${RegExp.escape(forbidden)}\\b').hasMatch(source),
          isFalse,
          reason: forbidden,
        );
      }
    });
  });
}
