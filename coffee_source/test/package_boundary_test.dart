import 'dart:io';

import 'package:coffee_source/coffee_source.dart';
import 'package:test/test.dart';

void main() {
  group('coffee_source package boundary', () {
    test('is pure Dart and depends only on coffee_symbol', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('coffee_symbol:'));
      expect(dependencies, contains('path: ../coffee_symbol'));
      for (final forbidden in [
        'atlas_canonical_json:',
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

    test('imports Symbol only through its public barrel', () {
      final sources = _productionSources();
      final imports = RegExp(
        "import 'package:coffee_symbol/[^']+';",
      ).allMatches(sources).map((match) => match.group(0)).toSet();

      expect(imports, {"import 'package:coffee_symbol/coffee_symbol.dart';"});
      expect(sources, isNot(contains('package:coffee_symbol/src/')));
      expect(sources, isNot(contains('package:coffee_knowledge/')));
      expect(sources, isNot(contains('package:coffee_pattern/')));
      expect(sources, isNot(contains('package:coffee_vision/')));
    });

    test('re-exports frozen reference types without redefining them', () {
      final barrel = File('lib/coffee_source.dart').readAsStringSync();
      final sources = _productionSources();

      expect(barrel, contains('CanonicalJsonProfileRef'));
      expect(barrel, contains('SourceRef'));
      expect(RegExp(r'class\s+SourceRef\b').allMatches(sources), isEmpty);
      expect(
        RegExp(r'class\s+CanonicalJsonProfileRef\b').allMatches(sources),
        isEmpty,
      );
    });

    test('exposes approved Source and catalog contracts', () {
      final barrel = File('lib/coffee_source.dart').readAsStringSync();
      expect(SourceRecord.recordType, 'atlas.sourceRecord');
      for (final approved in [
        'SourceRecord',
        'SourceClass',
        'SourceAgent',
        'SourceAgentType',
        'PublicationInfo',
        'LanguageInfo',
        'SourceIdentifier',
        'SourceIdentifierType',
        'AccessInfo',
        'RightsInfo',
        'RightsStatus',
        'CulturalCoverage',
        'CulturalCoverageBasis',
        'IntegrityInfo',
        'SourceManifestationType',
        'DomainTargetRef',
        'SourceUseAssessment',
        'QualityDimensions',
        'SourceCatalogReleaseManifest',
      ]) {
        expect(barrel, contains(approved), reason: approved);
      }
    });

    test('contains no JSON, I/O, policy, or semantic behavior', () {
      final sources = _productionSources();
      final executable = _withoutCommentsAndStrings(sources).toLowerCase();
      for (final forbidden in [
        "import 'dart:io'",
        "import 'dart:convert'",
        'fromjson',
        'tojson',
        'jsondecode',
        'jsonencode',
        'file(',
        'directory(',
        'confidence',
        'ranking',
        'fortune',
        'interpretation',
        'symboldefinition',
        'symbolevidencebinding',
        'admissionpolicy',
        'final bool enabled',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
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
  final start = source.indexOf('$section:\n');
  if (start < 0) return '';
  final rest = source.substring(start + section.length + 2);
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
