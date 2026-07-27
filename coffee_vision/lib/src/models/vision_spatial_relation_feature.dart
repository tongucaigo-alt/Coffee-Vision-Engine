import 'vision_component_relation.dart';
import 'vision_edge_selection_decision.dart';

/// Immutable M7D view of one existing spatial-relation selection decision.
///
/// The underlying relation and decision values are reused directly. This model
/// does not recalculate geometry, selection, confidence, or semantic meaning.
final class VisionSpatialRelationFeature {
  VisionSpatialRelationFeature.fromDecision(
    VisionEdgeSelectionDecision decision,
  ) : _decision = decision {
    final relation = decision.relation;
    if (relation.sourceComponentId <= 0 ||
        relation.targetComponentId <= 0 ||
        relation.sourceComponentId == relation.targetComponentId) {
      throw ArgumentError.value(
        relation,
        'decision',
        'must reference two different positive component IDs',
      );
    }
    if (!relation.centroidDistance.isFinite ||
        relation.centroidDistance < 0.0 ||
        !relation.boundingBoxDistance.isFinite ||
        relation.boundingBoxDistance < 0.0) {
      throw ArgumentError.value(
        relation,
        'decision',
        'must contain finite non-negative distances',
      );
    }
    if (relation.boundingBoxesTouch && relation.boundingBoxesIntersect) {
      throw ArgumentError.value(
        relation,
        'decision',
        'bounding boxes cannot touch and intersect simultaneously',
      );
    }
  }

  final VisionEdgeSelectionDecision _decision;

  /// Canonical source component identity from the existing relation.
  int get sourceComponentId => _decision.sourceComponentId;

  /// Canonical target component identity from the existing relation.
  int get targetComponentId => _decision.targetComponentId;

  /// Existing normalized centroid distance without recalculation.
  double get centroidDistance => _decision.relation.centroidDistance;

  /// Existing normalized bounding-box distance without recalculation.
  double get boundingBoxDistance => _decision.relation.boundingBoxDistance;

  /// Existing relative direction from the relation analysis.
  VisionRelativeDirection get relativeDirection =>
      _decision.relation.relativeDirection;

  /// Whether the existing relation reports bounding-box contact.
  bool get boundingBoxesTouch => _decision.relation.boundingBoxesTouch;

  /// Whether the existing relation reports positive-area box intersection.
  bool get boundingBoxesIntersect => _decision.relation.boundingBoxesIntersect;

  /// Whether the existing edge-selection decision selected this relation.
  bool get selected => _decision.selected;

  /// The existing deterministic selection or rejection reason.
  VisionEdgeSelectionReason get selectionReason => _decision.reason;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionSpatialRelationFeature && other._decision == _decision;
  }

  @override
  int get hashCode => _decision.hashCode;

  @override
  String toString() {
    return 'VisionSpatialRelationFeature('
        'sourceComponentId: $sourceComponentId, '
        'targetComponentId: $targetComponentId, '
        'centroidDistance: $centroidDistance, '
        'boundingBoxDistance: $boundingBoxDistance, '
        'relativeDirection: $relativeDirection, '
        'boundingBoxesTouch: $boundingBoxesTouch, '
        'boundingBoxesIntersect: $boundingBoxesIntersect, '
        'selected: $selected, selectionReason: $selectionReason)';
  }
}
