import 'vision_component_relation.dart';

/// Immutable ordered component relations and source-based nearest neighbors.
final class VisionComponentRelationResult {
  factory VisionComponentRelationResult({
    required Iterable<VisionComponentRelation> relations,
    required Map<int, int?> nearestNeighborByComponentId,
  }) {
    final nearestKeys = nearestNeighborByComponentId.keys.toList()..sort();
    final nearest = <int, int?>{};
    for (final sourceId in nearestKeys) {
      if (sourceId <= 0) {
        throw ArgumentError.value(
          sourceId,
          'nearestNeighborByComponentId',
          'must contain only positive component ids',
        );
      }
      nearest[sourceId] = nearestNeighborByComponentId[sourceId];
    }
    for (final entry in nearest.entries) {
      final targetId = entry.value;
      if (targetId == null) continue;
      if (targetId <= 0 ||
          targetId == entry.key ||
          !nearest.containsKey(targetId)) {
        throw ArgumentError.value(
          targetId,
          'nearestNeighborByComponentId',
          'must reference a different component contained in the result',
        );
      }
    }

    final relationList = relations.toList()
      ..sort((first, second) {
        final sourceComparison = first.sourceComponentId.compareTo(
          second.sourceComponentId,
        );
        if (sourceComparison != 0) return sourceComparison;
        return first.targetComponentId.compareTo(second.targetComponentId);
      });
    final relationPairs = <({int source, int target})>{};
    for (final relation in relationList) {
      if (!nearest.containsKey(relation.sourceComponentId) ||
          !nearest.containsKey(relation.targetComponentId)) {
        throw ArgumentError.value(
          relation,
          'relations',
          'must reference components contained in the nearest-neighbor map',
        );
      }
      final pair = (
        source: relation.sourceComponentId,
        target: relation.targetComponentId,
      );
      if (!relationPairs.add(pair)) {
        throw ArgumentError.value(
          relation,
          'relations',
          'must not contain duplicate directed component pairs',
        );
      }
    }

    return VisionComponentRelationResult._(
      relations: List<VisionComponentRelation>.unmodifiable(relationList),
      nearestNeighborByComponentId: Map<int, int?>.unmodifiable(nearest),
    );
  }

  VisionComponentRelationResult._({
    required this.relations,
    required this.nearestNeighborByComponentId,
  });

  final List<VisionComponentRelation> relations;
  final Map<int, int?> nearestNeighborByComponentId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionComponentRelationResult &&
            _sameRelations(other.relations, relations) &&
            _sameNearestNeighbors(
              other.nearestNeighborByComponentId,
              nearestNeighborByComponentId,
            );
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(relations),
    Object.hashAll(
      nearestNeighborByComponentId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );

  @override
  String toString() {
    return 'VisionComponentRelationResult('
        'relationCount: ${relations.length}, '
        'nearestNeighborByComponentId: $nearestNeighborByComponentId)';
  }

  static bool _sameRelations(
    List<VisionComponentRelation> first,
    List<VisionComponentRelation> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _sameNearestNeighbors(
    Map<int, int?> first,
    Map<int, int?> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
