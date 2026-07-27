/// Immutable statistical summary of a [VisionSpatialGraph].
///
/// This model contains aggregate values only. It does not retain or mutate
/// graph, component, or relation objects.
final class VisionGraphStatistics {
  VisionGraphStatistics({
    required int componentCount,
    required int relationCount,
    required int isolatedComponentCount,
    required int minDegree,
    required int maxDegree,
    required double averageDegree,
  }) : componentCount = _validateCount(componentCount, 'componentCount'),
       relationCount = _validateCount(relationCount, 'relationCount'),
       isolatedComponentCount = _validateCount(
         isolatedComponentCount,
         'isolatedComponentCount',
       ),
       minDegree = _validateCount(minDegree, 'minDegree'),
       maxDegree = _validateCount(maxDegree, 'maxDegree'),
       averageDegree = _validateAverage(averageDegree) {
    if (isolatedComponentCount > componentCount) {
      throw ArgumentError.value(
        isolatedComponentCount,
        'isolatedComponentCount',
        'must not exceed componentCount',
      );
    }
    if (minDegree > maxDegree) {
      throw ArgumentError.value(
        minDegree,
        'minDegree',
        'must not exceed maxDegree',
      );
    }
    if (componentCount == 0 &&
        (relationCount != 0 ||
            isolatedComponentCount != 0 ||
            minDegree != 0 ||
            maxDegree != 0 ||
            averageDegree != 0.0)) {
      throw ArgumentError(
        'An empty graph must have zero relation and degree statistics.',
      );
    }
    if (componentCount > 0 &&
        (averageDegree < minDegree || averageDegree > maxDegree)) {
      throw ArgumentError.value(
        averageDegree,
        'averageDegree',
        'must be between minDegree and maxDegree',
      );
    }
  }

  final int componentCount;
  final int relationCount;
  final int isolatedComponentCount;
  final int minDegree;
  final int maxDegree;
  final double averageDegree;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionGraphStatistics &&
            other.componentCount == componentCount &&
            other.relationCount == relationCount &&
            other.isolatedComponentCount == isolatedComponentCount &&
            other.minDegree == minDegree &&
            other.maxDegree == maxDegree &&
            other.averageDegree == averageDegree;
  }

  @override
  int get hashCode => Object.hash(
    componentCount,
    relationCount,
    isolatedComponentCount,
    minDegree,
    maxDegree,
    averageDegree,
  );

  @override
  String toString() {
    return 'VisionGraphStatistics(componentCount: $componentCount, '
        'relationCount: $relationCount, '
        'isolatedComponentCount: $isolatedComponentCount, '
        'minDegree: $minDegree, maxDegree: $maxDegree, '
        'averageDegree: $averageDegree)';
  }

  static int _validateCount(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must not be negative');
    }
    return value;
  }

  static double _validateAverage(double value) {
    if (!value.isFinite || value < 0.0) {
      throw ArgumentError.value(
        value,
        'averageDegree',
        'must be finite and non-negative',
      );
    }
    return value;
  }
}
