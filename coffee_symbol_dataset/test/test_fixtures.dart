import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';

const _profileChecksum =
    'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7';

final class SyntheticBundle {
  const SyntheticBundle({
    required this.manifest,
    required this.records,
    required this.definition,
    required this.binding,
  });

  final Map<String, Object?> manifest;
  final List<Map<String, Object?>> records;
  final Map<String, Object?> definition;
  final Map<String, Object?>? binding;

  Uint8List get manifestBytes => _bytes(manifest);

  List<Uint8List> get recordBytes =>
      records.map(_bytes).toList(growable: false);
}

SyntheticBundle syntheticBundle({bool includeBinding = true}) {
  const canonicalizer = AtlasCanonicalJson();
  final definition = <String, Object?>{
    'schemaVersion': '1.0',
    'recordType': 'atlas.symbolDefinition',
    'symbolId': 'test-symbol-001',
    'revision': 1,
    'canonicalJsonProfileRef': profileMap(),
    'preferredNames': [
      {
        'language': 'en',
        'value': 'Test symbol',
        'sourceRefs': [
          {'sourceId': 'test-source-001', 'revision': 1},
        ],
      },
    ],
    'aliases': <Object?>[],
    'neutralDefinitions': [
      {
        'language': 'en',
        'value': 'A synthetic neutral symbol definition.',
        'sourceRefs': [
          {
            'sourceId': 'test-source-001',
            'revision': 1,
            'locator': 'test-section-001',
          },
        ],
      },
    ],
  };
  final definitionChecksum = canonicalizer
      .canonicalizeValue(definition)
      .checksum;

  final binding = includeBinding
      ? <String, Object?>{
          'schemaVersion': '1.0',
          'recordType': 'atlas.symbolEvidenceBinding',
          'bindingId': 'test-binding-001',
          'revision': 1,
          'canonicalJsonProfileRef': profileMap(),
          'symbolRef': {
            'symbolId': 'test-symbol-001',
            'revision': 1,
            'checksum': definitionChecksum,
          },
          'knowledgeTargetRef': {
            'knowledgeReleaseId': 'test-kds-001',
            'knowledgeReleaseChecksum': checksum('1'),
            'knowledgeRecordId': 'test-record-001',
          },
          'sourceRefs': <Object?>[],
          'evidenceAssessmentRefs': [
            {
              'assessmentId': 'test-assessment-001',
              'revision': 1,
              'assessmentType': 'holdoutValidation',
              'checksum': checksum('2'),
            },
          ],
        }
      : null;
  final bindingChecksum = binding == null
      ? null
      : canonicalizer.canonicalizeValue(binding).checksum;

  final recordRefs = <Map<String, Object?>>[
    {
      'recordType': 'atlas.symbolDefinition',
      'recordId': 'test-symbol-001',
      'revision': 1,
      'checksum': definitionChecksum,
    },
    if (bindingChecksum != null)
      {
        'recordType': 'atlas.symbolEvidenceBinding',
        'recordId': 'test-binding-001',
        'revision': 1,
        'checksum': bindingChecksum,
      },
  ];
  final manifestPayload = <String, Object?>{
    'schemaVersion': '1.0',
    'recordType': 'atlas.symbolReleaseManifest',
    'releaseId': 'test-symbol-release-001',
    'createdAtUtc': '2026-08-04T00:00:00Z',
    'canonicalJsonProfileRef': profileMap(),
    'governanceSnapshotRef': {
      'snapshotId': 'test-governance-001',
      'checksum': checksum('3'),
    },
    'records': recordRefs,
    'sourceCatalogReleaseRef': {
      'releaseId': 'test-source-release-001',
      'checksum': checksum('4'),
    },
    'symbolAdmissionPolicyRef': {
      'policyId': 'test-symbol-policy-001',
      'revision': 1,
      'checksum': checksum('5'),
    },
    'evidenceAdmissionPolicyRef': {
      'policyId': 'test-evidence-policy-001',
      'revision': 1,
      'checksum': checksum('6'),
    },
    'evidenceAssessmentRegistryReleaseRef': {
      'releaseId': 'test-assessment-release-001',
      'checksum': checksum('7'),
    },
    'knowledgeDatasetReleaseRefs': [
      {'releaseId': 'test-kds-001', 'checksum': checksum('1')},
    ],
  };
  final manifest = <String, Object?>{
    ...manifestPayload,
    'manifestChecksum': canonicalizer
        .canonicalizeValue(manifestPayload)
        .checksum,
  };
  return SyntheticBundle(
    manifest: manifest,
    records: [definition, if (binding != null) binding],
    definition: definition,
    binding: binding,
  );
}

SyntheticBundle syntheticV2Bundle({bool includeBinding = true}) {
  final base = syntheticBundle(includeBinding: includeBinding);
  final manifest = deepCopy(base.manifest)..['schemaVersion'] = '2.0';
  if (!includeBinding) {
    manifest
      ..remove('evidenceAdmissionPolicyRef')
      ..remove('evidenceAssessmentRegistryReleaseRef')
      ..remove('knowledgeDatasetReleaseRefs');
  }
  return SyntheticBundle(
    manifest: rechecksumManifest(manifest),
    records: base.records.map(deepCopy).toList(growable: false),
    definition: deepCopy(base.definition),
    binding: base.binding == null ? null : deepCopy(base.binding!),
  );
}

Map<String, Object?> profileMap() => <String, Object?>{
  'profileId': 'atlas-canonical-json',
  'revision': 1,
  'checksum': _profileChecksum,
};

String checksum(String digit) =>
    'sha256:${List<String>.filled(64, digit).join()}';

SyntheticBundle rebuildBundle({
  required Map<String, Object?> manifest,
  required Map<String, Object?> definition,
  Map<String, Object?>? binding,
}) {
  const canonicalizer = AtlasCanonicalJson();
  final definitionCopy = deepCopy(definition);
  final definitionChecksum = canonicalizer
      .canonicalizeValue(definitionCopy)
      .checksum;
  final bindingCopy = binding == null ? null : deepCopy(binding);
  if (bindingCopy != null) {
    final symbolRef = Map<String, Object?>.from(
      bindingCopy['symbolRef']! as Map,
    );
    symbolRef['checksum'] = definitionChecksum;
    bindingCopy['symbolRef'] = symbolRef;
  }
  final records = <Map<String, Object?>>[
    definitionCopy,
    if (bindingCopy != null) bindingCopy,
  ];
  final recordRefs = <Map<String, Object?>>[
    {
      'recordType': 'atlas.symbolDefinition',
      'recordId': definitionCopy['symbolId'],
      'revision': definitionCopy['revision'],
      'checksum': definitionChecksum,
    },
    if (bindingCopy != null)
      {
        'recordType': 'atlas.symbolEvidenceBinding',
        'recordId': bindingCopy['bindingId'],
        'revision': bindingCopy['revision'],
        'checksum': canonicalizer.canonicalizeValue(bindingCopy).checksum,
      },
  ];
  final manifestCopy = deepCopy(manifest);
  manifestCopy['records'] = recordRefs;
  return SyntheticBundle(
    manifest: rechecksumManifest(manifestCopy),
    records: records,
    definition: definitionCopy,
    binding: bindingCopy,
  );
}

Map<String, Object?> rechecksumManifest(Map<String, Object?> manifest) {
  final payload = deepCopy(manifest)..remove('manifestChecksum');
  return <String, Object?>{
    ...payload,
    'manifestChecksum': const AtlasCanonicalJson()
        .canonicalizeValue(payload)
        .checksum,
  };
}

Map<String, Object?> deepCopy(Map<String, Object?> source) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(source)) as Map);

Uint8List bytesFor(Map<String, Object?> source) => _bytes(source);

Uint8List _bytes(Map<String, Object?> source) => Uint8List.fromList(
  const AtlasCanonicalJson().canonicalizeValue(source).canonicalBytes,
);
