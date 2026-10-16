import '../canonical_order.dart';
import 'vision_component_relation.dart';
import 'vision_edge_selection_decision.dart';
import 'vision_edge_selection_profile.dart';

/// Complete immutable edge-selection decisions for one candidate relation set.
final class VisionEdgeSelectionResult {
  factory VisionEdgeSelectionResult({
    required VisionEdgeSelectionProfile profile,
    required Iterable<VisionComponentRelation> candidateRelations,
    required Iterable<VisionEdgeSelectionDecision> decisionRecords,
  }) {
    final candidates = canonicalCopy(candidateRelations, _compareRelations);
    int candidateSource = 0, candidateTarget = 0;
    for (final candidate in candidates) {
      if (candidate.sourceComponentId == candidateSource &&
          candidate.targetComponentId == candidateTarget) {
        throw ArgumentError.value(
          candidate,
          'candidateRelations',
          'must not contain duplicate directed relation pairs',
        );
      }
      candidateSource = candidate.sourceComponentId;
      candidateTarget = candidate.targetComponentId;
    }

    final decisions = canonicalCopy(decisionRecords, _compareDecisions);
    int decisionSource = 0, decisionTarget = 0;
    for (final decision in decisions) {
      if (decision.sourceComponentId == decisionSource &&
          decision.targetComponentId == decisionTarget) {
        throw ArgumentError.value(
          decision,
          'decisionRecords',
          'must not contain duplicate directed relation decisions',
        );
      }
      decisionSource = decision.sourceComponentId;
      decisionTarget = decision.targetComponentId;
      _validateReason(profile, decision);
    }

    if (decisions.length != candidates.length) {
      throw ArgumentError.value(
        decisions.length,
        'decisionRecords',
        'must contain exactly one record for each candidate relation',
      );
    }
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final decision = decisions[index];
      if (candidate.sourceComponentId != decision.sourceComponentId ||
          candidate.targetComponentId != decision.targetComponentId) {
        throw ArgumentError.value(
          decision,
          'decisionRecords',
          'must cover the same directed pairs as candidateRelations',
        );
      }
      if (!identical(candidate, decision.relation)) {
        throw ArgumentError.value(
          decision.relation,
          'decisionRecords',
          'must retain the original candidate relation instance',
        );
      }
    }

    final selected = decisions
        .where((decision) => decision.selected)
        .map((decision) => decision.relation);
    return VisionEdgeSelectionResult._(
      profile: profile,
      selectedRelations: List<VisionComponentRelation>.unmodifiable(selected),
      decisionRecords: List<VisionEdgeSelectionDecision>.unmodifiable(
        decisions,
      ),
    );
  }

  const VisionEdgeSelectionResult._({
    required this.profile,
    required this.selectedRelations,
    required this.decisionRecords,
  });

  final VisionEdgeSelectionProfile profile;
  final List<VisionComponentRelation> selectedRelations;
  final List<VisionEdgeSelectionDecision> decisionRecords;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionEdgeSelectionResult &&
            other.profile == profile &&
            _sameList(other.decisionRecords, decisionRecords);
  }

  @override
  int get hashCode => Object.hash(profile, Object.hashAll(decisionRecords));

  @override
  String toString() {
    return 'VisionEdgeSelectionResult('
        'candidateCount: ${decisionRecords.length}, '
        'selectedCount: ${selectedRelations.length}, profile: $profile)';
  }

  static int _compareRelations(
    VisionComponentRelation first,
    VisionComponentRelation second,
  ) {
    final sourceComparison = first.sourceComponentId.compareTo(
      second.sourceComponentId,
    );
    if (sourceComparison != 0) return sourceComparison;
    return first.targetComponentId.compareTo(second.targetComponentId);
  }

  static int _compareDecisions(
    VisionEdgeSelectionDecision first,
    VisionEdgeSelectionDecision second,
  ) {
    final sourceComparison = first.sourceComponentId.compareTo(
      second.sourceComponentId,
    );
    if (sourceComparison != 0) return sourceComparison;
    return first.targetComponentId.compareTo(second.targetComponentId);
  }

  static void _validateReason(
    VisionEdgeSelectionProfile profile,
    VisionEdgeSelectionDecision decision,
  ) {
    if (profile.isPassThrough) {
      if (decision.reason != VisionEdgeSelectionReason.selectedByPassThrough) {
        throw ArgumentError.value(
          decision.reason,
          'decisionRecords',
          'pass-through profiles require selectedByPassThrough decisions',
        );
      }
      return;
    }
    if (decision.selected &&
        decision.reason != VisionEdgeSelectionReason.selectedByActiveFilters) {
      throw ArgumentError.value(
        decision.reason,
        'decisionRecords',
        'active profiles require selectedByActiveFilters for selected edges',
      );
    }
    if (decision.reason == VisionEdgeSelectionReason.selectedByPassThrough) {
      throw ArgumentError.value(
        decision.reason,
        'decisionRecords',
        'selectedByPassThrough is valid only for pass-through profiles',
      );
    }
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
