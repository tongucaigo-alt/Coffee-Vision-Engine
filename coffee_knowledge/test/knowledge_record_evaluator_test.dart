import 'dart:io';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeRecordEvaluator', () {
    const evaluator = KnowledgeRecordEvaluator();

    test('evaluates one constraint and preserves both identities', () {
      final record = KnowledgeRecord(
        id: 'single',
        constraints: [_widthConstraint()],
      );
      final candidate = _completeCandidate(id: 7);

      final KnowledgeRecordEvaluationResult result = evaluator.evaluate(
        record: record,
        candidate: candidate,
      );

      expect(result.candidateId, 7);
      expect(result.recordId, 'single');
      expect(result.constraintResults, hasLength(1));
      expect(
        result.constraintResults.single.constraint,
        same(record.constraints.single),
      );
      expect(
        result.constraintResults.single.outcome,
        KnowledgeConstraintOutcome.passed,
      );
      expect(result.constraintResults.single.observedDouble, 0.6);
    });

    test('evaluates every constraint once in canonical record order', () {
      final record = _completeRecord();
      final candidate = _completeCandidate();

      final result = evaluator.evaluate(record: record, candidate: candidate);

      expect(result.constraintResults, hasLength(record.constraints.length));
      expect(result.constraintResults.map((item) => item.constraint.key), [
        KnowledgeConstraintKey.geometryWidth,
        KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
        KnowledgeConstraintKey.topologyNodeCount,
      ]);
      for (var index = 0; index < record.constraints.length; index++) {
        expect(
          result.constraintResults[index].constraint,
          same(record.constraints[index]),
        );
      }
    });

    test('preserves mixed outcomes and continues after failed evidence', () {
      final record = KnowledgeRecord(
        id: 'mixed',
        constraints: [
          KnowledgeConstraint.integerRange(
            key: KnowledgeConstraintKey.topologyNodeCount,
            minimum: 1,
            maximum: 4,
          ),
          KnowledgeConstraint.doubleRange(
            key: KnowledgeConstraintKey.geometryHeight,
            minimum: 0.1,
            maximum: 0.2,
          ),
          _widthConstraint(),
        ],
      );
      final candidate = PatternCandidate.withGeometry(
        id: 3,
        evidence: [PatternEvidence.componentFeature(1)],
        geometry: _geometry(),
      );

      final result = evaluator.evaluate(record: record, candidate: candidate);

      expect(result.constraintResults.map((item) => item.outcome), [
        KnowledgeConstraintOutcome.passed,
        KnowledgeConstraintOutcome.failed,
        KnowledgeConstraintOutcome.unavailable,
      ]);
      expect(
        result.constraintResults.last.unavailableReason,
        KnowledgeConstraintUnavailableReason.topologyUnavailable,
      );
    });

    test('preserves all missing evidence without stopping early', () {
      final record = KnowledgeRecord(
        id: 'missing',
        constraints: [
          KnowledgeConstraint.integerRange(
            key: KnowledgeConstraintKey.topologyNodeCount,
            minimum: 1,
            maximum: 4,
          ),
          _widthConstraint(),
        ],
      );
      final candidate = PatternCandidate(
        id: 4,
        evidence: [PatternEvidence.componentFeature(1)],
      );

      final result = evaluator.evaluate(record: record, candidate: candidate);

      expect(result.constraintResults, hasLength(2));
      expect(
        result.constraintResults.map((item) => item.outcome),
        everyElement(KnowledgeConstraintOutcome.unavailable),
      );
      expect(result.constraintResults.map((item) => item.unavailableReason), [
        KnowledgeConstraintUnavailableReason.geometryUnavailable,
        KnowledgeConstraintUnavailableReason.topologyUnavailable,
      ]);
    });

    test('is deterministic for repeated equal evaluations', () {
      final firstRecord = _completeRecord();
      final secondRecord = _completeRecord();

      final first = evaluator.evaluate(
        record: firstRecord,
        candidate: _completeCandidate(),
      );
      final second = evaluator.evaluate(
        record: secondRecord,
        candidate: _completeCandidate(),
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('does not mutate record, candidate, or nested immutable values', () {
      final record = _completeRecord();
      final candidate = _completeCandidate();
      final constraintsBefore = List<KnowledgeConstraint>.of(
        record.constraints,
      );
      final evidenceBefore = List<PatternEvidence>.of(candidate.evidence);
      final geometryBefore = candidate.geometry;
      final topologyBefore = candidate.topology;

      evaluator.evaluate(record: record, candidate: candidate);

      expect(record.constraints, constraintsBefore);
      expect(candidate.evidence, evidenceBefore);
      expect(candidate.geometry, same(geometryBefore));
      expect(candidate.topology, same(topologyBefore));
      expect(() => record.constraints.clear(), throwsUnsupportedError);
      expect(() => candidate.evidence.clear(), throwsUnsupportedError);
    });

    test('exposes one synchronous operation and no downstream behavior', () {
      final barrel = File('lib/coffee_knowledge.dart').readAsStringSync();
      final source = File(
        'lib/src/knowledge_record_evaluator.dart',
      ).readAsStringSync();
      final executable = source
          .replaceAll(RegExp(r'//[^\r\n]*'), '')
          .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");

      expect(barrel, contains('KnowledgeRecordEvaluator'));
      expect(
        RegExp(r'constraintEvaluator\.evaluate\(').allMatches(executable),
        hasLength(1),
      );
      expect(
        executable,
        contains('for (final constraint in record.constraints)'),
      );
      for (final forbidden in [
        'KnowledgeMatchResult',
        'matched',
        'KnowledgeDataset',
        'batch',
        'score',
        'confidence',
        'rank',
        'weight',
        'interpretation',
        'json',
        'File(',
        'Future<',
        'try {',
        'catch (',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

KnowledgeRecord _completeRecord() {
  return KnowledgeRecord(
    id: 'record-a',
    constraints: [
      KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 3,
        maximum: 3,
      ),
      KnowledgeConstraint.booleanEquals(
        key: KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
        expected: false,
      ),
      _widthConstraint(),
    ],
  );
}

KnowledgeConstraint _widthConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.5,
    maximum: 0.7,
  );
}

PatternCandidate _completeCandidate({int id = 1}) {
  return PatternCandidate.withGeometryAndTopology(
    id: id,
    evidence: [PatternEvidence.componentFeature(1)],
    geometry: _geometry(),
    topology: PatternTopology(nodeCount: 3, directedEdgeCount: 4),
  );
}

PatternGeometry _geometry() {
  return PatternGeometry(
    left: 0.1,
    top: 0.2,
    right: 0.7,
    bottom: 0.8,
    centroidX: 0.4,
    centroidY: 0.5,
  );
}
