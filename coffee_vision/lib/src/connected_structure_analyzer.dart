import 'dart:collection';

import 'models/vision_connected_structure.dart';
import 'models/vision_connected_structure_result.dart';
import 'models/vision_spatial_graph.dart';

/// Finds weakly connected structures without mutating or extending the graph.
final class ConnectedStructureAnalyzer {
  const ConnectedStructureAnalyzer();

  VisionConnectedStructureResult analyze(VisionSpatialGraph graph) {
    final componentIds = graph.components
        .map((component) => component.id)
        .toList(growable: false);
    if (componentIds.isEmpty) {
      return VisionConnectedStructureResult(structures: const []);
    }

    final outgoing = <int, List<int>>{
      for (final componentId in componentIds) componentId: <int>[],
    };
    final incoming = <int, List<int>>{
      for (final componentId in componentIds) componentId: <int>[],
    };
    for (final relation in graph.relations) {
      outgoing[relation.sourceComponentId]!.add(relation.targetComponentId);
      incoming[relation.targetComponentId]!.add(relation.sourceComponentId);
    }

    final weakAdjacency = <int, List<int>>{
      for (final componentId in componentIds)
        componentId: _mergeDistinctSorted(
          outgoing[componentId]!,
          incoming[componentId]!,
        ),
    };

    final visited = <int>{};
    final memberships = <List<int>>[];
    for (final seedId in componentIds) {
      if (!visited.add(seedId)) continue;

      final queue = ListQueue<int>()..add(seedId);
      final memberIds = <int>[];
      while (queue.isNotEmpty) {
        final componentId = queue.removeFirst();
        memberIds.add(componentId);
        for (final neighborId in weakAdjacency[componentId]!) {
          if (visited.add(neighborId)) queue.add(neighborId);
        }
      }
      memberIds.sort();
      memberships.add(memberIds);
    }

    memberships.sort((first, second) => first.first.compareTo(second.first));
    final membershipIndexByComponentId = <int, int>{};
    for (var index = 0; index < memberships.length; index++) {
      for (final componentId in memberships[index]) {
        membershipIndexByComponentId[componentId] = index;
      }
    }

    final directedEdgeCounts = List<int>.filled(memberships.length, 0);
    for (final relation in graph.relations) {
      final sourceIndex =
          membershipIndexByComponentId[relation.sourceComponentId]!;
      assert(
        membershipIndexByComponentId[relation.targetComponentId] == sourceIndex,
        'Every relation must remain local to one weak structure.',
      );
      directedEdgeCounts[sourceIndex]++;
    }

    return VisionConnectedStructureResult(
      structures: [
        for (var index = 0; index < memberships.length; index++)
          VisionConnectedStructure(
            id: index + 1,
            componentIds: memberships[index],
            directedEdgeCount: directedEdgeCounts[index],
          ),
      ],
    );
  }

  static List<int> _mergeDistinctSorted(
    List<int> outgoing,
    List<int> incoming,
  ) {
    final merged = <int>[];
    var outgoingIndex = 0;
    var incomingIndex = 0;
    while (outgoingIndex < outgoing.length || incomingIndex < incoming.length) {
      final hasOutgoing = outgoingIndex < outgoing.length;
      final hasIncoming = incomingIndex < incoming.length;
      late final int next;
      if (!hasIncoming ||
          (hasOutgoing && outgoing[outgoingIndex] < incoming[incomingIndex])) {
        next = outgoing[outgoingIndex++];
      } else if (!hasOutgoing ||
          incoming[incomingIndex] < outgoing[outgoingIndex]) {
        next = incoming[incomingIndex++];
      } else {
        next = outgoing[outgoingIndex++];
        incomingIndex++;
      }
      if (merged.isEmpty || merged.last != next) merged.add(next);
    }
    return List<int>.unmodifiable(merged);
  }
}
