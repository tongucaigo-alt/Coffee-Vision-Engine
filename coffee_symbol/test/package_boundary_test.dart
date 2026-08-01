import 'dart:io';

import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:test/test.dart';

void main() {
  group('coffee_symbol package boundary', () {
    test('is pure Dart and depends only on coffee_knowledge', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('coffee_knowledge:'));
      expect(dependencies, contains('path: ../coffee_knowledge'));
      for (final forbidden in [
        'coffee_pattern:',
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

    test('imports Knowledge only through its public barrel', () {
      final sources = _productionSources();
      final imports = RegExp(
        "import 'package:coffee_knowledge/[^']+';",
      ).allMatches(sources).map((match) => match.group(0)).toSet();

      expect(
        imports.every(
          (value) =>
              value ==
              "import 'package:coffee_knowledge/coffee_knowledge.dart';",
        ),
        isTrue,
      );
      expect(sources, isNot(contains('package:coffee_knowledge/src/')));
      expect(sources, isNot(contains('package:coffee_pattern/')));
      expect(sources, isNot(contains('package:coffee_vision/')));
    });

    test('exposes the approved immutable contract surface', () {
      final barrel = File('lib/coffee_symbol.dart').readAsStringSync();
      for (final approved in [
        'CanonicalJsonProfileRef',
        'KnowledgeDatasetReleaseRef',
        'SourceRef',
        'SymbolRevisionRef',
        'KnowledgeTargetRef',
        'EvidenceAssessmentRef',
        'SourcedLocalizedText',
        'SymbolDefinition',
        'SymbolEvidenceBinding',
        'SymbolCandidateSupport',
        'SymbolCandidate',
        'SymbolCandidateResolver',
      ]) {
        expect(barrel, contains(approved), reason: approved);
      }
      expect(const SymbolCandidateResolver(), isA<SymbolCandidateResolver>());
    });

    test('has one synchronous public resolver behavior only', () {
      final source = File(
        'lib/src/symbol_candidate_resolver.dart',
      ).readAsStringSync();
      final executable = _withoutCommentsAndStrings(source);

      expect(
        RegExp(r'List<SymbolCandidate>\s+resolve\s*\(').allMatches(executable),
        hasLength(1),
      );
      expect(executable, isNot(contains('Future<')));
      expect(executable, isNot(contains('async')));
      expect(executable, isNot(contains('KnowledgeRecordEvaluator')));
      expect(executable, isNot(contains('ConstraintEvaluator')));
      expect(executable, isNot(contains('KnowledgeRecordMatchDecider')));
    });

    test(
      'contains no JSON, I/O, platform, ranking, or interpretation behavior',
      () {
        final sources = _productionSources();
        final executable = _withoutCommentsAndStrings(sources).toLowerCase();
        for (final forbidden in [
          "import 'dart:io'",
          "import 'dart:convert'",
          'jsondecode',
          'jsonencode',
          'fromjson',
          'tojson',
          'file(',
          'directory(',
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
