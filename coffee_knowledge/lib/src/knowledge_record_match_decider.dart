import 'models/knowledge_match_result.dart';
import 'models/knowledge_record_evaluation_result.dart';

/// Produces one mechanical match result from one complete record evaluation.
///
/// Match semantics remain owned by [KnowledgeMatchResult.matched].
final class KnowledgeRecordMatchDecider {
  const KnowledgeRecordMatchDecider();

  KnowledgeMatchResult decide({
    required KnowledgeRecordEvaluationResult evaluationResult,
  }) {
    return KnowledgeMatchResult(
      candidateId: evaluationResult.candidateId,
      recordId: evaluationResult.recordId,
      constraintResults: evaluationResult.constraintResults,
    );
  }
}
