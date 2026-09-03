import 'package:coffee_symbol/coffee_symbol.dart';

final RegExp _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
final RegExp _checksumPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _utcTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?Z$',
);

/// Symbol record types supported by the first dataset adapter.
enum SymbolDatasetRecordType {
  symbolDefinition('atlas.symbolDefinition'),
  symbolEvidenceBinding('atlas.symbolEvidenceBinding');

  const SymbolDatasetRecordType(this.wireName);

  final String wireName;
}

/// Exact immutable identity of one frozen Symbol release.
final class SymbolReleaseRef {
  SymbolReleaseRef({required String releaseId, required String checksum})
    : releaseId = _identifier(releaseId, 'releaseId'),
      checksum = _checksum(checksum, 'checksum');

  final String releaseId;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymbolReleaseRef &&
          other.releaseId == releaseId &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(releaseId, checksum);

  @override
  String toString() =>
      'SymbolReleaseRef(releaseId: $releaseId, checksum: $checksum)';
}

/// Exact immutable Governance snapshot dependency.
final class GovernanceSnapshotRef {
  GovernanceSnapshotRef({required String snapshotId, required String checksum})
    : snapshotId = _identifier(snapshotId, 'snapshotId'),
      checksum = _checksum(checksum, 'checksum');

  final String snapshotId;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GovernanceSnapshotRef &&
          other.snapshotId == snapshotId &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(snapshotId, checksum);

  @override
  String toString() =>
      'GovernanceSnapshotRef(snapshotId: $snapshotId, checksum: $checksum)';
}

/// Exact immutable Source Catalog release dependency.
final class SourceCatalogReleaseRef {
  SourceCatalogReleaseRef({required String releaseId, required String checksum})
    : releaseId = _identifier(releaseId, 'releaseId'),
      checksum = _checksum(checksum, 'checksum');

  final String releaseId;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceCatalogReleaseRef &&
          other.releaseId == releaseId &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(releaseId, checksum);

  @override
  String toString() =>
      'SourceCatalogReleaseRef(releaseId: $releaseId, checksum: $checksum)';
}

/// Exact immutable bibliographic Symbol admission policy dependency.
final class SymbolAdmissionPolicyRef {
  SymbolAdmissionPolicyRef({
    required String policyId,
    required int revision,
    required String checksum,
  }) : policyId = _identifier(policyId, 'policyId'),
       revision = _revision(revision, 'revision'),
       checksum = _checksum(checksum, 'checksum');

  final String policyId;
  final int revision;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymbolAdmissionPolicyRef &&
          other.policyId == policyId &&
          other.revision == revision &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(policyId, revision, checksum);

  @override
  String toString() =>
      'SymbolAdmissionPolicyRef(policyId: $policyId, revision: $revision, '
      'checksum: $checksum)';
}

/// Exact immutable physical evidence admission policy dependency.
final class EvidenceAdmissionPolicyRef {
  EvidenceAdmissionPolicyRef({
    required String policyId,
    required int revision,
    required String checksum,
  }) : policyId = _identifier(policyId, 'policyId'),
       revision = _revision(revision, 'revision'),
       checksum = _checksum(checksum, 'checksum');

  final String policyId;
  final int revision;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceAdmissionPolicyRef &&
          other.policyId == policyId &&
          other.revision == revision &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(policyId, revision, checksum);

  @override
  String toString() =>
      'EvidenceAdmissionPolicyRef(policyId: $policyId, revision: $revision, '
      'checksum: $checksum)';
}

/// Exact immutable Evidence Assessment Registry release dependency.
final class EvidenceAssessmentRegistryReleaseRef {
  EvidenceAssessmentRegistryReleaseRef({
    required String releaseId,
    required String checksum,
  }) : releaseId = _identifier(releaseId, 'releaseId'),
       checksum = _checksum(checksum, 'checksum');

  final String releaseId;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceAssessmentRegistryReleaseRef &&
          other.releaseId == releaseId &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(releaseId, checksum);

  @override
  String toString() =>
      'EvidenceAssessmentRegistryReleaseRef(releaseId: $releaseId, '
      'checksum: $checksum)';
}

/// Exact record membership entry in a frozen Symbol release.
final class SymbolReleaseRecordRef {
  SymbolReleaseRecordRef({
    required this.recordType,
    required String recordId,
    required int revision,
    required String checksum,
  }) : recordId = _identifier(recordId, 'recordId'),
       revision = _revision(revision, 'revision'),
       checksum = _checksum(checksum, 'checksum');

  final SymbolDatasetRecordType recordType;
  final String recordId;
  final int revision;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymbolReleaseRecordRef &&
          other.recordType == recordType &&
          other.recordId == recordId &&
          other.revision == revision &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(recordType, recordId, revision, checksum);

  @override
  String toString() {
    return 'SymbolReleaseRecordRef(recordType: ${recordType.wireName}, '
        'recordId: $recordId, revision: $revision, checksum: $checksum)';
  }
}

/// Immutable complete manifest for the supported Symbol release subset.
final class SymbolReleaseManifest {
  factory SymbolReleaseManifest({
    required String schemaVersion,
    required String releaseId,
    required String createdAtUtc,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required GovernanceSnapshotRef governanceSnapshotRef,
    required Iterable<SymbolReleaseRecordRef> records,
    required SourceCatalogReleaseRef sourceCatalogReleaseRef,
    required SymbolAdmissionPolicyRef symbolAdmissionPolicyRef,
    required EvidenceAdmissionPolicyRef evidenceAdmissionPolicyRef,
    required EvidenceAssessmentRegistryReleaseRef
    evidenceAssessmentRegistryReleaseRef,
    required Iterable<KnowledgeDatasetReleaseRef> knowledgeDatasetReleaseRefs,
    required String manifestChecksum,
  }) => _create(
    schemaVersion: schemaVersion,
    releaseId: releaseId,
    createdAtUtc: createdAtUtc,
    canonicalJsonProfileRef: canonicalJsonProfileRef,
    governanceSnapshotRef: governanceSnapshotRef,
    records: records,
    sourceCatalogReleaseRef: sourceCatalogReleaseRef,
    symbolAdmissionPolicyRef: symbolAdmissionPolicyRef,
    evidenceAdmissionPolicyRef: evidenceAdmissionPolicyRef,
    evidenceAssessmentRegistryReleaseRef: evidenceAssessmentRegistryReleaseRef,
    knowledgeDatasetReleaseRefs: knowledgeDatasetReleaseRefs,
    manifestChecksum: manifestChecksum,
    conditionalPhysicalDependencies: false,
  );

  /// Creates a version 2 manifest with binding-conditional physical refs.
  factory SymbolReleaseManifest.v2({
    required String schemaVersion,
    required String releaseId,
    required String createdAtUtc,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required GovernanceSnapshotRef governanceSnapshotRef,
    required Iterable<SymbolReleaseRecordRef> records,
    required SourceCatalogReleaseRef sourceCatalogReleaseRef,
    required SymbolAdmissionPolicyRef symbolAdmissionPolicyRef,
    EvidenceAdmissionPolicyRef? evidenceAdmissionPolicyRef,
    EvidenceAssessmentRegistryReleaseRef? evidenceAssessmentRegistryReleaseRef,
    Iterable<KnowledgeDatasetReleaseRef> knowledgeDatasetReleaseRefs =
        const <KnowledgeDatasetReleaseRef>[],
    required String manifestChecksum,
  }) => _create(
    schemaVersion: schemaVersion,
    releaseId: releaseId,
    createdAtUtc: createdAtUtc,
    canonicalJsonProfileRef: canonicalJsonProfileRef,
    governanceSnapshotRef: governanceSnapshotRef,
    records: records,
    sourceCatalogReleaseRef: sourceCatalogReleaseRef,
    symbolAdmissionPolicyRef: symbolAdmissionPolicyRef,
    evidenceAdmissionPolicyRef: evidenceAdmissionPolicyRef,
    evidenceAssessmentRegistryReleaseRef: evidenceAssessmentRegistryReleaseRef,
    knowledgeDatasetReleaseRefs: knowledgeDatasetReleaseRefs,
    manifestChecksum: manifestChecksum,
    conditionalPhysicalDependencies: true,
  );

  static SymbolReleaseManifest _create({
    required String schemaVersion,
    required String releaseId,
    required String createdAtUtc,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required GovernanceSnapshotRef governanceSnapshotRef,
    required Iterable<SymbolReleaseRecordRef> records,
    required SourceCatalogReleaseRef sourceCatalogReleaseRef,
    required SymbolAdmissionPolicyRef symbolAdmissionPolicyRef,
    required EvidenceAdmissionPolicyRef? evidenceAdmissionPolicyRef,
    required EvidenceAssessmentRegistryReleaseRef?
    evidenceAssessmentRegistryReleaseRef,
    required Iterable<KnowledgeDatasetReleaseRef> knowledgeDatasetReleaseRefs,
    required String manifestChecksum,
    required bool conditionalPhysicalDependencies,
  }) {
    final expectedVersion = conditionalPhysicalDependencies ? '2.0' : '1.0';
    if (schemaVersion != expectedVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    final canonicalRecords = records.toList(growable: false)
      ..sort(compareRecordRefs);
    if (canonicalRecords.isEmpty ||
        !canonicalRecords.any(
          (record) =>
              record.recordType == SymbolDatasetRecordType.symbolDefinition,
        )) {
      throw ArgumentError.value(
        records,
        'records',
        'must contain at least one SymbolDefinition',
      );
    }
    _rejectDuplicateRecords(canonicalRecords);
    final hasBindings = canonicalRecords.any(
      (record) =>
          record.recordType == SymbolDatasetRecordType.symbolEvidenceBinding,
    );
    final knowledgeReleases = knowledgeDatasetReleaseRefs.toList(
      growable: false,
    );
    final requiresPhysicalDependencies =
        !conditionalPhysicalDependencies || hasBindings;
    if (requiresPhysicalDependencies &&
        (evidenceAdmissionPolicyRef == null ||
            evidenceAssessmentRegistryReleaseRef == null ||
            knowledgeReleases.length != 1)) {
      throw ArgumentError.value(
        knowledgeDatasetReleaseRefs,
        'knowledgeDatasetReleaseRefs',
        'physical dependencies must be complete with exactly one release',
      );
    }
    if (!requiresPhysicalDependencies &&
        (evidenceAdmissionPolicyRef != null ||
            evidenceAssessmentRegistryReleaseRef != null ||
            knowledgeReleases.isNotEmpty)) {
      throw ArgumentError.value(
        knowledgeDatasetReleaseRefs,
        'knowledgeDatasetReleaseRefs',
        'definition-only version 2 manifests must omit physical dependencies',
      );
    }
    return SymbolReleaseManifest._(
      schemaVersion: schemaVersion,
      releaseRef: SymbolReleaseRef(
        releaseId: releaseId,
        checksum: manifestChecksum,
      ),
      createdAtUtc: _utcTimestamp(createdAtUtc),
      canonicalJsonProfileRef: canonicalJsonProfileRef,
      governanceSnapshotRef: governanceSnapshotRef,
      records: List<SymbolReleaseRecordRef>.unmodifiable(canonicalRecords),
      sourceCatalogReleaseRef: sourceCatalogReleaseRef,
      symbolAdmissionPolicyRef: symbolAdmissionPolicyRef,
      evidenceAdmissionPolicyRef: evidenceAdmissionPolicyRef,
      evidenceAssessmentRegistryReleaseRef:
          evidenceAssessmentRegistryReleaseRef,
      knowledgeDatasetReleaseRefs:
          List<KnowledgeDatasetReleaseRef>.unmodifiable(knowledgeReleases),
    );
  }

  const SymbolReleaseManifest._({
    required this.schemaVersion,
    required this.releaseRef,
    required this.createdAtUtc,
    required this.canonicalJsonProfileRef,
    required this.governanceSnapshotRef,
    required this.records,
    required this.sourceCatalogReleaseRef,
    required this.symbolAdmissionPolicyRef,
    required this.evidenceAdmissionPolicyRef,
    required this.evidenceAssessmentRegistryReleaseRef,
    required this.knowledgeDatasetReleaseRefs,
  });

  static const String recordType = 'atlas.symbolReleaseManifest';

  final String schemaVersion;
  final SymbolReleaseRef releaseRef;
  final String createdAtUtc;
  final CanonicalJsonProfileRef canonicalJsonProfileRef;
  final GovernanceSnapshotRef governanceSnapshotRef;
  final List<SymbolReleaseRecordRef> records;
  final SourceCatalogReleaseRef sourceCatalogReleaseRef;
  final SymbolAdmissionPolicyRef symbolAdmissionPolicyRef;
  final EvidenceAdmissionPolicyRef? evidenceAdmissionPolicyRef;
  final EvidenceAssessmentRegistryReleaseRef?
  evidenceAssessmentRegistryReleaseRef;
  final List<KnowledgeDatasetReleaseRef> knowledgeDatasetReleaseRefs;

  bool get hasBindings => records.any(
    (record) =>
        record.recordType == SymbolDatasetRecordType.symbolEvidenceBinding,
  );

  KnowledgeDatasetReleaseRef? get knowledgeRelease =>
      knowledgeDatasetReleaseRefs.isEmpty
      ? null
      : knowledgeDatasetReleaseRefs.single;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymbolReleaseManifest &&
          other.schemaVersion == schemaVersion &&
          other.releaseRef == releaseRef &&
          other.createdAtUtc == createdAtUtc &&
          other.canonicalJsonProfileRef == canonicalJsonProfileRef &&
          other.governanceSnapshotRef == governanceSnapshotRef &&
          _sameList(other.records, records) &&
          other.sourceCatalogReleaseRef == sourceCatalogReleaseRef &&
          other.symbolAdmissionPolicyRef == symbolAdmissionPolicyRef &&
          other.evidenceAdmissionPolicyRef == evidenceAdmissionPolicyRef &&
          other.evidenceAssessmentRegistryReleaseRef ==
              evidenceAssessmentRegistryReleaseRef &&
          _sameList(
            other.knowledgeDatasetReleaseRefs,
            knowledgeDatasetReleaseRefs,
          );

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    releaseRef,
    createdAtUtc,
    canonicalJsonProfileRef,
    governanceSnapshotRef,
    Object.hashAll(records),
    sourceCatalogReleaseRef,
    symbolAdmissionPolicyRef,
    evidenceAdmissionPolicyRef,
    evidenceAssessmentRegistryReleaseRef,
    Object.hashAll(knowledgeDatasetReleaseRefs),
  );

  @override
  String toString() {
    return 'SymbolReleaseManifest(releaseRef: $releaseRef, '
        'recordCount: ${records.length}, hasBindings: $hasBindings)';
  }
}

/// Immutable runtime view of one intrinsically validated Symbol release.
final class SymbolDatasetSnapshot {
  factory SymbolDatasetSnapshot({
    required SymbolReleaseManifest manifest,
    required Iterable<SymbolDefinition> definitions,
    required Iterable<SymbolEvidenceBinding> bindings,
  }) {
    final canonicalDefinitions = definitions.toList(growable: false)
      ..sort(compareDefinitions);
    final canonicalBindings = bindings.toList(growable: false)
      ..sort(compareBindings);
    if (canonicalDefinitions.isEmpty) {
      throw ArgumentError.value(
        definitions,
        'definitions',
        'must not be empty',
      );
    }
    _rejectDuplicateDefinitions(canonicalDefinitions);
    _rejectDuplicateBindings(canonicalBindings);
    return SymbolDatasetSnapshot._(
      manifest: manifest,
      definitions: List<SymbolDefinition>.unmodifiable(canonicalDefinitions),
      bindings: List<SymbolEvidenceBinding>.unmodifiable(canonicalBindings),
    );
  }

  const SymbolDatasetSnapshot._({
    required this.manifest,
    required this.definitions,
    required this.bindings,
  });

  final SymbolReleaseManifest manifest;
  final List<SymbolDefinition> definitions;
  final List<SymbolEvidenceBinding> bindings;

  KnowledgeDatasetReleaseRef? get knowledgeRelease => manifest.knowledgeRelease;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymbolDatasetSnapshot &&
          other.manifest == manifest &&
          _sameList(other.definitions, definitions) &&
          _sameList(other.bindings, bindings);

  @override
  int get hashCode => Object.hash(
    manifest,
    Object.hashAll(definitions),
    Object.hashAll(bindings),
  );

  @override
  String toString() {
    return 'SymbolDatasetSnapshot(releaseId: ${manifest.releaseRef.releaseId}, '
        'definitionCount: ${definitions.length}, '
        'bindingCount: ${bindings.length})';
  }
}

int compareRecordRefs(
  SymbolReleaseRecordRef first,
  SymbolReleaseRecordRef second,
) {
  final type = first.recordType.wireName.compareTo(second.recordType.wireName);
  if (type != 0) return type;
  final id = first.recordId.compareTo(second.recordId);
  if (id != 0) return id;
  return first.revision.compareTo(second.revision);
}

int compareDefinitions(SymbolDefinition first, SymbolDefinition second) {
  final id = first.symbolId.compareTo(second.symbolId);
  if (id != 0) return id;
  return first.revision.compareTo(second.revision);
}

int compareBindings(SymbolEvidenceBinding first, SymbolEvidenceBinding second) {
  final id = first.bindingId.compareTo(second.bindingId);
  if (id != 0) return id;
  return first.revision.compareTo(second.revision);
}

void _rejectDuplicateRecords(List<SymbolReleaseRecordRef> records) {
  for (var index = 1; index < records.length; index++) {
    if (compareRecordRefs(records[index - 1], records[index]) == 0) {
      throw ArgumentError.value(
        records[index],
        'records',
        'must contain unique record identities',
      );
    }
  }
}

void _rejectDuplicateDefinitions(List<SymbolDefinition> definitions) {
  for (var index = 1; index < definitions.length; index++) {
    if (compareDefinitions(definitions[index - 1], definitions[index]) == 0) {
      throw ArgumentError.value(
        definitions[index].symbolRef,
        'definitions',
        'must contain unique symbol revisions',
      );
    }
  }
}

void _rejectDuplicateBindings(List<SymbolEvidenceBinding> bindings) {
  for (var index = 1; index < bindings.length; index++) {
    if (compareBindings(bindings[index - 1], bindings[index]) == 0) {
      throw ArgumentError.value(
        bindings[index].bindingId,
        'bindings',
        'must contain unique binding revisions',
      );
    }
  }
}

String _identifier(String value, String name) {
  if (!_identifierPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'invalid identifier');
  }
  return value;
}

int _revision(int value, String name) {
  if (value <= 0) throw ArgumentError.value(value, name, 'must be positive');
  return value;
}

String _checksum(String value, String name) {
  if (!_checksumPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'invalid checksum');
  }
  return value;
}

String _utcTimestamp(String value) {
  final match = _utcTimestampPattern.firstMatch(value);
  if (match == null) {
    throw ArgumentError.value(value, 'createdAtUtc', 'invalid UTC timestamp');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final daysInMonth = month >= 1 && month <= 12
      ? <int>[
          31,
          _isLeapYear(year) ? 29 : 28,
          31,
          30,
          31,
          30,
          31,
          31,
          30,
          31,
          30,
          31,
        ][month - 1]
      : 0;
  if (year == 0 ||
      day < 1 ||
      day > daysInMonth ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    throw ArgumentError.value(value, 'createdAtUtc', 'invalid UTC timestamp');
  }
  return value;
}

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

bool _sameList<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
