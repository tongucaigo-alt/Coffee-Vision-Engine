import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_source_dataset/coffee_source_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('coffee_source_dataset package boundary', () {
    test('depends only on approved production packages', () {
      final dependencies = _yamlSection(
        File('pubspec.yaml').readAsStringSync(),
        'dependencies',
      );

      expect(dependencies, contains('coffee_source:'));
      expect(dependencies, contains('atlas_canonical_json:'));
      for (final forbidden in [
        'coffee_symbol:',
        'coffee_symbol_dataset:',
        'coffee_knowledge:',
        'coffee_pattern:',
        'coffee_vision:',
        'flutter:',
        'http:',
      ]) {
        expect(dependencies, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('imports dependencies only through public barrels', () {
      final sources = _productionSources();

      expect(sources, isNot(contains('package:coffee_source/src/')));
      expect(sources, isNot(contains('package:atlas_canonical_json/src/')));
    });

    test('exposes one synchronous immutable adapter operation', () {
      final source = File(
        'lib/src/source_catalog_parser.dart',
      ).readAsStringSync();
      final executable = _withoutCommentsAndStrings(source);

      expect(
        RegExp(r'SourceCatalogSnapshot\s+parse\s*\(').allMatches(executable),
        hasLength(1),
      );
      expect(executable, isNot(contains('Future<')));
      expect(executable, isNot(contains('async')));
      expect(
        () => const SourceCatalogParser().parse(
          manifestBytes: Uint8List(0),
          recordDocuments: const <Uint8List>[],
        ),
        throwsA(isA<SourceCatalogException>()),
      );
    });

    test(
      'contains no I/O, writer, eligibility calculation, or Symbol logic',
      () {
        final sources = _productionSources();
        final executable = _withoutCommentsAndStrings(sources).toLowerCase();
        for (final forbidden in [
          "import 'dart:io'",
          'writeas',
          'tojson',
          'encodebundle',
          'symboldefinition',
          'symbolevidencebinding',
          'confidence',
          'ranking',
          'fortune',
          'interpretation',
        ]) {
          expect(executable, isNot(contains(forbidden)), reason: forbidden);
        }
        expect(RegExp(r'\bFile\s*\(').hasMatch(sources), isFalse);
        expect(RegExp(r'\bDirectory\s*\(').hasMatch(sources), isFalse);
      },
    );

    test('contains exactly three schemas and no production dataset', () {
      final schemas = Directory('schemas')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.schema.json'))
          .toList();

      expect(schemas, hasLength(3));
      expect(Directory('datasets').existsSync(), isFalse);
    });
  });
}

String _productionSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .map((file) => file.readAsStringSync())
    .join('\n');

String _yamlSection(String source, String section) {
  final normalized = source.replaceAll('\r\n', '\n');
  final start = normalized.indexOf('$section:\n');
  if (start < 0) return '';
  final rest = normalized.substring(start + section.length + 2);
  final next = RegExp(r'^[A-Za-z_].*:$', multiLine: true).firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}

String _withoutCommentsAndStrings(String source) => source
    .replaceAll(RegExp(r'//[^\r\n]*'), '')
    .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");
