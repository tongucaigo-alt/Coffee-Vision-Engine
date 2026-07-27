import 'package:coffee_pattern/coffee_pattern.dart';

import 'knowledge_record_evaluator.dart';
import 'knowledge_record_match_decider.dart';
import 'models/knowledge_match_result.dart';
import 'models/knowledge_record.dart';

/// Matches one Pattern candidate against an externally supplied record list.
///
/// This service only composes the frozen single-record evaluator and decider.
/// It canonicalizes record traversal by exact record ID before evaluation.
final class KnowledgeRecordCollectionMatcher {
  const KnowledgeRecordCollectionMatcher();

  List<KnowledgeMatchResult> match({
    required PatternCandidate candidate,
    required Iterable<KnowledgeRecord> records,
  }) {
    final canonicalRecords = records.toList(growable: false);
    final seenIds = <String>{};
    for (final record in canonicalRecords) {
      final duplicateId = record.id;
      if (!seenIds.add(duplicateId)) {
        throw ArgumentError.value(
          duplicateId,
          'records',
          'must contain unique KnowledgeRecord IDs',
        );
      }
    }
    canonicalRecords.sort((first, second) => first.id.compareTo(second.id));

    const evaluator = KnowledgeRecordEvaluator();
    const decider = KnowledgeRecordMatchDecider();
    final results = <KnowledgeMatchResult>[];

    for (final record in canonicalRecords) {
      results.add(
        decider.decide(
          evaluationResult: evaluator.evaluate(
            record: record,
            candidate: candidate,
          ),
        ),
      );
    }

    return List<KnowledgeMatchResult>.unmodifiable(results);
  }
}
