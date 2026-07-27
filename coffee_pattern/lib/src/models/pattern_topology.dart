/// Immutable structure-level topology of one physical pattern.
///
/// The values are a direct projection of canonical public Vision connected
/// structure evidence. This model does not reconstruct or analyze a graph.
final class PatternTopology {
  PatternTopology({required int nodeCount, required int directedEdgeCount})
    : nodeCount = _validateNodeCount(nodeCount),
      directedEdgeCount = _validateDirectedEdgeCount(
        nodeCount: nodeCount,
        directedEdgeCount: directedEdgeCount,
      );

  /// Number of canonical component nodes in the connected structure.
  final int nodeCount;

  /// Number of canonical selected directed edges within the structure.
  final int directedEdgeCount;

  /// Whether the structure contains one node and no directed edges.
  bool get isIsolated => nodeCount == 1 && directedEdgeCount == 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatternTopology &&
            other.nodeCount == nodeCount &&
            other.directedEdgeCount == directedEdgeCount;
  }

  @override
  int get hashCode => Object.hash(nodeCount, directedEdgeCount);

  @override
  String toString() {
    return 'PatternTopology(nodeCount: $nodeCount, '
        'directedEdgeCount: $directedEdgeCount, '
        'isIsolated: $isIsolated)';
  }

  static int _validateNodeCount(int value) {
    if (value < 1) {
      throw ArgumentError.value(
        value,
        'nodeCount',
        'must be greater than zero',
      );
    }
    return value;
  }

  static int _validateDirectedEdgeCount({
    required int nodeCount,
    required int directedEdgeCount,
  }) {
    if (directedEdgeCount < 0) {
      throw ArgumentError.value(
        directedEdgeCount,
        'directedEdgeCount',
        'must not be negative',
      );
    }
    final maximum = nodeCount * (nodeCount - 1);
    if (directedEdgeCount > maximum) {
      throw ArgumentError.value(
        directedEdgeCount,
        'directedEdgeCount',
        'must not exceed $maximum for $nodeCount nodes',
      );
    }
    return directedEdgeCount;
  }
}
