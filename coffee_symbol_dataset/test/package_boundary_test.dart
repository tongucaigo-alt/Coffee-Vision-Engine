import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('coffee_symbol_dataset package boundary', () {
    test('depends only on approved public production packages', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('atlas_canonical_json:'));
      expect(dependencies, contains('path: ../atlas_canonical_json'));
      expect(dependencies, contains('coffee_symbol:'));
      expect(dependencies, contains('path: ../coffee_symbol'));
      for (final forbidden in [
        'coffee_knowledge:',
        'coffee_pattern:',
        'coffee_vision:',
        'flutter:',
        'http:',
        'image:',
        'camera:',
        'openai:',
      ]) {
        expect(dependencies, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('imports both dependencies only through public barrels', () {
      final sources = _productionSources();

      expect(sources, isNot(contains('package:coffee_symbol/src/')));
      expect(sources, isNot(contains('package:atlas_canonical_json/src/')));
      expect(sources, isNot(contains('package:coffee_knowledge/')));
      expect(sources, isNot(contains('package:coffee_pattern/')));
      expect(sources, isNot(contains('package:coffee_vision/')));
    });

    test('exposes the approved immutable adapter surface', () {
      final barrel = File('lib/coffee_symbol_dataset.dart').readAsStringSync();
      for (final approved in [
        'SymbolDatasetParser',
        'SymbolDatasetSnapshot',
        'SymbolReleaseManifest',
        'SymbolReleaseRef',
        'SymbolReleaseRecordRef',
        'GovernanceSnapshotRef',
        'SourceCatalogReleaseRef',
        'SymbolAdmissionPolicyRef',
        'EvidenceAdmissionPolicyRef',
        'EvidenceAssessmentRegistryReleaseRef',
        'SymbolDatasetException',
        'SymbolDatasetFailure',
      ]) {
        expect(barrel, contains(approved), reason: approved);
      }
      expect(const SymbolDatasetParser(), isA<SymbolDatasetParser>());
    });

    test('has one synchronous public parser operation only', () {
      final source = File(
        'lib/src/symbol_dataset_parser.dart',
      ).readAsStringSync();
      final executable = _withoutCommentsAndStrings(source);

      expect(
        RegExp(r'SymbolDatasetSnapshot\s+parse\s*\(').allMatches(executable),
        hasLength(1),
      );
      expect(executable, isNot(contains('Future<')));
      expect(executable, isNot(contains('async')));
      expect(
        () => const SymbolDatasetParser().parse(
          manifestBytes: Uint8List(0),
          recordDocuments: const <Uint8List>[],
        ),
        throwsA(isA<SymbolDatasetException>()),
      );
    });

    test(
      'contains no file I/O, writer, ranking, or interpretation behavior',
      () {
        final sources = _productionSources();
        final executable = _withoutCommentsAndStrings(sources).toLowerCase();
        for (final forbidden in [
          "import 'dart:io'",
          'file(',
          'directory(',
          'writeas',
          'tojson',
          'encodebundle',
          'score',
          'confidence',
          'ranking',
          'winner',
          'fortune',
          'interpretation',
          'openai',
          'http',
        ]) {
          expect(executable, isNot(contains(forbidden)), reason: forbidden);
        }
        expect(sources, isNot(contains('final bool enabled')));
      },
    );

    test('contains schemas and no production dataset directory', () {
      expect(
        File('schemas/symbol_definition.schema.json').existsSync(),
        isTrue,
      );
      expect(
        File('schemas/symbol_evidence_binding.schema.json').existsSync(),
        isTrue,
      );
      expect(
        File('schemas/symbol_release_manifest.schema.json').existsSync(),
        isTrue,
      );
      expect(Directory('datasets').existsSync(), isFalse);
    });
  });
}

String _productionSources() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
}

String _yamlSection(String source, String section) {
  final normalized = source.replaceAll('\r\n', '\n');
  final start = normalized.indexOf('$section:\n');
  if (start < 0) return '';
  final rest = normalized.substring(start + section.length + 2);
  final nextTopLevel = RegExp(
    r'^[A-Za-z_].*:$',
    multiLine: true,
  ).firstMatch(rest);
  return nextTopLevel == null ? rest : rest.substring(0, nextTopLevel.start);
}

String _withoutCommentsAndStrings(String source) {
  return source
      .replaceAll(RegExp(r'//[^\r\n]*'), '')
      .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");
}
