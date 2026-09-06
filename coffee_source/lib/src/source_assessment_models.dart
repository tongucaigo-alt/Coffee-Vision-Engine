import 'package:coffee_symbol/coffee_symbol.dart';

import 'source_validation.dart';

enum SourceEvidenceRole { primary, secondary, tertiary, discovery }

enum SourceSupportRelation {
  supports,
  contradicts,
  contextualizes,
  mentionsOnly,
}

enum SourceAssessmentOutcome {
  eligibleCore,
  eligibleCorroborative,
  discoveryOnly,
  ineligible,
}

enum ProvenanceQuality { verified, partiallyVerified, unverified }

enum AttributionQuality { identified, organizational, pseudonymous, anonymous }

enum EditorialControlQuality {
  peerReviewed,
  academicSupervision,
  institutional,
  professionalEditorial,
  selfPublished,
  none,
  unknown,
}

enum MethodTransparencyQuality { explicit, partial, absent, notApplicable }

enum SourceStabilityQuality {
  fixedEdition,
  archivedSnapshot,
  capturedMutable,
  uncapturedMutable,
}

enum CulturalProximityQuality {
  directCommunityRecord,
  recognizedSpecialist,
  secondaryAnalysis,
  unspecified,
}

final class DomainTargetRef {
  DomainTargetRef({
    required String recordType,
    required String recordId,
    required int revision,
    required String checksum,
    String? targetPath,
  }) : recordType = validateIdentifier(recordType, 'recordType'),
       recordId = validateIdentifier(recordId, 'recordId'),
       revision = _validateRevision(revision),
       checksum = validateChecksum(checksum, 'checksum'),
       targetPath = validateOptionalText(targetPath, 'targetPath') {
    final path = this.targetPath;
    if (path != null && !path.startsWith('/')) {
      throw ArgumentError.value(
        path,
        'targetPath',
        'must be an absolute JSON Pointer',
      );
    }
  }

  final String recordType;
  final String recordId;
  final int revision;
  final String checksum;
  final String? targetPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DomainTargetRef &&
          other.recordType == recordType &&
          other.recordId == recordId &&
          other.revision == revision &&
          other.checksum == checksum &&
          other.targetPath == targetPath;

  @override
  int get hashCode =>
      Object.hash(recordType, recordId, revision, checksum, targetPath);

  @override
  String toString() =>
      'DomainTargetRef(recordType: $recordType, recordId: $recordId, '
      'revision: $revision, targetPathPresent: ${targetPath != null})';
}

final class QualityDimensions {
  const QualityDimensions({
    required this.provenance,
    required this.attribution,
    required this.editorialControl,
    required this.methodTransparency,
    required this.sourceStability,
    required this.culturalProximity,
  });

  final ProvenanceQuality provenance;
  final AttributionQuality attribution;
  final EditorialControlQuality editorialControl;
  final MethodTransparencyQuality methodTransparency;
  final SourceStabilityQuality sourceStability;
  final CulturalProximityQuality culturalProximity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QualityDimensions &&
          other.provenance == provenance &&
          other.attribution == attribution &&
          other.editorialControl == editorialControl &&
          other.methodTransparency == methodTransparency &&
          other.sourceStability == sourceStability &&
          other.culturalProximity == culturalProximity;

  @override
  int get hashCode => Object.hash(
    provenance,
    attribution,
    editorialControl,
    methodTransparency,
    sourceStability,
    culturalProximity,
  );

  @override
  String toString() =>
      'QualityDimensions('
      'provenance: ${provenance.name}, attribution: ${attribution.name}, '
      'sourceStability: ${sourceStability.name})';
}

final class SourceUseAssessment {
  factory SourceUseAssessment({
    required String schemaVersion,
    required String useAssessmentId,
    required int revision,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required DomainTargetRef targetRef,
    required SourceRef sourceRef,
    required SourceEvidenceRole evidenceRole,
    required SourceSupportRelation supportRelation,
    required String independenceGroupId,
    required String independenceRationale,
    required QualityDimensions qualityDimensions,
    required SourceAssessmentOutcome assessmentOutcome,
    Iterable<String> limitations = const [],
    required String rationale,
  }) {
    if (schemaVersion != '1.0') {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', 'must be 1.0');
    }
    final canonicalLimitations = limitations.toList(growable: false)
      ..sort((first, second) => first.compareTo(second));
    for (var index = 0; index < canonicalLimitations.length; index++) {
      validateHumanText(canonicalLimitations[index], 'limitations');
      if (index > 0 &&
          canonicalLimitations[index - 1] == canonicalLimitations[index]) {
        throw ArgumentError.value(
          limitations,
          'limitations',
          'must not contain duplicate exact values',
        );
      }
    }
    return SourceUseAssessment._(
      schemaVersion: schemaVersion,
      useAssessmentId: validateIdentifier(useAssessmentId, 'useAssessmentId'),
      revision: _validateRevision(revision),
      canonicalJsonProfileRef: canonicalJsonProfileRef,
      targetRef: targetRef,
      sourceRef: sourceRef,
      evidenceRole: evidenceRole,
      supportRelation: supportRelation,
      independenceGroupId: validateIdentifier(
        independenceGroupId,
        'independenceGroupId',
      ),
      independenceRationale: validateHumanText(
        independenceRationale,
        'independenceRationale',
      ),
      qualityDimensions: qualityDimensions,
      assessmentOutcome: assessmentOutcome,
      limitations: List<String>.unmodifiable(canonicalLimitations),
      rationale: validateHumanText(rationale, 'rationale'),
    );
  }

  const SourceUseAssessment._({
    required this.schemaVersion,
    required this.useAssessmentId,
    required this.revision,
    required this.canonicalJsonProfileRef,
    required this.targetRef,
    required this.sourceRef,
    required this.evidenceRole,
    required this.supportRelation,
    required this.independenceGroupId,
    required this.independenceRationale,
    required this.qualityDimensions,
    required this.assessmentOutcome,
    required this.limitations,
    required this.rationale,
  });

  static const String recordType = 'atlas.sourceUseAssessment';

  final String schemaVersion;
  final String useAssessmentId;
  final int revision;
  final CanonicalJsonProfileRef canonicalJsonProfileRef;
  final DomainTargetRef targetRef;
  final SourceRef sourceRef;
  final SourceEvidenceRole evidenceRole;
  final SourceSupportRelation supportRelation;
  final String independenceGroupId;
  final String independenceRationale;
  final QualityDimensions qualityDimensions;
  final SourceAssessmentOutcome assessmentOutcome;
  final List<String> limitations;
  final String rationale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceUseAssessment &&
          other.schemaVersion == schemaVersion &&
          other.useAssessmentId == useAssessmentId &&
          other.revision == revision &&
          other.canonicalJsonProfileRef == canonicalJsonProfileRef &&
          other.targetRef == targetRef &&
          other.sourceRef == sourceRef &&
          other.evidenceRole == evidenceRole &&
          other.supportRelation == supportRelation &&
          other.independenceGroupId == independenceGroupId &&
          other.independenceRationale == independenceRationale &&
          other.qualityDimensions == qualityDimensions &&
          other.assessmentOutcome == assessmentOutcome &&
          sameList(other.limitations, limitations) &&
          other.rationale == rationale;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    useAssessmentId,
    revision,
    canonicalJsonProfileRef,
    targetRef,
    sourceRef,
    evidenceRole,
    supportRelation,
    independenceGroupId,
    independenceRationale,
    qualityDimensions,
    assessmentOutcome,
    Object.hashAll(limitations),
    rationale,
  );

  @override
  String toString() =>
      'SourceUseAssessment(useAssessmentId: $useAssessmentId, '
      'revision: $revision, evidenceRole: ${evidenceRole.name}, '
      'assessmentOutcome: ${assessmentOutcome.name}, '
      'limitationCount: ${limitations.length})';
}

int _validateRevision(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'revision', 'must be greater than zero');
  }
  return value;
}
