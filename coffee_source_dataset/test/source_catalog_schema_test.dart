import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  group('Source Catalog JSON Schemas', () {
    test('are self-contained Draft 2020-12 schemas', () {
      for (final path in _schemaPaths) {
        final source = jsonDecode(File(path).readAsStringSync())! as Map;
        expect(
          source[r'$schema'],
          'https://json-schema.org/draft/2020-12/schema',
          reason: path,
        );
        expect(
          () => JsonSchema.create(
            source.cast<Object?, Object?>(),
            schemaVersion: SchemaVersion.draft2020_12,
          ),
          returnsNormally,
          reason: path,
        );
      }
    });

    test('accepts the complete synthetic release documents', () {
      final bundle = syntheticBundle();

      expect(
        _schema(_schemaPaths[0]).validate(bundle.sourceRecord).isValid,
        isTrue,
      );
      expect(
        _schema(_schemaPaths[1]).validate(bundle.useAssessment).isValid,
        isTrue,
      );
      expect(
        _schema(_schemaPaths[2]).validate(bundle.manifest).isValid,
        isTrue,
      );
    });

    test('rejects unknown fields and missing required fields', () {
      final source = syntheticSourceRecord()..['enabled'] = true;
      final assessment = syntheticUseAssessment()..remove('targetRef');
      final manifest = deepCopy(syntheticBundle().manifest)..['ranking'] = 1;

      expect(_schema(_schemaPaths[0]).validate(source).isValid, isFalse);
      expect(_schema(_schemaPaths[1]).validate(assessment).isValid, isFalse);
      expect(_schema(_schemaPaths[2]).validate(manifest).isValid, isFalse);
    });

    test('mirrors rights and mutable-access invariants', () {
      final licensed = syntheticSourceRecord();
      licensed['rights'] = {'rightsStatus': 'licensed'};
      final onlineMutable = syntheticSourceRecord();
      onlineMutable['access'] = {'accessMode': 'online'};
      onlineMutable['integrity'] = {'manifestationType': 'uncapturedMutable'};
      final captured = syntheticSourceRecord();
      captured['integrity'] = {'manifestationType': 'capturedMutable'};

      expect(_schema(_schemaPaths[0]).validate(licensed).isValid, isFalse);
      expect(_schema(_schemaPaths[0]).validate(onlineMutable).isValid, isFalse);
      expect(_schema(_schemaPaths[0]).validate(captured).isValid, isFalse);
    });

    test('requires non-empty Source and assessment membership', () {
      final manifest = deepCopy(syntheticBundle().manifest)
        ..['sourceRecords'] = <Object?>[]
        ..['useAssessments'] = <Object?>[];

      expect(_schema(_schemaPaths[2]).validate(manifest).isValid, isFalse);
    });
  });
}

const _schemaPaths = [
  'schemas/source_record.schema.json',
  'schemas/source_use_assessment.schema.json',
  'schemas/source_catalog_release_manifest.schema.json',
];

JsonSchema _schema(String path) => JsonSchema.create(
  (jsonDecode(File(path).readAsStringSync())! as Map).cast<Object?, Object?>(),
  schemaVersion: SchemaVersion.draft2020_12,
);
