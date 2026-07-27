import 'dart:io';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('ConstraintEvaluator', () {
    const evaluator = ConstraintEvaluator();

    test('projects and passes every approved double-valued field', () {
      final candidate = _completeCandidate();
      final geometry = candidate.geometry!;
      final cases = <(KnowledgeConstraintKey, double)>[
        (KnowledgeConstraintKey.geometryLeft, geometry.left),
        (KnowledgeConstraintKey.geometryTop, geometry.top),
        (KnowledgeConstraintKey.geometryRight, geometry.right),
        (KnowledgeConstraintKey.geometryBottom, geometry.bottom),
        (KnowledgeConstraintKey.geometryCentroidX, geometry.centroidX),
        (KnowledgeConstraintKey.geometryCentroidY, geometry.centroidY),
        (KnowledgeConstraintKey.geometryWidth, geometry.width),
        (KnowledgeConstraintKey.geometryHeight, geometry.height),
        (KnowledgeConstraintKey.geometryAspectRatio, geometry.aspectRatio),
      ];

      for (final entry in cases) {
        final constraint = KnowledgeConstraint.doubleRange(
          key: entry.$1,
          minimum: entry.$2,
          maximum: entry.$2,
        );
        final result = evaluator.evaluate(
          candidate: candidate,
          constraint: constraint,
        );

        expect(result.constraint, same(constraint), reason: '${entry.$1}');
        expect(
          result.outcome,
          KnowledgeConstraintOutcome.passed,
          reason: '${entry.$1}',
        );
        expect(result.observedDouble, entry.$2, reason: '${entry.$1}');
      }
    });

    test('projects and passes every approved integer-valued field', () {
      final candidate = _completeCandidate();
      final topology = candidate.topology!;
      final cases = <(KnowledgeConstraintKey, int)>[
        (KnowledgeConstraintKey.topologyNodeCount, topology.nodeCount),
        (
          KnowledgeConstraintKey.topologyDirectedEdgeCount,
          topology.directedEdgeCount,
        ),
      ];

      for (final entry in cases) {
        final constraint = KnowledgeConstraint.integerRange(
          key: entry.$1,
          minimum: entry.$2,
          maximum: entry.$2,
        );
        final result = evaluator.evaluate(
          candidate: candidate,
          constraint: constraint,
        );

        expect(result.constraint, same(constraint), reason: '${entry.$1}');
        expect(
          result.outcome,
          KnowledgeConstraintOutcome.passed,
          reason: '${entry.$1}',
        );
        expect(result.observedInteger, entry.$2, reason: '${entry.$1}');
      }
    });

    test('projects and passes every approved boolean-valued field', () {
      final candidate = _completeCandidate();
      final cases = <(KnowledgeConstraintKey, bool)>[
        (
          KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
          candidate.geometry!.touchesWorkingImageBorder,
        ),
        (
          KnowledgeConstraintKey.topologyIsIsolated,
          candidate.topology!.isIsolated,
        ),
      ];

      for (final entry in cases) {
        final constraint = KnowledgeConstraint.booleanEquals(
          key: entry.$1,
          expected: entry.$2,
        );
        final result = evaluator.evaluate(
          candidate: candidate,
          constraint: constraint,
        );

        expect(result.constraint, same(constraint), reason: '${entry.$1}');
        expect(
          result.outcome,
          KnowledgeConstraintOutcome.passed,
          reason: '${entry.$1}',
        );
        expect(result.observedBoolean, entry.$2, reason: '${entry.$1}');
      }
    });

    test(
      'fails double, integer, and boolean comparisons deterministically',
      () {
        final candidate = _completeCandidate();
        final constraints = <KnowledgeConstraint>[
          KnowledgeConstraint.doubleRange(
            key: KnowledgeConstraintKey.geometryWidth,
            minimum: 0.1,
            maximum: 0.2,
          ),
          KnowledgeConstraint.integerRange(
            key: KnowledgeConstraintKey.topologyNodeCount,
            minimum: 1,
            maximum: 2,
          ),
          KnowledgeConstraint.booleanEquals(
            key: KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
            expected: true,
          ),
        ];

        for (final constraint in constraints) {
          final result = evaluator.evaluate(
            candidate: candidate,
            constraint: constraint,
          );
          expect(result.outcome, KnowledgeConstraintOutcome.failed);
        }
      },
    );

    test('uses inclusive lower and upper numeric boundaries', () {
      final candidate = _completeCandidate();
      final lowerDouble = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryLeft,
        minimum: candidate.geometry!.left,
        maximum: 0.5,
      );
      final upperDouble = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryRight,
        minimum: 0.5,
        maximum: candidate.geometry!.right,
      );
      final lowerInteger = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: candidate.topology!.nodeCount,
        maximum: 5,
      );
      final upperInteger = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 1,
        maximum: candidate.topology!.nodeCount,
      );

      for (final constraint in [
        lowerDouble,
        upperDouble,
        lowerInteger,
        upperInteger,
      ]) {
        expect(
          evaluator
              .evaluate(candidate: candidate, constraint: constraint)
              .outcome,
          KnowledgeConstraintOutcome.passed,
        );
      }
    });

    test('reports missing geometry as unavailable', () {
      final candidate = PatternCandidate(
        id: 1,
        evidence: [PatternEvidence.componentFeature(1)],
      );
      final constraint = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryWidth,
        minimum: 0.1,
        maximum: 0.9,
      );

      final result = evaluator.evaluate(
        candidate: candidate,
        constraint: constraint,
      );

      expect(result.outcome, KnowledgeConstraintOutcome.unavailable);
      expect(
        result.unavailableReason,
        KnowledgeConstraintUnavailableReason.geometryUnavailable,
      );
      expect(result.observedDouble, isNull);
    });

    test('reports missing topology as unavailable', () {
      final candidate = PatternCandidate.withGeometry(
        id: 1,
        evidence: [PatternEvidence.componentFeature(1)],
        geometry: _geometry(),
      );
      final constraint = KnowledgeConstraint.integerRange(
        key: KnowledgeConstraintKey.topologyNodeCount,
        minimum: 1,
        maximum: 5,
      );

      final result = evaluator.evaluate(
        candidate: candidate,
        constraint: constraint,
      );

      expect(result.outcome, KnowledgeConstraintOutcome.unavailable);
      expect(
        result.unavailableReason,
        KnowledgeConstraintUnavailableReason.topologyUnavailable,
      );
      expect(result.observedInteger, isNull);
    });

    test('repeated evaluation returns equal results and hash codes', () {
      final candidate = _completeCandidate();
      final constraint = KnowledgeConstraint.doubleRange(
        key: KnowledgeConstraintKey.geometryAspectRatio,
        minimum: 0.5,
        maximum: 2.0,
      );

      final first = evaluator.evaluate(
        candidate: candidate,
        constraint: constraint,
      );
      final second = evaluator.evaluate(
        candidate: candidate,
        constraint: constraint,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('does not mutate candidate, evidence, geometry, or constraint', () {
      final candidate = _completeCandidate();
      final evidenceBefore = List<PatternEvidence>.of(candidate.evidence);
      final geometryBefore = candidate.geometry;
      final topologyBefore = candidate.topology;
      final constraint = KnowledgeConstraint.booleanEquals(
        key: KnowledgeConstraintKey.topologyIsIsolated,
        expected: false,
      );

      evaluator.evaluate(candidate: candidate, constraint: constraint);

      expect(candidate.evidence, evidenceBefore);
      expect(candidate.geometry, same(geometryBefore));
      expect(candidate.topology, same(topologyBefore));
      expect(constraint.expectedBoolean, isFalse);
      expect(() => candidate.evidence.clear(), throwsUnsupportedError);
    });

    test('keeps the evaluator single-constraint and non-matching', () {
      final source = File(
        'lib/src/constraint_evaluator.dart',
      ).readAsStringSync();
      final executable = source
          .replaceAll(RegExp(r'//[^\r\n]*'), '')
          .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");

      expect(KnowledgeConstraintOutcome.values, [
        KnowledgeConstraintOutcome.passed,
        KnowledgeConstraintOutcome.failed,
        KnowledgeConstraintOutcome.unavailable,
      ]);
      for (final forbidden in [
        'KnowledgeRecord',
        'KnowledgeMatchResult',
        'dataset',
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

PatternCandidate _completeCandidate() {
  return PatternCandidate.withGeometryAndTopology(
    id: 1,
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
