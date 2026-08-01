import 'dart:io';

import 'package:test/test.dart';

import '../tool/knowledge_dataset_validator.dart';

void main() {
  group('Knowledge dataset validator CLI', () {
    test(
      'accepts the kds-001 candidate and prints only a safe summary',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();

        final code = await runKnowledgeDatasetValidator(
          ['datasets/kds-001/knowledge_dataset.json'],
          output: output,
          errors: errors,
        );

        expect(code, 0);
        expect(output.toString(), 'VALID kds-001: 1 active, 0 disabled.\n');
        expect(errors.toString(), isEmpty);
        expect(output.toString(), isNot(contains('geometryCentroidX')));
      },
    );

    test('returns validation failure without exposing source JSON', () async {
      final directory = await Directory.systemTemp.createTemp('k6b-invalid-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}invalid.json',
      );
      await file.writeAsString('{"schemaVersion":"2.0"}');
      final output = StringBuffer();
      final errors = StringBuffer();

      final code = await runKnowledgeDatasetValidator(
        [file.path],
        output: output,
        errors: errors,
      );

      expect(code, 1);
      expect(output.toString(), isEmpty);
      expect(errors.toString(), contains('missing fields'));
      expect(errors.toString(), isNot(contains(file.path)));
    });

    test(
      'uses exit code two for invalid arguments and unreadable files',
      () async {
        for (final arguments in [
          <String>[],
          ['missing-dataset.json'],
        ]) {
          final output = StringBuffer();
          final errors = StringBuffer();
          final code = await runKnowledgeDatasetValidator(
            arguments,
            output: output,
            errors: errors,
          );

          expect(code, 2);
          expect(output.toString(), isEmpty);
          expect(errors.toString(), isNotEmpty);
        }
      },
    );
  });
}
