import 'vision_component_relation.dart';

enum VisionEdgeSelectionReason {
  selectedByPassThrough,
  selectedByActiveFilters,
  rejectedByCentroidDistance,
  rejectedByBoundingBoxDistance,
  rejectedByBoundingBoxTouch,
  rejectedByOutgoingLimit,
}

/// Immutable decision for one existing directed component relation.
final class VisionEdgeSelectionDecision {
  const VisionEdgeSelectionDecision({
    required this.relation,
    required this.reason,
  });

  final VisionComponentRelation relation;
  final VisionEdgeSelectionReason reason;

  int get sourceComponentId => relation.sourceComponentId;
  int get targetComponentId => relation.targetComponentId;

  bool get selected =>
      reason == VisionEdgeSelectionReason.selectedByPassThrough ||
      reason == VisionEdgeSelectionReason.selectedByActiveFilters;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionEdgeSelectionDecision &&
            other.relation == relation &&
            other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(relation, reason);

  @override
  String toString() {
    return 'VisionEdgeSelectionDecision('
        'sourceComponentId: $sourceComponentId, '
        'targetComponentId: $targetComponentId, '
        'selected: $selected, reason: $reason)';
  }
}
