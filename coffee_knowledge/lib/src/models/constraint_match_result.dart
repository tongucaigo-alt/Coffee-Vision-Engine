import 'knowledge_constraint.dart';

/// Structured outcome of one physical constraint comparison.
enum KnowledgeConstraintOutcome { passed, failed, unavailable }

/// Why approved physical Pattern evidence could not be observed.
enum KnowledgeConstraintUnavailableReason {
  geometryUnavailable,
  topologyUnavailable,
}

/// Immutable structured evidence for one future constraint comparison.
///
/// This model represents an outcome but does not perform matching.
final class ConstraintMatchResult {
  factory ConstraintMatchResult.doubleObserved({
    required KnowledgeConstraint constraint,
    required double observedValue,
    required KnowledgeConstraintOutcome outcome,
  }) {
    _validateObservedOutcome(outcome);
    if (constraint.kind != KnowledgeConstraintKind.doubleRange) {
      throw ArgumentError.value(
        constraint,
        'constraint',
        'must be a double-range constraint',
      );
    }
    validateObservedDouble(key: constraint.key, value: observedValue);
    return ConstraintMatchResult._(
      constraint: constraint,
      outcome: outcome,
      observedDouble: observedValue,
    );
  }

  factory ConstraintMatchResult.integerObserved({
    required KnowledgeConstraint constraint,
    required int observedValue,
    required KnowledgeConstraintOutcome outcome,
  }) {
    _validateObservedOutcome(outcome);
    if (constraint.kind != KnowledgeConstraintKind.integerRange) {
      throw ArgumentError.value(
        constraint,
        'constraint',
        'must be an integer-range constraint',
      );
    }
    validateObservedInteger(key: constraint.key, value: observedValue);
    return ConstraintMatchResult._(
      constraint: constraint,
      outcome: outcome,
      observedInteger: observedValue,
    );
  }

  factory ConstraintMatchResult.booleanObserved({
    required KnowledgeConstraint constraint,
    required bool observedValue,
    required KnowledgeConstraintOutcome outcome,
  }) {
    _validateObservedOutcome(outcome);
    if (constraint.kind != KnowledgeConstraintKind.booleanEquals) {
      throw ArgumentError.value(
        constraint,
        'constraint',
        'must be a boolean constraint',
      );
    }
    return ConstraintMatchResult._(
      constraint: constraint,
      outcome: outcome,
      observedBoolean: observedValue,
    );
  }

  factory ConstraintMatchResult.unavailable({
    required KnowledgeConstraint constraint,
    required KnowledgeConstraintUnavailableReason reason,
  }) {
    final expectedReason = isGeometryConstraintKey(constraint.key)
        ? KnowledgeConstraintUnavailableReason.geometryUnavailable
        : KnowledgeConstraintUnavailableReason.topologyUnavailable;
    if (reason != expectedReason) {
      throw ArgumentError.value(
        reason,
        'reason',
        'must correspond to the physical field referenced by the constraint',
      );
    }
    return ConstraintMatchResult._(
      constraint: constraint,
      outcome: KnowledgeConstraintOutcome.unavailable,
      unavailableReason: reason,
    );
  }

  const ConstraintMatchResult._({
    required this.constraint,
    required this.outcome,
    this.observedDouble,
    this.observedInteger,
    this.observedBoolean,
    this.unavailableReason,
  });

  final KnowledgeConstraint constraint;
  final KnowledgeConstraintOutcome outcome;
  final double? observedDouble;
  final int? observedInteger;
  final bool? observedBoolean;
  final KnowledgeConstraintUnavailableReason? unavailableReason;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConstraintMatchResult &&
            other.constraint == constraint &&
            other.outcome == outcome &&
            other.observedDouble == observedDouble &&
            other.observedInteger == observedInteger &&
            other.observedBoolean == observedBoolean &&
            other.unavailableReason == unavailableReason;
  }

  @override
  int get hashCode => Object.hash(
    constraint,
    outcome,
    observedDouble,
    observedInteger,
    observedBoolean,
    unavailableReason,
  );

  @override
  String toString() {
    return 'ConstraintMatchResult(key: ${constraint.key}, '
        'outcome: $outcome, unavailableReason: $unavailableReason)';
  }

  static void _validateObservedOutcome(KnowledgeConstraintOutcome outcome) {
    if (outcome == KnowledgeConstraintOutcome.unavailable) {
      throw ArgumentError.value(
        outcome,
        'outcome',
        'observed values require passed or failed',
      );
    }
  }
}
