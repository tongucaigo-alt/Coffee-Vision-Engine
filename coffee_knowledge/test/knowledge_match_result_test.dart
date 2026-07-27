import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('ConstraintMatchResult', () {
    test('represents passed and failed typed observations', () {
      final width = _widthConstraint();
      final nodes = _nodeConstraint();
      final border = _borderConstraint();

      final doubleResult = ConstraintMatchResult.doubleObserved(
        constraint: width,
        observedValue: 0.4,
        outcome: KnowledgeConstraintOutcome.passed,
      );
      final integerResult = ConstraintMatchResult.integerObserved(
        constraint: nodes,
        observedValue: 3,
        outcome: KnowledgeConstraintOutcome.failed,
      );
      final booleanResult = ConstraintMatchResult.booleanObserved(
        constraint: border,
        observedValue: false,
        outcome: KnowledgeConstraintOutcome.passed,
      );

      expect(doubleResult.observedDouble, 0.4);
      expect(integerResult.observedInteger, 3);
      expect(booleanResult.observedBoolean, isFalse);
      expect(doubleResult.unavailableReason, isNull);
    });

    test('represents geometry and topology unavailability', () {
      final geometry = ConstraintMatchResult.unavailable(
        constraint: _widthConstraint(),
        reason: KnowledgeConstraintUnavailableReason.geometryUnavailable,
      );
      final topology = ConstraintMatchResult.unavailable(
        constraint: _nodeConstraint(),
        reason: KnowledgeConstraintUnavailableReason.topologyUnavailable,
      );

      expect(geometry.outcome, KnowledgeConstraintOutcome.unavailable);
      expect(geometry.observedDouble, isNull);
      expect(topology.outcome, KnowledgeConstraintOutcome.unavailable);
      expect(topology.observedInteger, isNull);
    });

    test('rejects observed-value and constraint-type mismatches', () {
      expect(
        () => ConstraintMatchResult.doubleObserved(
          constraint: _nodeConstraint(),
          observedValue: 0.5,
          outcome: KnowledgeConstraintOutcome.passed,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConstraintMatchResult.integerObserved(
          constraint: _widthConstraint(),
          observedValue: 1,
          outcome: KnowledgeConstraintOutcome.passed,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConstraintMatchResult.booleanObserved(
          constraint: _widthConstraint(),
          observedValue: true,
          outcome: KnowledgeConstraintOutcome.failed,
        ),
        throwsArgumentError,
      );
    });

    test('rejects unavailable outcomes with observed values', () {
      expect(
        () => ConstraintMatchResult.doubleObserved(
          constraint: _widthConstraint(),
          observedValue: 0.5,
          outcome: KnowledgeConstraintOutcome.unavailable,
        ),
        throwsArgumentError,
      );
    });

    test('rejects impossible observed physical values', () {
      expect(
        () => ConstraintMatchResult.doubleObserved(
          constraint: _widthConstraint(),
          observedValue: 0.0,
          outcome: KnowledgeConstraintOutcome.failed,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConstraintMatchResult.integerObserved(
          constraint: _nodeConstraint(),
          observedValue: 0,
          outcome: KnowledgeConstraintOutcome.failed,
        ),
        throwsArgumentError,
      );
    });

    test('rejects unavailable reasons from the wrong evidence family', () {
      expect(
        () => ConstraintMatchResult.unavailable(
          constraint: _widthConstraint(),
          reason: KnowledgeConstraintUnavailableReason.topologyUnavailable,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConstraintMatchResult.unavailable(
          constraint: _nodeConstraint(),
          reason: KnowledgeConstraintUnavailableReason.geometryUnavailable,
        ),
        throwsArgumentError,
      );
    });

    test('supports equality, hashCode, and structured safe toString', () {
      final first = ConstraintMatchResult.doubleObserved(
        constraint: _widthConstraint(),
        observedValue: 0.4,
        outcome: KnowledgeConstraintOutcome.passed,
      );
      final second = ConstraintMatchResult.doubleObserved(
        constraint: _widthConstraint(),
        observedValue: 0.4,
        outcome: KnowledgeConstraintOutcome.passed,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(<ConstraintMatchResult>{first, second}, hasLength(1));
      expect(first.toString(), contains('passed'));
      expect(first.toString(), isNot(contains('explanation')));
    });
  });

  group('KnowledgeMatchResult', () {
    test('canonicalizes outcomes and derives a successful match', () {
      final topology = ConstraintMatchResult.integerObserved(
        constraint: _nodeConstraint(),
        observedValue: 2,
        outcome: KnowledgeConstraintOutcome.passed,
      );
      final geometry = ConstraintMatchResult.doubleObserved(
        constraint: _widthConstraint(),
        observedValue: 0.4,
        outcome: KnowledgeConstraintOutcome.passed,
      );

      final result = KnowledgeMatchResult(
        candidateId: 4,
        recordId: 'record-a',
        constraintResults: [topology, geometry],
      );

      expect(result.candidateId, 4);
      expect(result.recordId, 'record-a');
      expect(result.constraintResults, [geometry, topology]);
      expect(result.matched, isTrue);
    });

    test('failed and unavailable constraints prevent a match', () {
      final failed = KnowledgeMatchResult(
        candidateId: 1,
        recordId: 'failed',
        constraintResults: [
          ConstraintMatchResult.doubleObserved(
            constraint: _widthConstraint(),
            observedValue: 0.4,
            outcome: KnowledgeConstraintOutcome.failed,
          ),
        ],
      );
      final unavailable = KnowledgeMatchResult(
        candidateId: 1,
        recordId: 'unavailable',
        constraintResults: [
          ConstraintMatchResult.unavailable(
            constraint: _widthConstraint(),
            reason: KnowledgeConstraintUnavailableReason.geometryUnavailable,
          ),
        ],
      );

      expect(failed.matched, isFalse);
      expect(unavailable.matched, isFalse);
    });

    test('rejects invalid identities and empty outcomes', () {
      final outcome = ConstraintMatchResult.doubleObserved(
        constraint: _widthConstraint(),
        observedValue: 0.4,
        outcome: KnowledgeConstraintOutcome.passed,
      );

      expect(
        () => KnowledgeMatchResult(
          candidateId: 0,
          recordId: 'record',
          constraintResults: [outcome],
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeMatchResult(
          candidateId: 1,
          recordId: ' record ',
          constraintResults: [outcome],
        ),
        throwsArgumentError,
      );
      expect(
        () => KnowledgeMatchResult(
          candidateId: 1,
          recordId: 'record',
          constraintResults: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate constraint-result keys', () {
      final outcome = ConstraintMatchResult.doubleObserved(
        constraint: _widthConstraint(),
        observedValue: 0.4,
        outcome: KnowledgeConstraintOutcome.passed,
      );

      expect(
        () => KnowledgeMatchResult(
          candidateId: 1,
          recordId: 'record',
          constraintResults: [outcome, outcome],
        ),
        throwsArgumentError,
      );
    });

    test('defensively preserves immutable outcomes', () {
      final mutable = <ConstraintMatchResult>[
        ConstraintMatchResult.doubleObserved(
          constraint: _widthConstraint(),
          observedValue: 0.4,
          outcome: KnowledgeConstraintOutcome.passed,
        ),
      ];
      final result = KnowledgeMatchResult(
        candidateId: 1,
        recordId: 'record',
        constraintResults: mutable,
      );
      mutable.clear();

      expect(result.constraintResults, hasLength(1));
      expect(() => result.constraintResults.clear(), throwsUnsupportedError);
    });

    test('supports deterministic value semantics and safe toString', () {
      KnowledgeMatchResult create() {
        return KnowledgeMatchResult(
          candidateId: 2,
          recordId: 'opaque',
          constraintResults: [
            ConstraintMatchResult.booleanObserved(
              constraint: _borderConstraint(),
              observedValue: true,
              outcome: KnowledgeConstraintOutcome.passed,
            ),
          ],
        );
      }

      final first = create();
      final second = create();

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(<KnowledgeMatchResult>{first, second}, hasLength(1));
      expect(first.toString(), contains('candidateId: 2'));
      expect(first.toString(), isNot(contains('confidence')));
    });
  });
}

KnowledgeConstraint _widthConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.2,
    maximum: 0.8,
  );
}

KnowledgeConstraint _nodeConstraint() {
  return KnowledgeConstraint.integerRange(
    key: KnowledgeConstraintKey.topologyNodeCount,
    minimum: 1,
    maximum: 4,
  );
}

KnowledgeConstraint _borderConstraint() {
  return KnowledgeConstraint.booleanEquals(
    key: KnowledgeConstraintKey.geometryTouchesWorkingImageBorder,
    expected: true,
  );
}
