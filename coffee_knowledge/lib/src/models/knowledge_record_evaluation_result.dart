import 'constraint_match_result.dart';
import 'knowledge_record.dart';

/// Complete immutable mechanical evaluation evidence for one record.
///
/// This result preserves atomic outcomes without deciding whether the record
/// matches the evaluated Pattern candidate.
final class KnowledgeRecordEvaluationResult {
  factory KnowledgeRecordEvaluationResult({
    required int candidateId,
    required KnowledgeRecord record,
    required Iterable<ConstraintMatchResult> constraintResults,
  }) {
    if (candidateId <= 0) {
      throw ArgumentError.value(
        candidateId,
        'candidateId',
        'must be greater than zero',
      );
    }

    final copiedResults = constraintResults.toList(growable: false);
    if (copiedResults.length != record.constraints.length) {
      throw ArgumentError.value(
        constraintResults,
        'constraintResults',
        'must contain exactly one result for every record constraint',
      );
    }

    for (var index = 0; index < copiedResults.length; index++) {
      if (!identical(
        copiedResults[index].constraint,
        record.constraints[index],
      )) {
        throw ArgumentError.value(
          copiedResults[index].constraint,
          'constraintResults',
          'must preserve the exact record constraints in canonical order',
        );
      }
    }

    return KnowledgeRecordEvaluationResult._(
      candidateId: candidateId,
      recordId: record.id,
      constraintResults: List<ConstraintMatchResult>.unmodifiable(
        copiedResults,
      ),
    );
  }

  const KnowledgeRecordEvaluationResult._({
    required this.candidateId,
    required this.recordId,
    required this.constraintResults,
  });

  /// Canonical identity of the evaluated Pattern candidate.
  final int candidateId;

  /// Stable opaque identity of the evaluated knowledge record.
  final String recordId;

  /// Complete atomic results in the record's canonical constraint order.
  final List<ConstraintMatchResult> constraintResults;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeRecordEvaluationResult &&
            other.candidateId == candidateId &&
            other.recordId == recordId &&
            _sameList(other.constraintResults, constraintResults);
  }

  @override
  int get hashCode =>
      Object.hash(candidateId, recordId, Object.hashAll(constraintResults));

  @override
  String toString() {
    return 'KnowledgeRecordEvaluationResult(candidateId: $candidateId, '
        'recordId: $recordId, '
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
