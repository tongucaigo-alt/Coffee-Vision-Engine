import 'dart:io';
import 'dart:convert';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('coffee_knowledge_dataset boundary', () {
    test('production dependency is only coffee_knowledge', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('coffee_knowledge:'));
      for (final forbidden in [
        'coffee_vision:',
        'coffee_pattern:',
        'flutter:',
        'image:',
        'camera:',
        'http:',
        'openai:',
      ]) {
        expect(dependencies, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('K6B exposes only the approved dataset contract', () {
      final source = File(
        'lib/coffee_knowledge_dataset.dart',
      ).readAsStringSync();

      expect(source, contains('KnowledgeDatasetParser'));
      expect(source, contains('KnowledgeDatasetSnapshot'));
      expect(source, contains('KnowledgeDatasetException'));
      expect(
        RegExp(r'^export ', multiLine: true).allMatches(source),
        hasLength(3),
      );
    });

    test('tooling imports only public Vision and Pattern barrels', () {
      final sources = Directory('tool')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(sources, contains('package:coffee_vision/coffee_vision.dart'));
      expect(sources, contains('package:coffee_pattern/coffee_pattern.dart'));
      expect(sources, isNot(contains('package:coffee_vision/src/')));
      expect(sources, isNot(contains('package:coffee_pattern/src/')));
      expect(sources, isNot(contains('VisionPipelineResult')));
      expect(sources, isNot(contains('analyzeDetailed(')));
    });

    test('report contract contains no semantic or scoring fields', () {
      final source = File(
        'tool/src/k6a_models.dart',
      ).readAsStringSync().toLowerCase();

      for (final forbidden in [
        'symbol',
        'fortune',
        'meaning',
        'interpretation',
        'confidence',
        'score',
        'rank',
        'weight',
        'ai',
      ]) {
        expect(
          RegExp('\\b${RegExp.escape(forbidden)}\\b').hasMatch(source),
          isFalse,
          reason: forbidden,
        );
      }
    });

    test('production adapter depends only on the public Knowledge barrel', () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(
        sources,
        contains('package:coffee_knowledge/coffee_knowledge.dart'),
      );
      expect(sources, isNot(contains('package:coffee_knowledge/src/')));
      expect(sources, isNot(contains('dart:io')));
      expect(sources, isNot(contains('package:coffee_pattern/')));
      expect(sources, isNot(contains('package:coffee_vision/')));
    });

    test('K6 contains the dataset and approved research freeze', () {
      expect(
        File('schemas/knowledge_dataset.schema.json').existsSync(),
        isTrue,
      );
      expect(
        File('datasets/kds-001/knowledge_dataset.json').existsSync(),
        isTrue,
      );
      expect(File('freezes/dataset_freeze_kds_001.txt').existsSync(), isTrue);
    });

    test(
      'schema is strict JSON and tracks the exact Knowledge key vocabulary',
      () {
        final schema =
            jsonDecode(
                  File(
                    'schemas/knowledge_dataset.schema.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final definitions = schema[r'$defs']! as Map<String, Object?>;
        final schemaKeys = <String>{};
        for (final definitionName in [
          'doubleKey',
          'integerKey',
          'booleanKey',
        ]) {
          final definition =
              definitions[definitionName]! as Map<String, Object?>;
          schemaKeys.addAll(
            (definition['enum']! as List<Object?>).cast<String>(),
          );
        }

        expect(schema['additionalProperties'], isFalse);
        expect(
          schemaKeys,
          KnowledgeConstraintKey.values.map((key) => key.name).toSet(),
        );
        expect(
          (definitions['record']!
              as Map<String, Object?>)['additionalProperties'],
          isFalse,
        );
      },
    );

    test(
      'dataset contracts contain no semantics, scoring, or interpretation',
      () {
        final sources = [
          ...Directory('lib').listSync(recursive: true).whereType<File>(),
          File('schemas/knowledge_dataset.schema.json'),
          File('datasets/kds-001/knowledge_dataset.json'),
        ].map((file) => file.readAsStringSync().toLowerCase()).join('\n');

        for (final forbidden in [
          'symbol',
          'fortune',
          'meaning',
          'interpretation',
          'confidence',
          'score',
          'rank',
          'weight',
          'openai',
        ]) {
          expect(
            RegExp('\\b${RegExp.escape(forbidden)}\\b').hasMatch(sources),
            isFalse,
            reason: forbidden,
          );
        }
      },
    );
  });
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
