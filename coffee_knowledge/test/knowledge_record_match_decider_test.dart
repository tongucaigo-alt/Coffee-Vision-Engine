import 'dart:io';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeRecordMatchDecider', () {
    const decider = KnowledgeRecordMatchDecider();

    test('all passed produces a match and preserves identities', () {
      final evaluation = _evaluation(
        candidateId: 7,
        recordId: 'record-a',
        outcomes: const [
          KnowledgeConstraintOutcome.passed,
          KnowledgeConstraintOutcome.passed,
        ],
      );

      final result = decider.decide(evaluationResult: evaluation);

      expect(result.candidateId, 7);
      expect(result.recordId, 'record-a');
      expect(result.matched, isTrue);
    });

    test('one failed result prevents a match', () {
      final result = decider.decide(
        evaluationResult: _evaluation(
          outcomes: const [KnowledgeConstraintOutcome.failed],
        ),
      );

      expect(result.matched, isFalse);
    });

    test('multiple failed results prevent a match', () {
      final result = decider.decide(
        evaluationResult: _evaluation(
          outcomes: const [
            KnowledgeConstraintOutcome.failed,
            KnowledgeConstraintOutcome.failed,
          ],
        ),
      );

      expect(result.matched, isFalse);
    });

    test('one unavailable result prevents a match', () {
      final result = decider.decide(
        evaluationResult: _evaluation(
          outcomes: const [KnowledgeConstraintOutcome.unavailable],
        ),
      );

      expect(result.matched, isFalse);
    });

    test('mixed passed and failed results prevent a match', () {
      final result = decider.decide(
        evaluationResult: _evaluation(
          outcomes: const [
            KnowledgeConstraintOutcome.passed,
            KnowledgeConstraintOutcome.failed,
          ],
        ),
      );

      expect(result.matched, isFalse);
      expect(result.constraintResults, hasLength(2));
    });

    test('mixed passed and unavailable results prevent a match', () {
      final result = decider.decide(
        evaluationResult: _evaluation(
          outcomes: const [
            KnowledgeConstraintOutcome.passed,
            KnowledgeConstraintOutcome.unavailable,
          ],
        ),
      );

      expect(result.matched, isFalse);
      expect(result.constraintResults, hasLength(2));
    });

    test('preserves every atomic result object and canonical order', () {
      final evaluation = _evaluation(
        outcomes: const [
          KnowledgeConstraintOutcome.failed,
          KnowledgeConstraintOutcome.passed,
          KnowledgeConstraintOutcome.unavailable,
        ],
      );

      final result = decider.decide(evaluationResult: evaluation);

      expect(result.constraintResults, hasLength(3));
      expect(
        result.constraintResults.map((item) => item.constraint.key),
        evaluation.constraintResults.map((item) => item.constraint.key),
      );
      for (
        var index = 0;
        index < evaluation.constraintResults.length;
        index++
      ) {
        expect(
          result.constraintResults[index],
          same(evaluation.constraintResults[index]),
        );
      }
    });

    test('is deterministic without mutating the evaluation result', () {
      final firstEvaluation = _evaluation(
        outcomes: const [
          KnowledgeConstraintOutcome.passed,
          KnowledgeConstraintOutcome.failed,
        ],
      );
      final secondEvaluation = _evaluation(
        outcomes: const [
          KnowledgeConstraintOutcome.passed,
          KnowledgeConstraintOutcome.failed,
        ],
      );
      final originalAtoms = List<ConstraintMatchResult>.of(
        firstEvaluation.constraintResults,
      );

      final first = decider.decide(evaluationResult: firstEvaluation);
      final second = decider.decide(evaluationResult: secondEvaluation);

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(firstEvaluation.constraintResults, originalAtoms);
      for (var index = 0; index < originalAtoms.length; index++) {
        expect(
          firstEvaluation.constraintResults[index],
          same(originalAtoms[index]),
        );
      }
      expect(
        () => firstEvaluation.constraintResults.clear(),
        throwsUnsupportedError,
      );
    });

    test('exposes one synchronous decision and no upstream behavior', () {
      final barrel = File('lib/coffee_knowledge.dart').readAsStringSync();
      final source = File(
        'lib/src/knowledge_record_match_decider.dart',
      ).readAsStringSync();
      final executable = source
          .replaceAll(RegExp(r'//[^\r\n]*'), '')
          .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");

      expect(barrel, contains('KnowledgeRecordMatchDecider'));
      expect(
        RegExp(r'KnowledgeMatchResult decide\(').allMatches(executable),
        hasLength(1),
      );
      expect(
        RegExp(r'return KnowledgeMatchResult\(').allMatches(executable),
        hasLength(1),
      );
      for (final forbidden in [
        'ConstraintEvaluator',
        'KnowledgeRecordEvaluator',
        '.evaluate(',
        'PatternCandidate',
        'coffee_pattern',
        'coffee_vision',
        'MatchPolicy',
        'KnowledgeDataset',
        'score',
        'confidence',
        'rank',
        'interpretation',
        'json',
        'File(',
        'Future<',
        'async',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

KnowledgeRecordEvaluationResult _evaluation({
  int candidateId = 1,
  String recordId = 'record',
  required List<KnowledgeConstraintOutcome> outcomes,
}) {
  final constraints = <KnowledgeConstraint>[
    _widthConstraint(),
    _heightConstraint(),
    _nodeCountConstraint(),
  ].take(outcomes.length).toList(growable: false);
  final record = KnowledgeRecord(id: recordId, constraints: constraints);
  final results = <ConstraintMatchResult>[
    for (var index = 0; index < outcomes.length; index++)
      _resultFor(record.constraints[index], outcomes[index]),
  ];
  return KnowledgeRecordEvaluationResult(
    candidateId: candidateId,
    record: record,
    constraintResults: results,
  );
}

ConstraintMatchResult _resultFor(
  KnowledgeConstraint constraint,
  KnowledgeConstraintOutcome outcome,
) {
  if (outcome == KnowledgeConstraintOutcome.unavailable) {
    return ConstraintMatchResult.unavailable(
      constraint: constraint,
      reason: switch (constraint.key) {
        KnowledgeConstraintKey.topologyNodeCount ||
        KnowledgeConstraintKey.topologyDirectedEdgeCount ||
        KnowledgeConstraintKey.topologyIsIsolated =>
          KnowledgeConstraintUnavailableReason.topologyUnavailable,
        _ => KnowledgeConstraintUnavailableReason.geometryUnavailable,
      },
    );
  }
  return switch (constraint.kind) {
    KnowledgeConstraintKind.doubleRange => ConstraintMatchResult.doubleObserved(
      constraint: constraint,
      observedValue: 0.5,
      outcome: outcome,
    ),
    KnowledgeConstraintKind.integerRange =>
      ConstraintMatchResult.integerObserved(
        constraint: constraint,
        observedValue: 2,
        outcome: outcome,
      ),
    KnowledgeConstraintKind.booleanEquals =>
      ConstraintMatchResult.booleanObserved(
        constraint: constraint,
        observedValue: true,
        outcome: outcome,
      ),
  };
}

KnowledgeConstraint _widthConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.2,
    maximum: 0.8,
  );
}

KnowledgeConstraint _heightConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryHeight,
    minimum: 0.2,
    maximum: 0.8,
  );
}

KnowledgeConstraint _nodeCountConstraint() {
  return KnowledgeConstraint.integerRange(
    key: KnowledgeConstraintKey.topologyNodeCount,
    minimum: 1,
    maximum: 4,
  );
}
