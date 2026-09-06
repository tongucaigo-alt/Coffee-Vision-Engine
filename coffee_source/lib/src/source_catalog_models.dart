import 'package:coffee_symbol/coffee_symbol.dart';

import 'source_validation.dart';

final class GovernanceSnapshotRef {
  GovernanceSnapshotRef({required String snapshotId, required String checksum})
    : snapshotId = validateIdentifier(snapshotId, 'snapshotId'),
      checksum = validateChecksum(checksum, 'checksum');

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
}

final class ContextRegistryReleaseRef {
  ContextRegistryReleaseRef({
    required String releaseId,
    required String checksum,
  }) : releaseId = validateIdentifier(releaseId, 'releaseId'),
       checksum = validateChecksum(checksum, 'checksum');

  final String releaseId;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextRegistryReleaseRef &&
          other.releaseId == releaseId &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(releaseId, checksum);
}

final class SourceRecordReleaseRef {
  SourceRecordReleaseRef({
    required String sourceId,
    required int revision,
    required String checksum,
  }) : sourceId = validateIdentifier(sourceId, 'sourceId'),
       revision = _validateRevision(revision),
       checksum = validateChecksum(checksum, 'checksum');

  final String sourceId;
  final int revision;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceRecordReleaseRef &&
          other.sourceId == sourceId &&
          other.revision == revision &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(sourceId, revision, checksum);
}

final class SourceUseAssessmentReleaseRef {
  SourceUseAssessmentReleaseRef({
    required String useAssessmentId,
    required int revision,
    required String checksum,
  }) : useAssessmentId = validateIdentifier(useAssessmentId, 'useAssessmentId'),
       revision = _validateRevision(revision),
       checksum = validateChecksum(checksum, 'checksum');

  final String useAssessmentId;
  final int revision;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceUseAssessmentReleaseRef &&
          other.useAssessmentId == useAssessmentId &&
          other.revision == revision &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(useAssessmentId, revision, checksum);
}

final class SourceCatalogReleaseManifest {
  factory SourceCatalogReleaseManifest({
    required String schemaVersion,
    required String releaseId,
    required String createdAtUtc,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required GovernanceSnapshotRef governanceSnapshotRef,
    required ContextRegistryReleaseRef contextRegistryReleaseRef,
    required Iterable<SourceRecordReleaseRef> sourceRecords,
    required Iterable<SourceUseAssessmentReleaseRef> useAssessments,
    required String manifestChecksum,
  }) {
    if (schemaVersion != '1.0') {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', 'must be 1.0');
    }
    final records = sourceRecords.toList(growable: false)
      ..sort(_compareRecords);
    final assessments = useAssessments.toList(growable: false)
      ..sort(_compareAssessments);
    if (records.isEmpty || assessments.isEmpty) {
      throw ArgumentError(
        'Source Catalog releases require source records and assessments.',
      );
    }
    _rejectDuplicateRecords(records);
    _rejectDuplicateAssessments(assessments);
    return SourceCatalogReleaseManifest._(
      schemaVersion: schemaVersion,
      releaseId: validateIdentifier(releaseId, 'releaseId'),
      createdAtUtc: validateUtcTimestamp(createdAtUtc, 'createdAtUtc'),
      canonicalJsonProfileRef: canonicalJsonProfileRef,
      governanceSnapshotRef: governanceSnapshotRef,
      contextRegistryReleaseRef: contextRegistryReleaseRef,
      sourceRecords: List<SourceRecordReleaseRef>.unmodifiable(records),
      useAssessments: List<SourceUseAssessmentReleaseRef>.unmodifiable(
        assessments,
      ),
      manifestChecksum: validateChecksum(manifestChecksum, 'manifestChecksum'),
    );
  }

  const SourceCatalogReleaseManifest._({
    required this.schemaVersion,
    required this.releaseId,
    required this.createdAtUtc,
    required this.canonicalJsonProfileRef,
    required this.governanceSnapshotRef,
    required this.contextRegistryReleaseRef,
    required this.sourceRecords,
    required this.useAssessments,
    required this.manifestChecksum,
  });

  static const String recordType = 'atlas.sourceCatalogReleaseManifest';

  final String schemaVersion;
  final String releaseId;
  final String createdAtUtc;
  final CanonicalJsonProfileRef canonicalJsonProfileRef;
  final GovernanceSnapshotRef governanceSnapshotRef;
  final ContextRegistryReleaseRef contextRegistryReleaseRef;
  final List<SourceRecordReleaseRef> sourceRecords;
  final List<SourceUseAssessmentReleaseRef> useAssessments;
  final String manifestChecksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceCatalogReleaseManifest &&
          other.schemaVersion == schemaVersion &&
          other.releaseId == releaseId &&
          other.createdAtUtc == createdAtUtc &&
          other.canonicalJsonProfileRef == canonicalJsonProfileRef &&
          other.governanceSnapshotRef == governanceSnapshotRef &&
          other.contextRegistryReleaseRef == contextRegistryReleaseRef &&
          sameList(other.sourceRecords, sourceRecords) &&
          sameList(other.useAssessments, useAssessments) &&
          other.manifestChecksum == manifestChecksum;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    releaseId,
    createdAtUtc,
    canonicalJsonProfileRef,
    governanceSnapshotRef,
    contextRegistryReleaseRef,
    Object.hashAll(sourceRecords),
    Object.hashAll(useAssessments),
    manifestChecksum,
  );

  @override
  String toString() =>
      'SourceCatalogReleaseManifest(releaseId: $releaseId, '
      'sourceRecordCount: ${sourceRecords.length}, '
      'assessmentCount: ${useAssessments.length})';

  static int _compareRecords(
    SourceRecordReleaseRef first,
    SourceRecordReleaseRef second,
  ) {
    final id = first.sourceId.compareTo(second.sourceId);
    return id != 0 ? id : first.revision.compareTo(second.revision);
  }

  static int _compareAssessments(
    SourceUseAssessmentReleaseRef first,
    SourceUseAssessmentReleaseRef second,
  ) {
    final id = first.useAssessmentId.compareTo(second.useAssessmentId);
    return id != 0 ? id : first.revision.compareTo(second.revision);
  }

  static void _rejectDuplicateRecords(List<SourceRecordReleaseRef> values) {
    for (var index = 1; index < values.length; index++) {
      final first = values[index - 1];
      final second = values[index];
      if (first.sourceId == second.sourceId &&
          first.revision == second.revision) {
        throw ArgumentError.value(
          values,
          'sourceRecords',
          'duplicate identity',
        );
      }
    }
  }

  static void _rejectDuplicateAssessments(
    List<SourceUseAssessmentReleaseRef> values,
  ) {
    for (var index = 1; index < values.length; index++) {
      final first = values[index - 1];
      final second = values[index];
      if (first.useAssessmentId == second.useAssessmentId &&
          first.revision == second.revision) {
        throw ArgumentError.value(
          values,
          'useAssessments',
          'duplicate identity',
        );
      }
    }
  }
}

int _validateRevision(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'revision', 'must be greater than zero');
  }
  return value;
}
