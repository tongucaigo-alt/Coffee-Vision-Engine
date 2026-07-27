import 'dart:io';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeRecordEvaluationResult', () {
    test('represents exactly one record and one candidate identity', () {
      final record = _record();
      final results = _resultsFor(record);

      final evaluation = KnowledgeRecordEvaluationResult(
        candidateId: 7,
        record: record,
        constraintResults: results,
      );

      expect(evaluation.candidateId, 7);
      expect(evaluation.recordId, 'record-a');
      expect(evaluation.constraintResults, results);
    });

    test('preserves canonical record order and exact atomic results', () {
      final record = _record();
      final results = _resultsFor(record);

      final evaluation = KnowledgeRecordEvaluationResult(
        candidateId: 1,
        record: record,
        constraintResults: results,
      );

      expect(
        evaluation.constraintResults.map((result) => result.constraint.key),
        [
          KnowledgeConstraintKey.geometryWidth,
          KnowledgeConstraintKey.topologyNodeCount,
        ],
      );
      expect(evaluation.constraintResults[0], same(results[0]));
      expect(evaluation.constraintResults[1], same(results[1]));
      expect(
        evaluation.constraintResults[0].constraint,
        same(record.constraints[0]),
      );
      expect(
        evaluation.constraintResults[1].constraint,
        same(record.constraints[1]),
      );
    });

    test('preserves failed and unavailable atomic evidence unchanged', () {
      final record = _record();
      final results = <ConstraintMatchResult>[
        ConstraintMatchResult.doubleObserved(
          constraint: record.constraints[0],
          observedValue: 0.9,
          outcome: KnowledgeConstraintOutcome.failed,
        ),
        ConstraintMatchResult.unavailable(
          constraint: record.constraints[1],
          reason: KnowledgeConstraintUnavailableReason.topologyUnavailable,
        ),
      ];

      final evaluation = KnowledgeRecordEvaluationResult(
        candidateId: 1,
        record: record,
        constraintResults: results,
      );

      expect(evaluation.constraintResults[0], same(results[0]));
      expect(evaluation.constraintResults[1], same(results[1]));
      expect(evaluation.constraintResults.map((result) => result.outcome), [
        KnowledgeConstraintOutcome.failed,
        KnowledgeConstraintOutcome.unavailable,
      ]);
    });

    test('rejects invalid candidate identity', () {
      final record = _record();

      expect(
        () => KnowledgeRecordEvaluationResult(
          candidateId: 0,
          record: record,
          constraintResults: _resultsFor(record),
        ),
        throwsArgumentError,
      );
    });

    test('rejects incomplete and extra result collections', () {
      final record = _record();
      final results = _resultsFor(record);

      expect(
        () => KnowledgeRecordEvaluationResult(
          candidateId: 1,
          record: record,
          constraintResults: [results.first],
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeRecordEvaluationResult(
          candidateId: 1,
          record: record,
          constraintResults: [...results, results.last],
        ),
        throwsArgumentError,
      );
    });

    test('rejects reordered and foreign constraint results', () {
      final record = _record();
      final results = _resultsFor(record);
      final foreignConstraint = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryWidth,
        minimum: 0.2,
        maximum: 0.8,
      );

      expect(
        () => KnowledgeRecordEvaluationResult(
          candidateId: 1,
          record: record,
          constraintResults: results.reversed,
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeRecordEvaluationResult(
          candidateId: 1,
          record: KnowledgeRecord(
            id: 'foreign',
            constraints: [foreignConstraint],
          ),
          constraintResults: [
            ConstraintMatchResult.doubleObserved(
              constraint: KnowledgeConstraint.doubleRange(
                key: KnowledgeConstraintKey.geometryWidth,
                minimum: 0.2,
                maximum: 0.8,
              ),
              observedValue: 0.5,
              outcome: KnowledgeConstraintOutcome.passed,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('defensively preserves an immutable result collection', () {
      final record = _record();
      final mutable = _resultsFor(record);
      final evaluation = KnowledgeRecordEvaluationResult(
        candidateId: 1,
        record: record,
        constraintResults: mutable,
      );

      mutable.clear();

      expect(evaluation.constraintResults, hasLength(2));
      expect(
        () => evaluation.constraintResults.clear(),
        throwsUnsupportedError,
      );
    });

    test('supports deterministic value semantics and safe toString', () {
      KnowledgeRecordEvaluationResult create() {
        final record = _record();
        return KnowledgeRecordEvaluationResult(
          candidateId: 3,
          record: record,
          constraintResults: _resultsFor(record),
        );
      }

      final first = create();
      final second = create();
      final text = first.toString().toLowerCase();

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(<KnowledgeRecordEvaluationResult>{first, second}, hasLength(1));
      expect(text, contains('candidateid: 3'));
      expect(text, contains('recordid: record-a'));
      for (final forbidden in [
        'matched',
        'score',
        'confidence',
        'rank',
        'interpretation',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('exports only a contract and contains no evaluator behavior', () {
      final barrel = File('lib/coffee_knowledge.dart').readAsStringSync();
      final source = File(
        'lib/src/models/knowledge_record_evaluation_result.dart',
      ).readAsStringSync();
      final executable = source
          .replaceAll(RegExp(r'//[^\r\n]*'), '')
          .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");

      expect(barrel, contains('KnowledgeRecordEvaluationResult'));
      for (final forbidden in [
        'KnowledgeRecordEvaluator',
        'ConstraintEvaluator(',
        '.evaluate(',
        'matched',
        'score',
        'confidence',
        'rank',
        'interpretation',
        'json',
        'File(',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

KnowledgeRecord _record() {
  return KnowledgeRecord(
    id: 'record-a',
    constraints: [
      KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 1,
        maximum: 4,
      ),
      KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryWidth,
        minimum: 0.2,
        maximum: 0.8,
      ),
    ],
  );
}

List<ConstraintMatchResult> _resultsFor(KnowledgeRecord record) {
  return [
    ConstraintMatchResult.doubleObserved(
      constraint: record.constraints[0],
      observedValue: 0.5,
      outcome: KnowledgeConstraintOutcome.passed,
    ),
    ConstraintMatchResult.integerObserved(
      constraint: record.constraints[1],
      observedValue: 2,
      outcome: KnowledgeConstraintOutcome.passed,
    ),
  ];
}
