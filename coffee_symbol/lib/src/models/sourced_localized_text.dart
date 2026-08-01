import '../validation.dart';
import 'exact_references.dart';

/// Immutable human-readable text with exact source traceability.
final class SourcedLocalizedText {
  factory SourcedLocalizedText({
    required String language,
    required String value,
    required Iterable<SourceRef> sourceRefs,
  }) {
    final materialized = sourceRefs.toList(growable: false);
    if (materialized.isEmpty) {
      throw ArgumentError.value(sourceRefs, 'sourceRefs', 'must not be empty');
    }
    final canonical = List<SourceRef>.of(materialized)
      ..sort(_compareSourceRefs);
    for (var index = 1; index < canonical.length; index++) {
      if (canonical[index - 1] == canonical[index]) {
        throw ArgumentError.value(
          sourceRefs,
          'sourceRefs',
          'must not contain duplicate exact source references',
        );
      }
    }
    return SourcedLocalizedText._(
      language: validateLanguage(language),
      value: validateHumanText(value, 'value'),
      sourceRefs: List<SourceRef>.unmodifiable(canonical),
    );
  }

  const SourcedLocalizedText._({
    required this.language,
    required this.value,
    required this.sourceRefs,
  });

  /// BCP-47 language tag for the text.
  final String language;

  /// Source-backed human-readable text in Unicode NFC form.
  final String value;

  /// Canonically ordered exact source references.
  final List<SourceRef> sourceRefs;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SourcedLocalizedText &&
            other.language == language &&
            other.value == value &&
            sameList(other.sourceRefs, sourceRefs);
  }

  @override
  int get hashCode => Object.hash(language, value, Object.hashAll(sourceRefs));

  @override
  String toString() {
    return 'SourcedLocalizedText(language: $language, '
        'sourceRefCount: ${sourceRefs.length})';
  }

  static int _compareSourceRefs(SourceRef first, SourceRef second) {
    final id = first.sourceId.compareTo(second.sourceId);
    if (id != 0) return id;
    final revision = first.revision.compareTo(second.revision);
    if (revision != 0) return revision;
    return (first.locator ?? '').compareTo(second.locator ?? '');
  }
}
