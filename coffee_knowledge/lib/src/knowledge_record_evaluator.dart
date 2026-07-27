import 'package:coffee_pattern/coffee_pattern.dart';

import 'constraint_evaluator.dart';
import 'models/constraint_match_result.dart';
import 'models/knowledge_record.dart';
import 'models/knowledge_record_evaluation_result.dart';

/// Evaluates every physical constraint in one knowledge record.
///
/// This evaluator preserves atomic evidence without making a match decision.
final class KnowledgeRecordEvaluator {
  const KnowledgeRecordEvaluator();

  KnowledgeRecordEvaluationResult evaluate({
    required KnowledgeRecord record,
    required PatternCandidate candidate,
  }) {
    const constraintEvaluator = ConstraintEvaluator();
    final constraintResults = <ConstraintMatchResult>[
      for (final constraint in record.constraints)
        constraintEvaluator.evaluate(
          candidate: candidate,
          constraint: constraint,
        ),
    ];

    return KnowledgeRecordEvaluationResult(
      candidateId: candidate.id,
      record: record,
      constraintResults: constraintResults,
    );
  }
}
