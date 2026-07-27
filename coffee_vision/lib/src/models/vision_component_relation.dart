enum VisionRelativeDirection { left, right, above, below, overlappingCenter }

/// Directed geometric relation from one component to another.
final class VisionComponentRelation {
  VisionComponentRelation({
    required int sourceComponentId,
    required int targetComponentId,
    required double centroidDistance,
    required double boundingBoxDistance,
    required this.relativeDirection,
    required this.boundingBoxesTouch,
    required this.boundingBoxesIntersect,
  }) : sourceComponentId = _validatedId(sourceComponentId, 'sourceComponentId'),
       targetComponentId = _validatedId(targetComponentId, 'targetComponentId'),
       centroidDistance = _validatedDistance(
         centroidDistance,
         'centroidDistance',
       ),
       boundingBoxDistance = _validatedDistance(
         boundingBoxDistance,
         'boundingBoxDistance',
       ) {
    if (sourceComponentId == targetComponentId) {
      throw ArgumentError.value(
        targetComponentId,
        'targetComponentId',
        'must differ from sourceComponentId',
      );
    }
    if (boundingBoxesTouch && boundingBoxesIntersect) {
      throw ArgumentError(
        'Bounding boxes cannot touch and intersect at the same time.',
      );
    }
  }

  final int sourceComponentId;
  final int targetComponentId;
  final double centroidDistance;
  final double boundingBoxDistance;
  final VisionRelativeDirection relativeDirection;
  final bool boundingBoxesTouch;
  final bool boundingBoxesIntersect;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionComponentRelation &&
            other.sourceComponentId == sourceComponentId &&
            other.targetComponentId == targetComponentId &&
            other.centroidDistance == centroidDistance &&
            other.boundingBoxDistance == boundingBoxDistance &&
            other.relativeDirection == relativeDirection &&
            other.boundingBoxesTouch == boundingBoxesTouch &&
            other.boundingBoxesIntersect == boundingBoxesIntersect;
  }

  @override
  int get hashCode => Object.hash(
    sourceComponentId,
    targetComponentId,
    centroidDistance,
    boundingBoxDistance,
    relativeDirection,
    boundingBoxesTouch,
    boundingBoxesIntersect,
  );

  @override
  String toString() {
    return 'VisionComponentRelation(sourceComponentId: $sourceComponentId, '
        'targetComponentId: $targetComponentId, '
        'centroidDistance: $centroidDistance, '
        'boundingBoxDistance: $boundingBoxDistance, '
        'relativeDirection: $relativeDirection, '
        'boundingBoxesTouch: $boundingBoxesTouch, '
        'boundingBoxesIntersect: $boundingBoxesIntersect)';
  }

  static int _validatedId(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
    return value;
  }

  static double _validatedDistance(double value, String name) {
    if (!value.isFinite || value < 0.0) {
      throw ArgumentError.value(value, name, 'must be finite and non-negative');
    }
    return value;
  }
}
