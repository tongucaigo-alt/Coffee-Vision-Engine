import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  group('Symbol dataset JSON Schemas', () {
    test('all schemas are self-contained Draft 2020-12 documents', () {
      for (final path in _schemaPaths) {
        final source = jsonDecode(File(path).readAsStringSync());
        expect(source, isA<Map<Object?, Object?>>(), reason: path);
        final object = source! as Map<Object?, Object?>;
        expect(
          object[r'$schema'],
          'https://json-schema.org/draft/2020-12/schema',
          reason: path,
        );
        expect(
          () => JsonSchema.create(
            object,
            schemaVersion: SchemaVersion.draft2020_12,
          ),
          returnsNormally,
          reason: path,
        );
      }
    });

    test('synthetic Definition validates independently', () {
      final bundle = syntheticBundle();
      final schema = _schema(_schemaPaths[0]);

      expect(schema.validate(bundle.definition).isValid, isTrue);
    });

    test('synthetic Binding validates independently', () {
      final bundle = syntheticBundle();
      final schema = _schema(_schemaPaths[1]);

      expect(schema.validate(bundle.binding).isValid, isTrue);
    });

    test('synthetic manifest validates independently', () {
      final bundle = syntheticBundle();
      final schema = _schema(_schemaPaths[2]);

      expect(schema.validate(bundle.manifest).isValid, isTrue);
    });

    test(
      'version 2 definition-only manifest validates without physical refs',
      () {
        final bundle = syntheticV2Bundle(includeBinding: false);

        expect(
          _schema(_schemaPaths[3]).validate(bundle.manifest).isValid,
          isTrue,
        );
        expect(
          _schema(_schemaPaths[2]).validate(bundle.manifest).isValid,
          isFalse,
        );
      },
    );

    test('version 2 binding manifest requires the complete physical set', () {
      final bundle = syntheticV2Bundle();
      final schema = _schema(_schemaPaths[3]);

      expect(schema.validate(bundle.manifest).isValid, isTrue);
      for (final field in [
        'evidenceAdmissionPolicyRef',
        'evidenceAssessmentRegistryReleaseRef',
        'knowledgeDatasetReleaseRefs',
      ]) {
        final manifest = deepCopy(bundle.manifest)..remove(field);
        expect(schema.validate(manifest).isValid, isFalse, reason: field);
      }
    });

    test('version 2 definition-only manifest forbids every physical field', () {
      final bundle = syntheticV2Bundle(includeBinding: false);
      final physicalValues = syntheticBundle().manifest;
      final schema = _schema(_schemaPaths[3]);

      for (final field in [
        'evidenceAdmissionPolicyRef',
        'evidenceAssessmentRegistryReleaseRef',
        'knowledgeDatasetReleaseRefs',
      ]) {
        final manifest = deepCopy(bundle.manifest)
          ..[field] = physicalValues[field];
        expect(schema.validate(manifest).isValid, isFalse, reason: field);
      }
    });

    test('schemas reject unknown semantic and activation fields', () {
      final bundle = syntheticBundle();
      final definition = deepCopy(bundle.definition)..['meaning'] = 'forbidden';
      final binding = deepCopy(bundle.binding!)..['enabled'] = true;
      final manifest = deepCopy(bundle.manifest)..['rankingPolicy'] = 'none';

      expect(_schema(_schemaPaths[0]).validate(definition).isValid, isFalse);
      expect(_schema(_schemaPaths[1]).validate(binding).isValid, isFalse);
      expect(_schema(_schemaPaths[2]).validate(manifest).isValid, isFalse);
    });

    test(
      'manifest schema requires one Definition and one Knowledge release',
      () {
        final bundle = syntheticBundle();
        final manifest = deepCopy(bundle.manifest)
          ..['records'] = <Object?>[]
          ..['knowledgeDatasetReleaseRefs'] = <Object?>[];

        expect(_schema(_schemaPaths[2]).validate(manifest).isValid, isFalse);
      },
    );
  });
}

const _schemaPaths = [
  'schemas/symbol_definition.schema.json',
  'schemas/symbol_evidence_binding.schema.json',
  'schemas/symbol_release_manifest.schema.json',
  'schemas/symbol_release_manifest_v2.schema.json',
];

JsonSchema _schema(String path) => JsonSchema.create(
  jsonDecode(File(path).readAsStringSync())! as Map<Object?, Object?>,
  schemaVersion: SchemaVersion.draft2020_12,
);
