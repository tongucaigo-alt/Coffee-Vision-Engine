import 'dart:io';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  group('atlas_canonical_json package boundary', () {
    test('is pure Dart with crypto as its sole production dependency', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('crypto: ^3.0.7'));
      for (final forbidden in [
        'coffee_symbol:',
        'coffee_knowledge:',
        'coffee_pattern:',
        'coffee_vision:',
        'flutter:',
        'http:',
        'ssi:',
      ]) {
        expect(dependencies, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('dependency boundary parsing is line-ending independent', () {
      const pubspec =
          'name: sample\r\ndependencies:\r\n  crypto: ^3.0.7\r\n'
          'dev_dependencies:\r\n  test: any\r\n';

      expect(_yamlSection(pubspec, 'dependencies'), contains('crypto: ^3.0.7'));
    });

    test('exports only the approved public contract families', () {
      final barrel = File('lib/atlas_canonical_json.dart').readAsStringSync();
      for (final approved in [
        'AtlasCanonicalJson',
        'AtlasCanonicalJsonResult',
        'AtlasCanonicalJsonException',
        'AtlasCanonicalJsonFailure',
        'AtlasCanonicalJsonProfile',
      ]) {
        expect(barrel, contains(approved), reason: approved);
      }
      expect(barrel, isNot(contains('StrictJsonParser')));
      expect(barrel, isNot(contains('JcsEncoder')));
    });

    test('has exactly two synchronous canonicalization operations', () {
      final source = File(
        'lib/src/atlas_canonical_json.dart',
      ).readAsStringSync();
      final executable = _withoutCommentsAndStrings(source);

      expect(
        RegExp(r'canonicalizeUtf8\s*\(').allMatches(executable),
        hasLength(1),
      );
      expect(
        RegExp(r'canonicalizeValue\s*\(').allMatches(executable),
        hasLength(1),
      );
      expect(executable, isNot(contains('Future<')));
      expect(executable, isNot(contains('async')));
    });

    test('production code has no domain, I/O, or normalization behavior', () {
      final sources = _productionSources();
      final executable = _withoutCommentsAndStrings(sources).toLowerCase();
      for (final forbidden in [
        "import 'dart:io'",
        'coffee_symbol',
        'coffee_knowledge',
        'coffee_pattern',
        'coffee_vision',
        'jsondecode',
        'jsonencode',
        '.trim(',
        'normaliz',
        'url',
        'manifestchecksum',
        'symboldefinition',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(const AtlasCanonicalJson(), isA<AtlasCanonicalJson>());
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
