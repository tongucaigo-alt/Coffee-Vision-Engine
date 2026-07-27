import 'constraint_match_result.dart';
import 'knowledge_record.dart';

/// Immutable future boundary for one candidate-to-record comparison.
///
/// The result contains only structured physical outcomes. It does not contain
/// scores, confidence, rank, semantic identity, or interpretation.
final class KnowledgeMatchResult {
  factory KnowledgeMatchResult({
    required int candidateId,
    required String recordId,
    required Iterable<ConstraintMatchResult> constraintResults,
  }) {
    if (candidateId <= 0) {
      throw ArgumentError.value(
        candidateId,
        'candidateId',
        'must be greater than zero',
      );
    }
    final validatedRecordId = validateKnowledgeRecordId(recordId);
    final canonical = constraintResults.toList(growable: false)
      ..sort(
        (first, second) =>
            first.constraint.key.index.compareTo(second.constraint.key.index),
      );
    if (canonical.isEmpty) {
      throw ArgumentError.value(
        constraintResults,
        'constraintResults',
        'must not be empty',
      );
    }
    for (var index = 1; index < canonical.length; index++) {
      if (canonical[index - 1].constraint.key ==
          canonical[index].constraint.key) {
        throw ArgumentError.value(
          canonical[index].constraint.key,
          'constraintResults',
          'must contain at most one result for each constraint key',
        );
      }
    }
    return KnowledgeMatchResult._(
      candidateId: candidateId,
      recordId: validatedRecordId,
      constraintResults: List<ConstraintMatchResult>.unmodifiable(canonical),
    );
  }

  const KnowledgeMatchResult._({
    required this.candidateId,
    required this.recordId,
    required this.constraintResults,
  });

  final int candidateId;
  final String recordId;
  final List<ConstraintMatchResult> constraintResults;

  /// Whether every required physical constraint passed.
  bool get matched => constraintResults.every(
    (result) => result.outcome == KnowledgeConstraintOutcome.passed,
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeMatchResult &&
            other.candidateId == candidateId &&
            other.recordId == recordId &&
            _sameList(other.constraintResults, constraintResults);
  }

  @override
  int get hashCode =>
      Object.hash(candidateId, recordId, Object.hashAll(constraintResults));

  @override
  String toString() {
    return 'KnowledgeMatchResult(candidateId: $candidateId, '
        'recordId: $recordId, matched: $matched, '
        'constraintResultCount: ${constraintResults.length})';
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
