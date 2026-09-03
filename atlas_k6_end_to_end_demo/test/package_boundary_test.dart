import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
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

    test('bundled Symbol release is an explicit definition-only fixture', () {
      final snapshot = const SymbolDatasetParser().parse(
        manifestBytes: File(
          'assets/test-symbol-dataset/manifest.json',
        ).readAsBytesSync(),
        recordDocuments: [
          File(
            'assets/test-symbol-dataset/records/test-symbol-001.json',
          ).readAsBytesSync(),
        ],
      );

      expect(snapshot.manifest.schemaVersion, '2.0');
      expect(
        snapshot.manifest.releaseRef.releaseId,
        'test-symbol-release-definition-only-001',
      );
      expect(snapshot.definitions.single.symbolId, 'test-symbol-001');
      expect(snapshot.bindings, isEmpty);
      expect(snapshot.knowledgeRelease, isNull);
    });

    test('bundled Symbol record checksum mismatch fails closed', () {
      final definitionFile = File(
        'assets/test-symbol-dataset/records/test-symbol-001.json',
      );
      final changedDefinition = definitionFile.readAsStringSync().replaceFirst(
        'Test Symbol',
        'Changed Test Symbol',
      );

      expect(
        () => const SymbolDatasetParser().parse(
          manifestBytes: File(
            'assets/test-symbol-dataset/manifest.json',
          ).readAsBytesSync(),
          recordDocuments: [Uint8List.fromList(utf8.encode(changedDefinition))],
        ),
        throwsA(
          isA<SymbolDatasetException>().having(
            (error) => error.failure,
            'failure',
            SymbolDatasetFailure.checksumMismatch,
          ),
        ),
      );
    });

    test('controller composes only the approved public engine chain', () {
      final source = File(
        'lib/src/integration/atlas_k6_controller.dart',
      ).readAsStringSync();

      expect(source, contains('analyzeFeatures'));
      expect(source, contains('analyzePatterns'));
      expect(source, contains('KnowledgeRecordCollectionMatcher'));
      expect(source, contains('SymbolCandidateResolver'));
      expect(source, contains('_resolveSymbols'));
      expect(source, isNot(contains('analyzeDetailed')));
      expect(source, isNot(contains('VisionPipelineResult')));
      expect(source, isNot(contains('ConstraintEvaluator')));
      expect(source, isNot(contains('KnowledgeRecordEvaluator')));
      expect(source, isNot(contains('KnowledgeRecordMatchDecider')));
      expect(source, isNot(contains("package:coffee_symbol/src/")));
      expect(source, isNot(contains("package:coffee_symbol_dataset/src/")));
    });

    test('exact Knowledge release checksum matches the frozen baseline', () {
      final freeze = File(
        '../coffee_knowledge_dataset/freezes/dataset_freeze_kds_001.txt',
      ).readAsStringSync();
      final checksum = RegExp(
        r'^datasetSha256=(sha256:[0-9a-f]{64})$',
        multiLine: true,
      ).firstMatch(freeze)!.group(1)!;
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(mainSource, contains(checksum));
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
        'fortune',
        'meaning',
        'interpretation',
        'confidence',
        'ranking',
        'winner',
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
