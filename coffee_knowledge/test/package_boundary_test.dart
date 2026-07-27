import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('coffee_knowledge package boundary', () {
    test('is pure Dart and depends only on coffee_pattern in production', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('coffee_pattern:'));
      expect(dependencies, contains('path: ../coffee_pattern'));
      for (final forbidden in [
        'coffee_vision:',
        'flutter:',
        'image:',
        'camera:',
        'http:',
        'dio:',
        'openai:',
      ]) {
        expect(dependencies, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('uses no Vision internals or non-public Pattern imports', () {
      final sources = _productionSources();
      final patternImports = RegExp(
        "import 'package:coffee_pattern/[^']+';",
      ).allMatches(sources).map((match) => match.group(0)).toSet();

      expect(
        patternImports.every(
          (value) =>
              value == "import 'package:coffee_pattern/coffee_pattern.dart';",
        ),
        isTrue,
      );
      expect(sources, isNot(contains('package:coffee_pattern/src/')));
      expect(sources, isNot(contains('package:coffee_vision/')));
      expect(sources, isNot(contains("import 'dart:io'")));
      expect(sources, isNot(contains("import 'dart:convert'")));
    });

    test('exports only the approved Knowledge public surface', () {
      final barrel = File('lib/coffee_knowledge.dart').readAsStringSync();

      for (final approved in [
        'ConstraintEvaluator',
        'KnowledgeRecordEvaluator',
        'KnowledgeRecordMatchDecider',
        'KnowledgeConstraint',
        'KnowledgeConstraintKey',
        'KnowledgeConstraintKind',
        'KnowledgeRecord',
        'KnowledgeRecordEvaluationResult',
        'ConstraintMatchResult',
        'KnowledgeConstraintOutcome',
        'KnowledgeConstraintUnavailableReason',
        'KnowledgeMatchResult',
      ]) {
        expect(barrel, contains(approved), reason: approved);
      }
      for (final forbidden in [
        'KnowledgeEngine',
        'KnowledgeDataset',
        'KnowledgeMatchRequest',
        'KnowledgeValidationResult',
        'KnowledgeValidationIssue',
      ]) {
        expect(barrel, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('contains no upstream analysis, JSON, or serialization API', () {
      final executable = _withoutCommentsAndStrings(_productionSources());

      for (final forbidden in [
        'analyzePatterns(',
        'CoffeeVisionEngine',
        'PatternEngine',
        'jsonDecode',
        'jsonEncode',
        'fromJson',
        'toJson',
        'File(',
        'KnowledgeEngine',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('contains no semantic, scoring, AI, or language contract fields', () {
      final declarations = _productionSources()
          .split('\n')
          .where((line) => line.startsWith('  final '))
          .join('\n')
          .toLowerCase();

      for (final forbidden in [
        'score',
        'confidence',
        'rank',
        'weight',
        'priority',
        'symbol',
        'fortune',
        'meaning',
        'label',
        'description',
        'language',
        'interpretation',
        'metadata',
        'domain',
        'enabled',
        'schema',
        'checksum',
      ]) {
        expect(declarations, isNot(contains(forbidden)), reason: forbidden);
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
