import '../validation.dart';
import 'exact_references.dart';

/// Immutable admitted link between physical Knowledge and one Symbol revision.
///
/// Activation is controlled by frozen release membership. This contract has
/// no mutable or independent `enabled` state.
final class SymbolEvidenceBinding {
  factory SymbolEvidenceBinding({
    required String bindingId,
    required int revision,
    required CanonicalJsonProfileRef canonicalJsonProfileRef,
    required SymbolRevisionRef symbolRef,
    required KnowledgeTargetRef knowledgeTargetRef,
    Iterable<SourceRef> sourceRefs = const [],
    required Iterable<EvidenceAssessmentRef> evidenceAssessmentRefs,
  }) {
    final canonicalSources = _canonicalizeSources(sourceRefs);
    final canonicalAssessments = _canonicalizeAssessments(
      evidenceAssessmentRefs,
    );
    if (canonicalAssessments.isEmpty) {
      throw ArgumentError.value(
        evidenceAssessmentRefs,
        'evidenceAssessmentRefs',
        'must not be empty',
      );
    }
    return SymbolEvidenceBinding._(
      bindingId: validateIdentifier(bindingId, 'bindingId'),
      revision: validateRevision(revision, 'revision'),
      canonicalJsonProfileRef: canonicalJsonProfileRef,
      symbolRef: symbolRef,
      knowledgeTargetRef: knowledgeTargetRef,
      sourceRefs: canonicalSources,
      evidenceAssessmentRefs: canonicalAssessments,
    );
  }

  const SymbolEvidenceBinding._({
    required this.bindingId,
    required this.revision,
    required this.canonicalJsonProfileRef,
    required this.symbolRef,
    required this.knowledgeTargetRef,
    required this.sourceRefs,
    required this.evidenceAssessmentRefs,
  });

  /// Fixed schema version for this contract family.
  static const String schemaVersion = '1.0';

  /// Fixed canonical record type.
  static const String recordType = 'atlas.symbolEvidenceBinding';

  /// Stable binding identity.
  final String bindingId;

  /// Exact immutable binding revision.
  final int revision;

  /// Canonical profile for the binding revision.
  final CanonicalJsonProfileRef canonicalJsonProfileRef;

  /// Exact target SymbolDefinition revision.
  final SymbolRevisionRef symbolRef;

  /// Exact frozen physical Knowledge target.
  final KnowledgeTargetRef knowledgeTargetRef;

  /// Optional bibliographic references, canonically ordered.
  final List<SourceRef> sourceRefs;

  /// Required exact internal evidence assessments, canonically ordered.
  final List<EvidenceAssessmentRef> evidenceAssessmentRefs;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SymbolEvidenceBinding &&
            other.bindingId == bindingId &&
            other.revision == revision &&
            other.canonicalJsonProfileRef == canonicalJsonProfileRef &&
            other.symbolRef == symbolRef &&
            other.knowledgeTargetRef == knowledgeTargetRef &&
            sameList(other.sourceRefs, sourceRefs) &&
            sameList(other.evidenceAssessmentRefs, evidenceAssessmentRefs);
  }

  @override
  int get hashCode => Object.hash(
    bindingId,
    revision,
    canonicalJsonProfileRef,
    symbolRef,
    knowledgeTargetRef,
    Object.hashAll(sourceRefs),
    Object.hashAll(evidenceAssessmentRefs),
  );

  @override
  String toString() {
    return 'SymbolEvidenceBinding(bindingId: $bindingId, '
        'revision: $revision, symbolRef: $symbolRef, '
        'knowledgeTargetRef: $knowledgeTargetRef, '
        'sourceRefCount: ${sourceRefs.length}, '
        'assessmentRefCount: ${evidenceAssessmentRefs.length})';
  }

  static List<SourceRef> _canonicalizeSources(Iterable<SourceRef> values) {
    final canonical = values.toList(growable: false)..sort(_compareSources);
    for (var index = 1; index < canonical.length; index++) {
      if (canonical[index - 1] == canonical[index]) {
        throw ArgumentError.value(
          values,
          'sourceRefs',
          'must not contain duplicate exact source references',
        );
      }
    }
    return List<SourceRef>.unmodifiable(canonical);
  }

  static List<EvidenceAssessmentRef> _canonicalizeAssessments(
    Iterable<EvidenceAssessmentRef> values,
  ) {
    final canonical = values.toList(growable: false)..sort(_compareAssessments);
    for (var index = 1; index < canonical.length; index++) {
      if (canonical[index - 1] == canonical[index]) {
        throw ArgumentError.value(
          values,
          'evidenceAssessmentRefs',
          'must not contain duplicate exact assessment references',
        );
      }
    }
    return List<EvidenceAssessmentRef>.unmodifiable(canonical);
  }

  static int _compareSources(SourceRef first, SourceRef second) {
    final id = first.sourceId.compareTo(second.sourceId);
    if (id != 0) return id;
    final revision = first.revision.compareTo(second.revision);
    if (revision != 0) return revision;
    return (first.locator ?? '').compareTo(second.locator ?? '');
  }

  static int _compareAssessments(
    EvidenceAssessmentRef first,
    EvidenceAssessmentRef second,
  ) {
    final type = first.assessmentType.index.compareTo(
      second.assessmentType.index,
    );
    if (type != 0) return type;
    final id = first.assessmentId.compareTo(second.assessmentId);
    if (id != 0) return id;
    return first.revision.compareTo(second.revision);
  }
}
