/// Immutable configuration for deterministic directed edge selection.
final class VisionEdgeSelectionProfile {
  const VisionEdgeSelectionProfile({
    this.maxCentroidDistance,
    this.maxBoundingBoxDistance,
    this.requireBoundingBoxTouch = false,
    this.maxOutgoingPerSource,
  }) : assert(
         maxCentroidDistance == null ||
             (maxCentroidDistance >= 0.0 &&
                 maxCentroidDistance <= double.maxFinite),
         'maxCentroidDistance must be finite and non-negative',
       ),
       assert(
         maxBoundingBoxDistance == null ||
             (maxBoundingBoxDistance >= 0.0 &&
                 maxBoundingBoxDistance <= double.maxFinite),
         'maxBoundingBoxDistance must be finite and non-negative',
       ),
       assert(
         maxOutgoingPerSource == null || maxOutgoingPerSource >= 0,
         'maxOutgoingPerSource must be non-negative',
       );

  final double? maxCentroidDistance;
  final double? maxBoundingBoxDistance;
  final bool requireBoundingBoxTouch;
  final int? maxOutgoingPerSource;

  bool get isPassThrough =>
      maxCentroidDistance == null &&
      maxBoundingBoxDistance == null &&
      !requireBoundingBoxTouch &&
      maxOutgoingPerSource == null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionEdgeSelectionProfile &&
            other.maxCentroidDistance == maxCentroidDistance &&
            other.maxBoundingBoxDistance == maxBoundingBoxDistance &&
            other.requireBoundingBoxTouch == requireBoundingBoxTouch &&
            other.maxOutgoingPerSource == maxOutgoingPerSource;
  }

  @override
  int get hashCode => Object.hash(
    maxCentroidDistance,
    maxBoundingBoxDistance,
    requireBoundingBoxTouch,
    maxOutgoingPerSource,
  );

  @override
  String toString() {
    return 'VisionEdgeSelectionProfile('
        'maxCentroidDistance: $maxCentroidDistance, '
        'maxBoundingBoxDistance: $maxBoundingBoxDistance, '
        'requireBoundingBoxTouch: $requireBoundingBoxTouch, '
        'maxOutgoingPerSource: $maxOutgoingPerSource)';
  }
}
