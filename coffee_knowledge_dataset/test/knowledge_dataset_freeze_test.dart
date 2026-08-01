import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  group('kds-001 research baseline freeze', () {
    test('records the complete immutable research decision', () {
      final freeze = _readFreeze();

      expect(freeze['datasetVersion'], 'kds-001');
      expect(freeze['freezeStatus'], 'research-baseline');
      expect(freeze['schemaVersion'], '1.0');
      expect(freeze['activeRecordCount'], '1');
      expect(freeze['disabledRecordCount'], '0');
      expect(freeze['authoringObservationCount'], '2');
      expect(freeze['holdoutObservationCount'], '1');
      expect(freeze['holdoutMatched'], 'true');
      expect(freeze['holdoutPassedConstraintCount'], '3');
      expect(freeze['determinismStatus'], 'pass');
      expect(freeze['datasetValidationStatus'], 'pass');
      expect(freeze['frozenUpstreamIntegrityStatus'], 'pass');
    });

    test('binds the frozen dataset and schema by exact SHA-256', () async {
      final freeze = _readFreeze();

      expect(
        freeze['datasetSha256'],
        'sha256:${await _sha256Of('datasets/kds-001/knowledge_dataset.json')}',
      );
      expect(
        freeze['schemaSha256'],
        'sha256:${await _sha256Of('schemas/knowledge_dataset.schema.json')}',
      );
    });

    test('does not overstate the evidence or production readiness', () {
      final freeze = _readFreeze();

      expect(freeze['canonicalOutOfCohortMatchCount'], '1');
      expect(freeze['externalChallengeObservationCount'], '27');
      expect(freeze['externalChallengeMatchCount'], '0');
      expect(freeze['externalChallengeRole'], 'non-canonical-research-only');
      expect(freeze['productionReadiness'], 'not-claimed');
      expect(
        freeze['knownLimitation'],
        'minimal-coverage-two-authoring-one-holdout',
      );
    });
  });
}

Map<String, String> _readFreeze() {
  final result = <String, String>{};
  for (final line in File(
    'freezes/dataset_freeze_kds_001.txt',
  ).readAsLinesSync()) {
    final separator = line.indexOf('=');
    if (separator <= 0 || separator == line.length - 1) {
      throw FormatException('Invalid freeze record line.');
    }
    final key = line.substring(0, separator);
    final value = line.substring(separator + 1);
    if (result.containsKey(key)) {
      throw FormatException('Duplicate freeze record key: $key');
    }
    result[key] = value;
  }
  return Map.unmodifiable(result);
}

Future<String> _sha256Of(String path) async {
  return sha256.convert(await File(path).readAsBytes()).toString();
}
