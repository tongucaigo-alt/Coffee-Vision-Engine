import 'models/vision_component_relation.dart';
import 'models/vision_component_relation_result.dart';
import 'models/vision_edge_selection_decision.dart';
import 'models/vision_edge_selection_profile.dart';
import 'models/vision_edge_selection_result.dart';

/// Deterministically selects existing directed relations without mutating them.
final class EdgeSelector {
  const EdgeSelector();

  VisionEdgeSelectionResult select({
    required VisionComponentRelationResult relationResult,
    required VisionEdgeSelectionProfile profile,
  }) {
    _validateProfile(profile);
    final relations = relationResult.relations.toList()
      ..sort(_compareCanonical);
    _validateFullCandidateSet(relationResult, relations);

    final rejections =
        <({int source, int target}), VisionEdgeSelectionReason>{};
    final eligibleBySource = <int, List<VisionComponentRelation>>{};
    for (final relation in relations) {
      final rejection = _geometricRejection(profile, relation);
      if (rejection != null) {
        rejections[_pairOf(relation)] = rejection;
        continue;
      }
      eligibleBySource
          .putIfAbsent(relation.sourceComponentId, () => [])
          .add(relation);
    }

    final outgoingLimit = profile.maxOutgoingPerSource;
    if (outgoingLimit != null) {
      for (final candidates in eligibleBySource.values) {
        candidates.sort(_compareOutgoingCandidates);
        for (var index = outgoingLimit; index < candidates.length; index++) {
          rejections[_pairOf(candidates[index])] =
              VisionEdgeSelectionReason.rejectedByOutgoingLimit;
        }
      }
    }

    final selectedReason = profile.isPassThrough
        ? VisionEdgeSelectionReason.selectedByPassThrough
        : VisionEdgeSelectionReason.selectedByActiveFilters;
    final decisions = [
      for (final relation in relations)
        VisionEdgeSelectionDecision(
          relation: relation,
          reason: rejections[_pairOf(relation)] ?? selectedReason,
        ),
    ];
    return VisionEdgeSelectionResult(
      profile: profile,
      candidateRelations: relations,
      decisionRecords: decisions,
    );
  }

  VisionEdgeSelectionReason? _geometricRejection(
    VisionEdgeSelectionProfile profile,
    VisionComponentRelation relation,
  ) {
    final maxCentroidDistance = profile.maxCentroidDistance;
    if (maxCentroidDistance != null &&
        relation.centroidDistance > maxCentroidDistance) {
      return VisionEdgeSelectionReason.rejectedByCentroidDistance;
    }
    final maxBoundingBoxDistance = profile.maxBoundingBoxDistance;
    if (maxBoundingBoxDistance != null &&
        relation.boundingBoxDistance > maxBoundingBoxDistance) {
      return VisionEdgeSelectionReason.rejectedByBoundingBoxDistance;
    }
    if (profile.requireBoundingBoxTouch && !relation.boundingBoxesTouch) {
      return VisionEdgeSelectionReason.rejectedByBoundingBoxTouch;
    }
    return null;
  }

  void _validateProfile(VisionEdgeSelectionProfile profile) {
    _validateDistance(
      profile.maxCentroidDistance,
      'profile.maxCentroidDistance',
    );
    _validateDistance(
      profile.maxBoundingBoxDistance,
      'profile.maxBoundingBoxDistance',
    );
    final maxOutgoingPerSource = profile.maxOutgoingPerSource;
    if (maxOutgoingPerSource != null && maxOutgoingPerSource < 0) {
      throw ArgumentError.value(
        maxOutgoingPerSource,
        'profile.maxOutgoingPerSource',
        'must be non-negative',
      );
    }
  }

  void _validateDistance(double? value, String name) {
    if (value != null && (!value.isFinite || value < 0.0)) {
      throw ArgumentError.value(value, name, 'must be finite and non-negative');
    }
  }

  void _validateFullCandidateSet(
    VisionComponentRelationResult relationResult,
    List<VisionComponentRelation> relations,
  ) {
    final componentIds = relationResult.nearestNeighborByComponentId.keys
        .toSet();
    final expectedCount = componentIds.length * (componentIds.length - 1);
    if (relations.length != expectedCount) {
      throw ArgumentError.value(
        relations.length,
        'relationResult.relations',
        'must contain exactly $expectedCount directed candidate relations',
      );
    }

    final pairs = <({int source, int target})>{};
    for (final relation in relations) {
      if (!componentIds.contains(relation.sourceComponentId) ||
          !componentIds.contains(relation.targetComponentId)) {
        throw ArgumentError.value(
          relation,
          'relationResult.relations',
          'must reference only components in the nearest-neighbor map',
        );
      }
      if (relation.sourceComponentId == relation.targetComponentId) {
        throw ArgumentError.value(
          relation,
          'relationResult.relations',
          'must not contain self relations',
        );
      }
      if (!pairs.add(_pairOf(relation))) {
        throw ArgumentError.value(
          relation,
          'relationResult.relations',
          'must not contain duplicate directed relation pairs',
        );
      }
    }
    for (final sourceId in componentIds) {
      for (final targetId in componentIds) {
        if (sourceId == targetId) continue;
        if (!pairs.contains((source: sourceId, target: targetId))) {
          throw ArgumentError.value(
            relationResult,
            'relationResult',
            'must contain every directed candidate pair exactly once',
          );
        }
      }
    }
  }

  static ({int source, int target}) _pairOf(VisionComponentRelation relation) =>
      (source: relation.sourceComponentId, target: relation.targetComponentId);

  static int _compareCanonical(
    VisionComponentRelation first,
    VisionComponentRelation second,
  ) {
    final sourceComparison = first.sourceComponentId.compareTo(
      second.sourceComponentId,
    );
    if (sourceComparison != 0) return sourceComparison;
    return first.targetComponentId.compareTo(second.targetComponentId);
  }

  static int _compareOutgoingCandidates(
    VisionComponentRelation first,
    VisionComponentRelation second,
  ) {
    final centroidComparison = first.centroidDistance.compareTo(
      second.centroidDistance,
    );
    if (centroidComparison != 0) return centroidComparison;
    final boundingBoxComparison = first.boundingBoxDistance.compareTo(
      second.boundingBoxDistance,
    );
    if (boundingBoxComparison != 0) return boundingBoxComparison;
    return first.targetComponentId.compareTo(second.targetComponentId);
  }
}
