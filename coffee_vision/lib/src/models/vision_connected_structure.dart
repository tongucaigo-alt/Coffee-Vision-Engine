/// Immutable summary of one weakly connected spatial-graph structure.
final class VisionConnectedStructure {
  factory VisionConnectedStructure({
    required int id,
    required Iterable<int> componentIds,
    required int directedEdgeCount,
  }) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be greater than zero');
    }
    if (directedEdgeCount < 0) {
      throw ArgumentError.value(
        directedEdgeCount,
        'directedEdgeCount',
        'must not be negative',
      );
    }

    final ids = componentIds.toList()..sort();
    if (ids.isEmpty) {
      throw ArgumentError.value(
        componentIds,
        'componentIds',
        'must not be empty',
      );
    }
    final uniqueIds = <int>{};
    for (final componentId in ids) {
      if (componentId <= 0) {
        throw ArgumentError.value(
          componentId,
          'componentIds',
          'must contain only positive component ids',
        );
      }
      if (!uniqueIds.add(componentId)) {
        throw ArgumentError.value(
          componentId,
          'componentIds',
          'must not contain duplicate component ids',
        );
      }
    }

    final maximumDirectedEdgeCount = ids.length * (ids.length - 1);
    if (directedEdgeCount > maximumDirectedEdgeCount) {
      throw ArgumentError.value(
        directedEdgeCount,
        'directedEdgeCount',
        'must not exceed $maximumDirectedEdgeCount for ${ids.length} '
            'components',
      );
    }

    return VisionConnectedStructure._(
      id: id,
      componentIds: List<int>.unmodifiable(ids),
      directedEdgeCount: directedEdgeCount,
    );
  }

  VisionConnectedStructure._({
    required this.id,
    required this.componentIds,
    required this.directedEdgeCount,
  }) : componentCount = componentIds.length,
       isIsolated = componentIds.length == 1 && directedEdgeCount == 0;

  /// Deterministic, one-based identity within one analysis result.
  final int id;
  final List<int> componentIds;
  final int componentCount;
  final int directedEdgeCount;
  final bool isIsolated;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionConnectedStructure &&
            other.id == id &&
            other.directedEdgeCount == directedEdgeCount &&
            _sameIds(other.componentIds, componentIds);
  }

  @override
  int get hashCode =>
      Object.hash(id, directedEdgeCount, Object.hashAll(componentIds));

  @override
  String toString() {
    return 'VisionConnectedStructure(id: $id, '
        'componentCount: $componentCount, '
        'directedEdgeCount: $directedEdgeCount, '
        'isIsolated: $isIsolated)';
  }

  static bool _sameIds(List<int> first, List<int> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
