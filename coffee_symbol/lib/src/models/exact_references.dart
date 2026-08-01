import '../validation.dart';

/// Exact identity of the canonical JSON profile used by a frozen record.
final class CanonicalJsonProfileRef {
  CanonicalJsonProfileRef({
    required String profileId,
    required int revision,
    required String checksum,
  }) : profileId = validateIdentifier(profileId, 'profileId'),
       revision = validateRevision(revision, 'revision'),
       checksum = validateChecksum(checksum, 'checksum');

  /// Opaque canonical profile identity.
  final String profileId;

  /// Exact immutable profile revision.
  final int revision;

  /// Canonical SHA-256 of that profile revision.
  final String checksum;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CanonicalJsonProfileRef &&
            other.profileId == profileId &&
            other.revision == revision &&
            other.checksum == checksum;
  }

  @override
  int get hashCode => Object.hash(profileId, revision, checksum);

  @override
  String toString() {
    return 'CanonicalJsonProfileRef(profileId: $profileId, '
        'revision: $revision, checksum: $checksum)';
  }
}

/// Exact identity of one frozen physical Knowledge dataset release.
final class KnowledgeDatasetReleaseRef {
  KnowledgeDatasetReleaseRef({
    required String releaseId,
    required String checksum,
  }) : releaseId = validateIdentifier(releaseId, 'releaseId'),
       checksum = validateChecksum(checksum, 'checksum');

  /// Opaque immutable release identity.
  final String releaseId;

  /// Canonical release SHA-256.
  final String checksum;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeDatasetReleaseRef &&
            other.releaseId == releaseId &&
            other.checksum == checksum;
  }

  @override
  int get hashCode => Object.hash(releaseId, checksum);

  @override
  String toString() {
    return 'KnowledgeDatasetReleaseRef(releaseId: $releaseId, '
        'checksum: $checksum)';
  }
}

/// Small immutable reference to an exact source manifestation.
final class SourceRef {
  SourceRef({required String sourceId, required int revision, String? locator})
    : sourceId = validateIdentifier(sourceId, 'sourceId'),
      revision = validateRevision(revision, 'revision'),
      locator = validateOptionalText(locator, 'locator');

  /// Stable source lineage identity.
  final String sourceId;

  /// Exact consulted manifestation revision.
  final int revision;

  /// Optional location inside the consulted manifestation.
  final String? locator;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SourceRef &&
            other.sourceId == sourceId &&
            other.revision == revision &&
            other.locator == locator;
  }

  @override
  int get hashCode => Object.hash(sourceId, revision, locator);

  @override
  String toString() {
    return 'SourceRef(sourceId: $sourceId, revision: $revision, '
        'locatorPresent: ${locator != null})';
  }
}

/// Exact immutable SymbolDefinition revision identity.
final class SymbolRevisionRef {
  SymbolRevisionRef({
    required String symbolId,
    required int revision,
    required String checksum,
  }) : symbolId = validateIdentifier(symbolId, 'symbolId'),
       revision = validateRevision(revision, 'revision'),
       checksum = validateChecksum(checksum, 'checksum');

  /// Stable symbol identity.
  final String symbolId;

  /// Exact immutable symbol revision.
  final int revision;

  /// Canonical SHA-256 of the referenced definition revision.
  final String checksum;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SymbolRevisionRef &&
            other.symbolId == symbolId &&
            other.revision == revision &&
            other.checksum == checksum;
  }

  @override
  int get hashCode => Object.hash(symbolId, revision, checksum);

  @override
  String toString() {
    return 'SymbolRevisionRef(symbolId: $symbolId, revision: $revision, '
        'checksum: $checksum)';
  }
}

/// Exact frozen KnowledgeRecord target of one Symbol binding.
final class KnowledgeTargetRef {
  KnowledgeTargetRef({
    required KnowledgeDatasetReleaseRef knowledgeRelease,
    required String knowledgeRecordId,
  }) : knowledgeRelease = knowledgeRelease,
       knowledgeRecordId = validateIdentifier(
         knowledgeRecordId,
         'knowledgeRecordId',
       );

  /// Frozen dataset release containing the target record.
  final KnowledgeDatasetReleaseRef knowledgeRelease;

  /// Exact KnowledgeRecord identity inside the frozen release.
  final String knowledgeRecordId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeTargetRef &&
            other.knowledgeRelease == knowledgeRelease &&
            other.knowledgeRecordId == knowledgeRecordId;
  }

  @override
  int get hashCode => Object.hash(knowledgeRelease, knowledgeRecordId);

  @override
  String toString() {
    return 'KnowledgeTargetRef(knowledgeRelease: $knowledgeRelease, '
        'knowledgeRecordId: $knowledgeRecordId)';
  }
}

/// Approved physical evidence assessment categories.
enum EvidenceAssessmentType {
  /// Authoring-cohort physical behavior validation.
  cohortValidation,

  /// Independent holdout physical behavior validation.
  holdoutValidation,

  /// Challenge against a known competing physical formation.
  confoundChallenge,

  /// Expert review of physical observability and confounds.
  expertMorphologyReview,
}

/// Exact immutable reference to one admitted evidence assessment.
final class EvidenceAssessmentRef {
  EvidenceAssessmentRef({
    required String assessmentId,
    required int revision,
    required EvidenceAssessmentType assessmentType,
    required String checksum,
  }) : assessmentId = validateIdentifier(assessmentId, 'assessmentId'),
       revision = validateRevision(revision, 'revision'),
       assessmentType = assessmentType,
       checksum = validateChecksum(checksum, 'checksum');

  /// Stable assessment identity.
  final String assessmentId;

  /// Exact immutable assessment revision.
  final int revision;

  /// Approved physical assessment category.
  final EvidenceAssessmentType assessmentType;

  /// Canonical SHA-256 of the assessment revision.
  final String checksum;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EvidenceAssessmentRef &&
            other.assessmentId == assessmentId &&
            other.revision == revision &&
            other.assessmentType == assessmentType &&
            other.checksum == checksum;
  }

  @override
  int get hashCode =>
      Object.hash(assessmentId, revision, assessmentType, checksum);

  @override
  String toString() {
    return 'EvidenceAssessmentRef(assessmentId: $assessmentId, '
        'revision: $revision, assessmentType: $assessmentType, '
        'checksum: $checksum)';
  }
}
