import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';

const canonicalProfile = <String, Object?>{
  'profileId': 'atlas-canonical-json',
  'revision': 1,
  'checksum':
      'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7',
};

final class SyntheticSourceBundle {
  const SyntheticSourceBundle({
    required this.sourceRecord,
    required this.useAssessment,
    required this.manifest,
  });

  final Map<String, Object?> sourceRecord;
  final Map<String, Object?> useAssessment;
  final Map<String, Object?> manifest;

  Uint8List get manifestBytes => bytesFor(manifest);

  List<Uint8List> get recordBytes => [
    bytesFor(sourceRecord),
    bytesFor(useAssessment),
  ];
}

SyntheticSourceBundle syntheticBundle({
  Map<String, Object?>? sourceRecord,
  Map<String, Object?>? useAssessment,
}) {
  final source = sourceRecord ?? syntheticSourceRecord();
  final assessment = useAssessment ?? syntheticUseAssessment();
  final manifest = <String, Object?>{
    'schemaVersion': '1.0',
    'recordType': 'atlas.sourceCatalogReleaseManifest',
    'releaseId': 'test-source-catalog-001',
    'createdAtUtc': '2026-09-05T00:00:00Z',
    'canonicalJsonProfileRef': deepCopy(canonicalProfile),
    'governanceSnapshotRef': {
      'snapshotId': 'test-governance-001',
      'checksum': checksumForSeed('a'),
    },
    'contextRegistryReleaseRef': {
      'releaseId': 'test-context-release-001',
      'checksum': checksumForSeed('c'),
    },
    'sourceRecords': [
      {
        'sourceId': source['sourceId'],
        'revision': source['revision'],
        'checksum': checksumFor(source),
      },
    ],
    'useAssessments': [
      {
        'useAssessmentId': assessment['useAssessmentId'],
        'revision': assessment['revision'],
        'checksum': checksumFor(assessment),
      },
    ],
  };
  return SyntheticSourceBundle(
    sourceRecord: source,
    useAssessment: assessment,
    manifest: rechecksumManifest(manifest),
  );
}

Map<String, Object?> syntheticSourceRecord() => <String, Object?>{
  'schemaVersion': '1.0',
  'recordType': 'atlas.sourceRecord',
  'sourceId': 'test-source-001',
  'revision': 1,
  'canonicalJsonProfileRef': deepCopy(canonicalProfile),
  'sourceClass': 'monographOrBook',
  'title': 'Synthetic fixed source',
  'creators': [
    {'agentType': 'person', 'displayName': 'Test Author', 'role': 'author'},
  ],
  'publication': {
    'publicationDate': '2026',
    'publisher': 'Test Publisher',
    'edition': 'First edition',
    'pages': '16',
  },
  'languages': {'consultedLanguage': 'en'},
  'identifiers': [
    {'identifierType': 'isbn', 'value': '9780000000000'},
    {'identifierType': 'url', 'value': 'https://example.invalid/source'},
  ],
  'access': {'accessMode': 'physical'},
  'rights': {'rightsStatus': 'citationOnly'},
  'culturalCoverage': {
    'contextIds': ['test-context-001'],
    'basis': 'sourceDeclared',
  },
  'integrity': {'manifestationType': 'fixedEdition'},
};

Map<String, Object?> syntheticUseAssessment() => <String, Object?>{
  'schemaVersion': '1.0',
  'recordType': 'atlas.sourceUseAssessment',
  'useAssessmentId': 'test-use-001',
  'revision': 1,
  'canonicalJsonProfileRef': deepCopy(canonicalProfile),
  'targetRef': {
    'recordType': 'atlas.symbolDefinition',
    'recordId': 'test-symbol-001',
    'revision': 1,
    'checksum': checksumForSeed('b'),
    'targetPath': '/preferredNames/0',
  },
  'sourceRef': {
    'sourceId': 'test-source-001',
    'revision': 1,
    'locator': 'p. 16',
  },
  'evidenceRole': 'primary',
  'supportRelation': 'supports',
  'independenceGroupId': 'test-family-001',
  'independenceRationale': 'Independent synthetic source family.',
  'qualityDimensions': {
    'provenance': 'verified',
    'attribution': 'identified',
    'editorialControl': 'professionalEditorial',
    'methodTransparency': 'partial',
    'sourceStability': 'fixedEdition',
    'culturalProximity': 'recognizedSpecialist',
  },
  'assessmentOutcome': 'eligibleCore',
  'limitations': ['Synthetic fixture only.'],
  'rationale': 'Source directly supports the literal test field.',
};

Map<String, Object?> rechecksumManifest(Map<String, Object?> input) {
  final result = deepCopy(input)..remove('manifestChecksum');
  result['manifestChecksum'] = checksumFor(result);
  return result;
}

String checksumFor(Object? value) =>
    const AtlasCanonicalJson().canonicalizeValue(value).checksum;

String checksumForSeed(String seed) => 'sha256:${seed.padRight(64, seed)}';

Uint8List bytesFor(Object? value, {bool pretty = false}) => Uint8List.fromList(
  utf8.encode(
    pretty
        ? const JsonEncoder.withIndent('  ').convert(value)
        : jsonEncode(value),
  ),
);

Map<String, Object?> deepCopy(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value))! as Map).cast<String, Object?>();

Map<String, Object?> reverseRootProperties(Map<String, Object?> value) =>
    Map<String, Object?>.fromEntries(value.entries.toList().reversed);
