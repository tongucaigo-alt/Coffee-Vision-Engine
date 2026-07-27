import 'vision_component.dart';
import 'vision_component_relation.dart';
import 'vision_component_relation_result.dart';
import 'vision_component_result.dart';

/// Immutable organization of validated components and directed relations.
///
/// This graph is an organization layer, not an analysis layer. It preserves
/// existing component and relation objects without adding, removing, changing,
/// or inferring relations. Higher-level graph analysis belongs in separate
/// analyzers that consume this model.
final class VisionSpatialGraph {
  VisionSpatialGraph._({
    required Iterable<VisionComponent> components,
    required Iterable<VisionComponentRelation> relations,
    required Map<int, Iterable<int>> adjacency,
  }) : components = List<VisionComponent>.unmodifiable(components),
       relations = List<VisionComponentRelation>.unmodifiable(relations),
       adjacency = Map<int, List<int>>.unmodifiable({
         for (final entry in adjacency.entries)
           entry.key: List<int>.unmodifiable(entry.value),
       });

  final List<VisionComponent> components;
  final List<VisionComponentRelation> relations;
  final Map<int, List<int>> adjacency;

  /// Returns outgoing relation targets for [componentId].
  List<int> neighborIdsOf(int componentId) {
    return adjacency[componentId] ??
        (throw ArgumentError.value(
          componentId,
          'componentId',
          'does not exist in this spatial graph',
        ));
  }

  /// Returns the number of existing outgoing relations for [componentId].
  int degreeOf(int componentId) => neighborIdsOf(componentId).length;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionSpatialGraph &&
            _sameList(other.components, components) &&
            _sameList(other.relations, relations) &&
            _sameAdjacency(other.adjacency, adjacency);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(components),
    Object.hashAll(relations),
    Object.hashAll(
      adjacency.entries.map(
        (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
      ),
    ),
  );

  @override
  String toString() {
    return 'VisionSpatialGraph(componentCount: ${components.length}, '
        'relationCount: ${relations.length})';
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _sameAdjacency(
    Map<int, List<int>> first,
    Map<int, List<int>> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      final otherNeighbors = second[entry.key];
      if (otherNeighbors == null || !_sameList(otherNeighbors, entry.value)) {
        return false;
      }
    }
    return true;
  }
}

/// Internal organizer for the Atlas graph representation.
///
/// It validates and indexes existing data only. It must not perform graph
/// analysis, infer connections, or repair incomplete relation results.
final class SpatialGraphOrganizer {
  const SpatialGraphOrganizer();

  VisionSpatialGraph organize({
    required VisionComponentResult componentResult,
    required VisionComponentRelationResult relationResult,
  }) {
    return _organize(
      componentResult: componentResult,
      relations: relationResult.relations,
      requiredNearestIds: relationResult.nearestNeighborByComponentId.keys
          .toSet(),
      requireCompleteRelations: true,
    );
  }

  VisionSpatialGraph organizeSparse({
    required VisionComponentResult componentResult,
    required Iterable<VisionComponentRelation> relations,
  }) {
    return _organize(
      componentResult: componentResult,
      relations: relations,
      requireCompleteRelations: false,
    );
  }

  VisionSpatialGraph _organize({
    required VisionComponentResult componentResult,
    required Iterable<VisionComponentRelation> relations,
    required bool requireCompleteRelations,
    Set<int>? requiredNearestIds,
  }) {
    final components = componentResult.components.toList()
      ..sort((first, second) => first.id.compareTo(second.id));
    final componentIds = <int>{};
    for (final component in components) {
      if (!componentIds.add(component.id)) {
        throw ArgumentError.value(
          component.id,
          'componentResult',
          'must contain unique component ids',
        );
      }
    }

    if (requiredNearestIds != null &&
        !_sameIds(componentIds, requiredNearestIds)) {
      throw ArgumentError.value(
        requiredNearestIds,
        'requiredNearestIds',
        'nearest-neighbor keys must exactly match component ids',
      );
    }

    final relationList = relations.toList()
      ..sort((first, second) {
        final sourceComparison = first.sourceComponentId.compareTo(
          second.sourceComponentId,
        );
        if (sourceComparison != 0) return sourceComparison;
        return first.targetComponentId.compareTo(second.targetComponentId);
      });
    final expectedRelationCount = components.length * (components.length - 1);
    if (requireCompleteRelations &&
        relationList.length != expectedRelationCount) {
      throw ArgumentError.value(
        relationList.length,
        'relations',
        'must contain exactly $expectedRelationCount directed relations',
      );
    }

    final relationPairs = <({int source, int target})>{};
    final adjacency = <int, List<int>>{
      for (final component in components) component.id: <int>[],
    };
    for (final relation in relationList) {
      final sourceId = relation.sourceComponentId;
      final targetId = relation.targetComponentId;
      if (!componentIds.contains(sourceId) ||
          !componentIds.contains(targetId)) {
        throw ArgumentError.value(
          relation,
          'relationResult',
          'relations must reference only supplied components',
        );
      }
      if (sourceId == targetId) {
        throw ArgumentError.value(
          relation,
          'relationResult',
          'self relations are not allowed',
        );
      }
      final pair = (source: sourceId, target: targetId);
      if (!relationPairs.add(pair)) {
        throw ArgumentError.value(
          relation,
          'relationResult',
          'directed relation pairs must be unique',
        );
      }
      adjacency[sourceId]!.add(targetId);
    }

    if (requireCompleteRelations) {
      for (final sourceId in componentIds) {
        for (final targetId in componentIds) {
          if (sourceId == targetId) continue;
          if (!relationPairs.contains((source: sourceId, target: targetId))) {
            throw ArgumentError.value(
              relationList,
              'relations',
              'must contain every directed pair exactly once',
            );
          }
        }
      }
    }

    var adjacencyRelationCount = 0;
    for (final neighbors in adjacency.values) {
      neighbors.sort();
      adjacencyRelationCount += neighbors.length;
    }
    if (adjacencyRelationCount != relationList.length) {
      throw ArgumentError.value(
        relationList,
        'relations',
        'every relation must have exactly one adjacency entry',
      );
    }

    return VisionSpatialGraph._(
      components: components,
      relations: relationList,
      adjacency: adjacency,
    );
  }

  static bool _sameIds(Set<int> first, Set<int> second) {
    return first.length == second.length && first.containsAll(second);
  }
}
