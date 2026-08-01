import 'package:coffee_knowledge/coffee_knowledge.dart';

import '../validation.dart';
import 'symbol_definition.dart';
import 'symbol_evidence_binding.dart';

/// One exact, explainable support path for a derived Symbol candidate.
final class SymbolCandidateSupport {
  SymbolCandidateSupport({
    required SymbolEvidenceBinding binding,
    required KnowledgeMatchResult knowledgeMatch,
  }) : binding = binding,
       knowledgeMatch = knowledgeMatch {
    if (!knowledgeMatch.matched) {
      throw ArgumentError.value(
        knowledgeMatch,
        'knowledgeMatch',
        'must be matched',
      );
    }
    if (knowledgeMatch.recordId !=
        binding.knowledgeTargetRef.knowledgeRecordId) {
      throw ArgumentError.value(
        knowledgeMatch.recordId,
        'knowledgeMatch',
        'must identify the binding KnowledgeRecord target',
      );
    }
  }

  /// Exact original admitted binding object.
  final SymbolEvidenceBinding binding;

  /// Exact original physical Knowledge match object.
  final KnowledgeMatchResult knowledgeMatch;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SymbolCandidateSupport &&
            other.binding == binding &&
            other.knowledgeMatch == knowledgeMatch;
  }

  @override
  int get hashCode => Object.hash(binding, knowledgeMatch);

  @override
  String toString() {
    return 'SymbolCandidateSupport(bindingId: ${binding.bindingId}, '
        'bindingRevision: ${binding.revision}, '
        'recordId: ${knowledgeMatch.recordId})';
  }
}

/// Immutable derived Symbol candidate with complete canonical support.
///
/// This runtime projection is not a canonical Symbol or evidence record.
final class SymbolCandidate {
  factory SymbolCandidate({
    required int patternCandidateId,
    required SymbolDefinition definition,
    required Iterable<SymbolCandidateSupport> supports,
  }) {
    if (patternCandidateId <= 0) {
      throw ArgumentError.value(
        patternCandidateId,
        'patternCandidateId',
        'must be greater than zero',
      );
    }
    final materialized = supports.toList(growable: false);
    if (materialized.isEmpty) {
      throw ArgumentError.value(supports, 'supports', 'must not be empty');
    }
    for (final support in materialized) {
      if (support.knowledgeMatch.candidateId != patternCandidateId) {
        throw ArgumentError.value(
          support.knowledgeMatch.candidateId,
          'supports',
          'must identify the same Pattern candidate',
        );
      }
      if (support.binding.symbolRef != definition.symbolRef) {
        throw ArgumentError.value(
          support.binding.symbolRef,
          'supports',
          'must reference the exact SymbolDefinition revision',
        );
      }
    }
    final canonical = List<SymbolCandidateSupport>.of(materialized)
      ..sort(_compareSupports);
    for (var index = 1; index < canonical.length; index++) {
      if (_compareSupports(canonical[index - 1], canonical[index]) == 0) {
        throw ArgumentError.value(
          supports,
          'supports',
          'must not contain duplicate support identities',
        );
      }
    }
    return SymbolCandidate._(
      patternCandidateId: patternCandidateId,
      definition: definition,
      supports: List<SymbolCandidateSupport>.unmodifiable(canonical),
    );
  }

  const SymbolCandidate._({
    required this.patternCandidateId,
    required this.definition,
    required this.supports,
  });

  /// Result-local physical Pattern candidate identity.
  final int patternCandidateId;

  /// Exact original SymbolDefinition object.
  final SymbolDefinition definition;

  /// Complete, canonically ordered support paths.
  final List<SymbolCandidateSupport> supports;

  /// Stable symbol identity.
  String get symbolId => definition.symbolId;

  /// Exact symbol revision.
  int get symbolRevision => definition.revision;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SymbolCandidate &&
            other.patternCandidateId == patternCandidateId &&
            other.definition == definition &&
            sameList(other.supports, supports);
  }

  @override
  int get hashCode =>
      Object.hash(patternCandidateId, definition, Object.hashAll(supports));

  @override
  String toString() {
    return 'SymbolCandidate(patternCandidateId: $patternCandidateId, '
        'symbolId: $symbolId, symbolRevision: $symbolRevision, '
        'supportCount: ${supports.length})';
  }

  static int _compareSupports(
    SymbolCandidateSupport first,
    SymbolCandidateSupport second,
  ) {
    final record = first.knowledgeMatch.recordId.compareTo(
      second.knowledgeMatch.recordId,
    );
    if (record != 0) return record;
    final binding = first.binding.bindingId.compareTo(second.binding.bindingId);
    if (binding != 0) return binding;
    return first.binding.revision.compareTo(second.binding.revision);
  }
}
