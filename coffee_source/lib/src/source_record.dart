import 'package:coffee_symbol/coffee_symbol.dart';

import 'source_models.dart';
import 'source_validation.dart';

/// One immutable, exact source manifestation inspected by Atlas.
final class SourceRecord {
  factory SourceRecord({
    required String schemaVersion,
    required String sourceId,
    required int revision,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required SourceClass sourceClass,
    required String title,
    required Iterable<SourceAgent> creators,
    required PublicationInfo publication,
    required LanguageInfo languages,
    required Iterable<SourceIdentifier> identifiers,
    required AccessInfo access,
    required RightsInfo rights,
    required CulturalCoverage culturalCoverage,
    required IntegrityInfo integrity,
  }) {
    if (schemaVersion != '1.0') {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'must be the supported value 1.0',
      );
    }
    final sourceRef = SourceRef(sourceId: sourceId, revision: revision);
    final canonicalCreators = creators.toList(growable: false)
      ..sort(_compareCreators);
    final canonicalIdentifiers = identifiers.toList(growable: false)
      ..sort(_compareIdentifiers);
    if (canonicalIdentifiers.isEmpty) {
      throw ArgumentError.value(
        identifiers,
        'identifiers',
        'must contain at least one recoverable identifier',
      );
    }
    for (var index = 1; index < canonicalIdentifiers.length; index++) {
      if (canonicalIdentifiers[index - 1] == canonicalIdentifiers[index]) {
        throw ArgumentError.value(
          identifiers,
          'identifiers',
          'must not contain duplicate exact identifiers',
        );
      }
    }
    final isMutable =
        integrity.manifestationType ==
            SourceManifestationType.capturedMutable ||
        integrity.manifestationType ==
            SourceManifestationType.uncapturedMutable;
    if (access.accessMode == 'online' &&
        isMutable &&
        access.accessedAtUtc == null) {
      throw ArgumentError.value(
        access,
        'access',
        'online mutable content requires accessedAtUtc',
      );
    }
    return SourceRecord._(
      schemaVersion: schemaVersion,
      sourceRef: sourceRef,
      canonicalJsonProfileRef: canonicalJsonProfileRef,
      sourceClass: sourceClass,
      title: validateHumanText(title, 'title'),
      creators: List<SourceAgent>.unmodifiable(canonicalCreators),
      publication: publication,
      languages: languages,
      identifiers: List<SourceIdentifier>.unmodifiable(canonicalIdentifiers),
      access: access,
      rights: rights,
      culturalCoverage: culturalCoverage,
      integrity: integrity,
    );
  }

  const SourceRecord._({
    required this.schemaVersion,
    required this.sourceRef,
    required this.canonicalJsonProfileRef,
    required this.sourceClass,
    required this.title,
    required this.creators,
    required this.publication,
    required this.languages,
    required this.identifiers,
    required this.access,
    required this.rights,
    required this.culturalCoverage,
    required this.integrity,
  });

  static const String recordType = 'atlas.sourceRecord';

  final String schemaVersion;
  final SourceRef sourceRef;
  final CanonicalJsonProfileRef canonicalJsonProfileRef;
  final SourceClass sourceClass;
  final String title;
  final List<SourceAgent> creators;
  final PublicationInfo publication;
  final LanguageInfo languages;
  final List<SourceIdentifier> identifiers;
  final AccessInfo access;
  final RightsInfo rights;
  final CulturalCoverage culturalCoverage;
  final IntegrityInfo integrity;

  String get sourceId => sourceRef.sourceId;
  int get revision => sourceRef.revision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceRecord &&
          other.schemaVersion == schemaVersion &&
          other.sourceRef == sourceRef &&
          other.canonicalJsonProfileRef == canonicalJsonProfileRef &&
          other.sourceClass == sourceClass &&
          other.title == title &&
          sameList(other.creators, creators) &&
          other.publication == publication &&
          other.languages == languages &&
          sameList(other.identifiers, identifiers) &&
          other.access == access &&
          other.rights == rights &&
          other.culturalCoverage == culturalCoverage &&
          other.integrity == integrity;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    sourceRef,
    canonicalJsonProfileRef,
    sourceClass,
    title,
    Object.hashAll(creators),
    publication,
    languages,
    Object.hashAll(identifiers),
    access,
    rights,
    culturalCoverage,
    integrity,
  );

  @override
  String toString() =>
      'SourceRecord(sourceId: $sourceId, revision: $revision, '
      'sourceClass: ${sourceClass.name}, creatorCount: ${creators.length}, '
      'identifierCount: ${identifiers.length})';

  static int _compareCreators(SourceAgent first, SourceAgent second) {
    final role = first.role.compareTo(second.role);
    if (role != 0) return role;
    final type = first.agentType.name.compareTo(second.agentType.name);
    if (type != 0) return type;
    return first.displayName.compareTo(second.displayName);
  }

  static int _compareIdentifiers(
    SourceIdentifier first,
    SourceIdentifier second,
  ) {
    final type = first.identifierType.name.compareTo(
      second.identifierType.name,
    );
    if (type != 0) return type;
    return first.value.compareTo(second.value);
  }
}
