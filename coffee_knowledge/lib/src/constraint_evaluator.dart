import 'package:coffee_pattern/coffee_pattern.dart';

import 'models/constraint_match_result.dart';
import 'models/knowledge_constraint.dart';

/// Deterministically evaluates one physical constraint against one pattern.
///
/// This evaluator performs no record matching, ranking, interpretation, or
/// dataset traversal.
final class ConstraintEvaluator {
  const ConstraintEvaluator();

  ConstraintMatchResult evaluate({
    required PatternCandidate candidate,
    required KnowledgeConstraint constraint,
  }) {
    final geometry = candidate.geometry;
    final topology = candidate.topology;

    return switch (constraint.key) {
      KnowledgeConstraintKey.geometryLeft =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.left),
      KnowledgeConstraintKey.geometryTop =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.top),
      KnowledgeConstraintKey.geometryRight =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.right),
      KnowledgeConstraintKey.geometryBottom =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.bottom),
      KnowledgeConstraintKey.geometryCentroidX =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.centroidX),
      KnowledgeConstraintKey.geometryCentroidY =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.centroidY),
      KnowledgeConstraintKey.geometryWidth =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.width),
      KnowledgeConstraintKey.geometryHeight =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.height),
      KnowledgeConstraintKey.geometryAspectRatio =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateDouble(constraint, geometry.aspectRatio),
      KnowledgeConstraintKey.geometryTouchesWorkingImageBorder =>
        geometry == null
            ? _geometryUnavailable(constraint)
            : _evaluateBoolean(constraint, geometry.touchesWorkingImageBorder),
      KnowledgeConstraintKey.topologyNodeCount =>
        topology == null
            ? _topologyUnavailable(constraint)
            : _evaluateInteger(constraint, topology.nodeCount),
      KnowledgeConstraintKey.topologyDirectedEdgeCount =>
        topology == null
            ? _topologyUnavailable(constraint)
            : _evaluateInteger(constraint, topology.directedEdgeCount),
      KnowledgeConstraintKey.topologyIsIsolated =>
        topology == null
            ? _topologyUnavailable(constraint)
            : _evaluateBoolean(constraint, topology.isIsolated),
    };
  }

  static ConstraintMatchResult _evaluateDouble(
    KnowledgeConstraint constraint,
    double observedValue,
  ) {
    final passed =
        observedValue >= constraint.minimumDouble! &&
        observedValue <= constraint.maximumDouble!;
    return ConstraintMatchResult.doubleObserved(
      constraint: constraint,
      observedValue: observedValue,
      outcome: passed
          ? KnowledgeConstraintOutcome.passed
          : KnowledgeConstraintOutcome.failed,
    );
  }

  static ConstraintMatchResult _evaluateInteger(
    KnowledgeConstraint constraint,
    int observedValue,
  ) {
    final passed =
        observedValue >= constraint.minimumInteger! &&
        observedValue <= constraint.maximumInteger!;
    return ConstraintMatchResult.integerObserved(
      constraint: constraint,
      observedValue: observedValue,
      outcome: passed
          ? KnowledgeConstraintOutcome.passed
          : KnowledgeConstraintOutcome.failed,
    );
  }

  static ConstraintMatchResult _evaluateBoolean(
    KnowledgeConstraint constraint,
    bool observedValue,
  ) {
    return ConstraintMatchResult.booleanObserved(
      constraint: constraint,
      observedValue: observedValue,
      outcome: observedValue == constraint.expectedBoolean
          ? KnowledgeConstraintOutcome.passed
          : KnowledgeConstraintOutcome.failed,
    );
  }

  static ConstraintMatchResult _geometryUnavailable(
    KnowledgeConstraint constraint,
  ) {
    return ConstraintMatchResult.unavailable(
      constraint: constraint,
      reason: KnowledgeConstraintUnavailableReason.geometryUnavailable,
    );
  }

  static ConstraintMatchResult _topologyUnavailable(
    KnowledgeConstraint constraint,
  ) {
    return ConstraintMatchResult.unavailable(
      constraint: constraint,
      reason: KnowledgeConstraintUnavailableReason.topologyUnavailable,
    );
  }
}
