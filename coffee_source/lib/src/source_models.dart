import 'source_validation.dart';

/// Objective publication or creation form of a source manifestation.
enum SourceClass {
  journalOrConferencePublication,
  monographOrBook,
  thesisOrDissertation,
  institutionalPublication,
  archivalMaterial,
  referenceWork,
  interview,
  oralHistoryOrFieldRecord,
  webPublication,
  communityGeneratedContent,
}

/// Observable identity kind of a source creator or publisher.
enum SourceAgentType { person, organization }

/// Immutable creator or publisher attribution.
final class SourceAgent {
  SourceAgent({
    required this.agentType,
    required String displayName,
    required String role,
  }) : displayName = validateHumanText(displayName, 'displayName'),
       role = validateHumanText(role, 'role');

  final SourceAgentType agentType;
  final String displayName;
  final String role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceAgent &&
          other.agentType == agentType &&
          other.displayName == displayName &&
          other.role == role;

  @override
  int get hashCode => Object.hash(agentType, displayName, role);

  @override
  String toString() => 'SourceAgent(agentType: ${agentType.name}, role: $role)';
}

/// Immutable publication metadata for the consulted manifestation.
final class PublicationInfo {
  PublicationInfo({
    String? publicationDate,
    String? publisher,
    String? containerTitle,
    String? edition,
    String? volume,
    String? issue,
    String? pages,
  }) : publicationDate = validateOptionalText(
         publicationDate,
         'publicationDate',
       ),
       publisher = validateOptionalText(publisher, 'publisher'),
       containerTitle = validateOptionalText(containerTitle, 'containerTitle'),
       edition = validateOptionalText(edition, 'edition'),
       volume = validateOptionalText(volume, 'volume'),
       issue = validateOptionalText(issue, 'issue'),
       pages = validateOptionalText(pages, 'pages');

  final String? publicationDate;
  final String? publisher;
  final String? containerTitle;
  final String? edition;
  final String? volume;
  final String? issue;
  final String? pages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicationInfo &&
          other.publicationDate == publicationDate &&
          other.publisher == publisher &&
          other.containerTitle == containerTitle &&
          other.edition == edition &&
          other.volume == volume &&
          other.issue == issue &&
          other.pages == pages;

  @override
  int get hashCode => Object.hash(
    publicationDate,
    publisher,
    containerTitle,
    edition,
    volume,
    issue,
    pages,
  );

  @override
  String toString() =>
      'PublicationInfo(datePresent: ${publicationDate != null}, '
      'publisherPresent: ${publisher != null})';
}

/// Consulted and, when known, original source languages.
final class LanguageInfo {
  LanguageInfo({required String consultedLanguage, String? originalLanguage})
    : consultedLanguage = validateLanguage(
        consultedLanguage,
        'consultedLanguage',
      ),
      originalLanguage = originalLanguage == null
          ? null
          : validateLanguage(originalLanguage, 'originalLanguage');

  final String consultedLanguage;
  final String? originalLanguage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageInfo &&
          other.consultedLanguage == consultedLanguage &&
          other.originalLanguage == originalLanguage;

  @override
  int get hashCode => Object.hash(consultedLanguage, originalLanguage);

  @override
  String toString() =>
      'LanguageInfo(consultedLanguage: $consultedLanguage, '
      'originalLanguagePresent: ${originalLanguage != null})';
}

/// Recoverable source identifier vocabulary.
enum SourceIdentifierType {
  doi,
  isbn,
  issn,
  url,
  archiveId,
  catalogId,
  localAccessionId,
}

/// Immutable recoverable identifier for a source manifestation.
final class SourceIdentifier {
  SourceIdentifier({required this.identifierType, required String value})
    : value = validateHumanText(value, 'value');

  final SourceIdentifierType identifierType;
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceIdentifier &&
          other.identifierType == identifierType &&
          other.value == value;

  @override
  int get hashCode => Object.hash(identifierType, value);

  @override
  String toString() =>
      'SourceIdentifier(identifierType: ${identifierType.name})';
}

/// Immutable access metadata for the consulted manifestation.
final class AccessInfo {
  AccessInfo({
    required String accessMode,
    String? accessedAtUtc,
    String? repository,
  }) : accessMode = validateIdentifier(accessMode, 'accessMode'),
       accessedAtUtc = validateOptionalUtcTimestamp(
         accessedAtUtc,
         'accessedAtUtc',
       ),
       repository = validateOptionalText(repository, 'repository');

  final String accessMode;
  final String? accessedAtUtc;
  final String? repository;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessInfo &&
          other.accessMode == accessMode &&
          other.accessedAtUtc == accessedAtUtc &&
          other.repository == repository;

  @override
  int get hashCode => Object.hash(accessMode, accessedAtUtc, repository);

  @override
  String toString() =>
      'AccessInfo(accessMode: $accessMode, '
      'accessedAtUtcPresent: ${accessedAtUtc != null})';
}

/// Rights status known for the consulted manifestation.
enum RightsStatus {
  publicDomain,
  licensed,
  permissionGranted,
  citationOnly,
  restricted,
  unknown,
}

/// Immutable minimum rights information.
final class RightsInfo {
  RightsInfo({
    required this.rightsStatus,
    String? licenseId,
    String? permissionRef,
  }) : licenseId = validateOptionalText(licenseId, 'licenseId'),
       permissionRef = validateOptionalText(permissionRef, 'permissionRef') {
    if (rightsStatus == RightsStatus.licensed && this.licenseId == null) {
      throw ArgumentError.value(
        licenseId,
        'licenseId',
        'is required when rightsStatus is licensed',
      );
    }
    if (rightsStatus == RightsStatus.permissionGranted &&
        this.permissionRef == null) {
      throw ArgumentError.value(
        permissionRef,
        'permissionRef',
        'is required when rightsStatus is permissionGranted',
      );
    }
  }

  final RightsStatus rightsStatus;
  final String? licenseId;
  final String? permissionRef;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RightsInfo &&
          other.rightsStatus == rightsStatus &&
          other.licenseId == licenseId &&
          other.permissionRef == permissionRef;

  @override
  int get hashCode => Object.hash(rightsStatus, licenseId, permissionRef);

  @override
  String toString() =>
      'RightsInfo(rightsStatus: ${rightsStatus.name}, '
      'licensePresent: ${licenseId != null}, '
      'permissionPresent: ${permissionRef != null})';
}

/// Basis on which cultural context coverage was recorded.
enum CulturalCoverageBasis { sourceDeclared, catalogerObserved, unknown }

/// Immutable cultural-context coverage metadata.
final class CulturalCoverage {
  factory CulturalCoverage({
    required Iterable<String> contextIds,
    required CulturalCoverageBasis basis,
    String? note,
  }) {
    final canonicalContextIds = contextIds.toList(growable: false)
      ..sort((first, second) => first.compareTo(second));
    for (var index = 0; index < canonicalContextIds.length; index++) {
      validateIdentifier(canonicalContextIds[index], 'contextIds');
      if (index > 0 &&
          canonicalContextIds[index - 1] == canonicalContextIds[index]) {
        throw ArgumentError.value(
          contextIds,
          'contextIds',
          'must not contain duplicate exact context IDs',
        );
      }
    }
    return CulturalCoverage._(
      contextIds: List<String>.unmodifiable(canonicalContextIds),
      basis: basis,
      note: validateOptionalText(note, 'note'),
    );
  }

  const CulturalCoverage._({
    required this.contextIds,
    required this.basis,
    required this.note,
  });

  final List<String> contextIds;
  final CulturalCoverageBasis basis;
  final String? note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CulturalCoverage &&
          sameList(other.contextIds, contextIds) &&
          other.basis == basis &&
          other.note == note;

  @override
  int get hashCode => Object.hash(Object.hashAll(contextIds), basis, note);

  @override
  String toString() =>
      'CulturalCoverage(contextCount: ${contextIds.length}, '
      'basis: ${basis.name}, notePresent: ${note != null})';
}

/// Physical form in which the consulted source was fixed or observed.
enum SourceManifestationType {
  fixedEdition,
  archivedSnapshot,
  capturedMutable,
  uncapturedMutable,
  physicalRecord,
}

/// Immutable integrity metadata for the exact consulted manifestation.
final class IntegrityInfo {
  IntegrityInfo({
    required this.manifestationType,
    String? capturedAtUtc,
    String? contentChecksum,
    String? archivedIdentifier,
  }) : capturedAtUtc = validateOptionalUtcTimestamp(
         capturedAtUtc,
         'capturedAtUtc',
       ),
       contentChecksum = validateOptionalChecksum(
         contentChecksum,
         'contentChecksum',
       ),
       archivedIdentifier = validateOptionalText(
         archivedIdentifier,
         'archivedIdentifier',
       ) {
    if (manifestationType == SourceManifestationType.capturedMutable &&
        (this.capturedAtUtc == null || this.contentChecksum == null)) {
      throw ArgumentError.value(
        manifestationType,
        'manifestationType',
        'capturedMutable requires capturedAtUtc and contentChecksum',
      );
    }
  }

  final SourceManifestationType manifestationType;
  final String? capturedAtUtc;
  final String? contentChecksum;
  final String? archivedIdentifier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegrityInfo &&
          other.manifestationType == manifestationType &&
          other.capturedAtUtc == capturedAtUtc &&
          other.contentChecksum == contentChecksum &&
          other.archivedIdentifier == archivedIdentifier;

  @override
  int get hashCode => Object.hash(
    manifestationType,
    capturedAtUtc,
    contentChecksum,
    archivedIdentifier,
  );

  @override
  String toString() =>
      'IntegrityInfo(manifestationType: ${manifestationType.name}, '
      'capturePresent: ${capturedAtUtc != null}, '
      'checksumPresent: ${contentChecksum != null})';
}
