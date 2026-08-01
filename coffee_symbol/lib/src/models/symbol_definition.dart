import '../validation.dart';
import 'exact_references.dart';
import 'sourced_localized_text.dart';

/// Immutable canonical symbol identity, terminology, and neutral definition.
///
/// This model contains no interpretation, fortune meaning, score, confidence,
/// or physical measurements.
final class SymbolDefinition {
  factory SymbolDefinition({
    required SymbolRevisionRef symbolRef,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required Iterable<SourcedLocalizedText> preferredNames,
    Iterable<SourcedLocalizedText> aliases = const [],
    required Iterable<SourcedLocalizedText> neutralDefinitions,
  }) {
    final preferred = _canonicalizeTexts(
      preferredNames,
      'preferredNames',
      requireNonEmpty: true,
    );
    final canonicalAliases = _canonicalizeTexts(aliases, 'aliases');
    final definitions = _canonicalizeTexts(
      neutralDefinitions,
      'neutralDefinitions',
      requireNonEmpty: true,
    );
    final preferredLanguages = <String>{};
    for (final entry in preferred) {
      if (!preferredLanguages.add(entry.language)) {
        throw ArgumentError.value(
          preferredNames,
          'preferredNames',
          'must contain at most one preferred name per language',
        );
      }
    }
    final allNames = <String>{};
    for (final entry in [...preferred, ...canonicalAliases]) {
      final identity = '${entry.language}\u0000${entry.value}';
      if (!allNames.add(identity)) {
        throw ArgumentError.value(
          aliases,
          'aliases',
          'must not duplicate a preferred name or alias',
        );
      }
    }
    return SymbolDefinition._(
      symbolRef: symbolRef,
      canonicalJsonProfileRef: canonicalJsonProfileRef,
      preferredNames: preferred,
      aliases: canonicalAliases,
      neutralDefinitions: definitions,
    );
  }

  const SymbolDefinition._({
    required this.symbolRef,
    required this.canonicalJsonProfileRef,
    required this.preferredNames,
    required this.aliases,
    required this.neutralDefinitions,
  });

  /// Fixed schema version for this contract family.
  static const String schemaVersion = '1.0';

  /// Fixed canonical record type.
  static const String recordType = 'atlas.symbolDefinition';

  /// Exact identity and checksum of this definition revision.
  final SymbolRevisionRef symbolRef;

  /// Exact canonical JSON profile used for its canonical representation.
  final CanonicalJsonProfileRef canonicalJsonProfileRef;

  /// One source-backed preferred name per included language.
  final List<SourcedLocalizedText> preferredNames;

  /// Optional source-backed aliases.
  final List<SourcedLocalizedText> aliases;

  /// Source-backed neutral definitions without fortune interpretation.
  final List<SourcedLocalizedText> neutralDefinitions;

  /// Stable symbol identity.
  String get symbolId => symbolRef.symbolId;

  /// Exact immutable definition revision.
  int get revision => symbolRef.revision;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SymbolDefinition &&
            other.symbolRef == symbolRef &&
            other.canonicalJsonProfileRef == canonicalJsonProfileRef &&
            sameList(other.preferredNames, preferredNames) &&
            sameList(other.aliases, aliases) &&
            sameList(other.neutralDefinitions, neutralDefinitions);
  }

  @override
  int get hashCode => Object.hash(
    symbolRef,
    canonicalJsonProfileRef,
    Object.hashAll(preferredNames),
    Object.hashAll(aliases),
    Object.hashAll(neutralDefinitions),
  );

  @override
  String toString() {
    return 'SymbolDefinition(symbolId: $symbolId, revision: $revision, '
        'preferredNameCount: ${preferredNames.length}, '
        'aliasCount: ${aliases.length}, '
        'neutralDefinitionCount: ${neutralDefinitions.length})';
  }

  static List<SourcedLocalizedText> _canonicalizeTexts(
    Iterable<SourcedLocalizedText> values,
    String name, {
    bool requireNonEmpty = false,
  }) {
    final materialized = values.toList(growable: false);
    if (requireNonEmpty && materialized.isEmpty) {
      throw ArgumentError.value(values, name, 'must not be empty');
    }
    final canonical = List<SourcedLocalizedText>.of(materialized)
      ..sort(_compareTexts);
    for (var index = 1; index < canonical.length; index++) {
      if (canonical[index - 1] == canonical[index]) {
        throw ArgumentError.value(
          values,
          name,
          'must not contain duplicate entries',
        );
      }
    }
    return List<SourcedLocalizedText>.unmodifiable(canonical);
  }

  static int _compareTexts(
    SourcedLocalizedText first,
    SourcedLocalizedText second,
  ) {
    final language = first.language.compareTo(second.language);
    if (language != 0) return language;
    return first.value.compareTo(second.value);
  }
}
