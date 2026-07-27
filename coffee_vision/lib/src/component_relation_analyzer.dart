import 'dart:math' as math;

import 'models/vision_component.dart';
import 'models/vision_component_relation.dart';
import 'models/vision_component_relation_result.dart';
import 'models/vision_component_result.dart';

/// Calculates deterministic directed relations from existing component data.
final class ComponentRelationAnalyzer {
  const ComponentRelationAnalyzer();

  static const double _centerEpsilon = 1e-12;

  VisionComponentRelationResult analyze(VisionComponentResult input) {
    final components = input.components.toList()
      ..sort((first, second) => first.id.compareTo(second.id));
    _validateUniqueIds(components);

    final relations = <VisionComponentRelation>[];
    final nearestNeighbors = <int, int?>{};
    for (final source in components) {
      int? nearestTargetId;
      double? nearestDistance;

      for (final target in components) {
        if (source.id == target.id) continue;
        final relation = _createRelation(source, target);
        relations.add(relation);

        if (nearestDistance == null ||
            relation.centroidDistance < nearestDistance ||
            (relation.centroidDistance == nearestDistance &&
                target.id < nearestTargetId!)) {
          nearestDistance = relation.centroidDistance;
          nearestTargetId = target.id;
        }
      }
      nearestNeighbors[source.id] = nearestTargetId;
    }

    return VisionComponentRelationResult(
      relations: relations,
      nearestNeighborByComponentId: nearestNeighbors,
    );
  }

  VisionComponentRelation _createRelation(
    VisionComponent source,
    VisionComponent target,
  ) {
    final dx = target.centroid.x - source.centroid.x;
    final dy = target.centroid.y - source.centroid.y;
    final sourceBox = source.boundingBox;
    final targetBox = target.boundingBox;
    final horizontalOverlap =
        math.min(sourceBox.right, targetBox.right) -
        math.max(sourceBox.left, targetBox.left);
    final verticalOverlap =
        math.min(sourceBox.bottom, targetBox.bottom) -
        math.max(sourceBox.top, targetBox.top);
    final intersects = horizontalOverlap > 0.0 && verticalOverlap > 0.0;
    final touches =
        !intersects && horizontalOverlap >= 0.0 && verticalOverlap >= 0.0;
    final horizontalGap = math.max(
      0.0,
      math.max(sourceBox.left, targetBox.left) -
          math.min(sourceBox.right, targetBox.right),
    );
    final verticalGap = math.max(
      0.0,
      math.max(sourceBox.top, targetBox.top) -
          math.min(sourceBox.bottom, targetBox.bottom),
    );

    return VisionComponentRelation(
      sourceComponentId: source.id,
      targetComponentId: target.id,
      centroidDistance: math.sqrt(dx * dx + dy * dy),
      boundingBoxDistance: math.sqrt(
        horizontalGap * horizontalGap + verticalGap * verticalGap,
      ),
      relativeDirection: _relativeDirection(dx, dy),
      boundingBoxesTouch: touches,
      boundingBoxesIntersect: intersects,
    );
  }

  VisionRelativeDirection _relativeDirection(double dx, double dy) {
    final absoluteDx = dx.abs();
    final absoluteDy = dy.abs();
    if (absoluteDx <= _centerEpsilon && absoluteDy <= _centerEpsilon) {
      return VisionRelativeDirection.overlappingCenter;
    }
    if (absoluteDx >= absoluteDy) {
      return dx < 0.0
          ? VisionRelativeDirection.left
          : VisionRelativeDirection.right;
    }
    return dy < 0.0
        ? VisionRelativeDirection.above
        : VisionRelativeDirection.below;
  }

  void _validateUniqueIds(List<VisionComponent> components) {
    for (var index = 1; index < components.length; index++) {
      if (components[index - 1].id == components[index].id) {
        throw ArgumentError.value(
          components[index].id,
          'componentResult.components',
          'must contain unique component ids',
        );
      }
    }
  }
}
