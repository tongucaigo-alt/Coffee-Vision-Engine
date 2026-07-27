import 'vision_connected_structure.dart';

/// Immutable result of weakly connected structure analysis.
final class VisionConnectedStructureResult {
  factory VisionConnectedStructureResult({
    required Iterable<VisionConnectedStructure> structures,
  }) {
    final structureList = structures.toList()
      ..sort(
        (first, second) =>
            first.componentIds.first.compareTo(second.componentIds.first),
      );

    final assignedComponentIds = <int>{};
    var largestStructureSize = 0;
    var isolatedStructureCount = 0;
    for (var index = 0; index < structureList.length; index++) {
      final structure = structureList[index];
      final expectedId = index + 1;
      if (structure.id != expectedId) {
        throw ArgumentError.value(
          structure.id,
          'structures',
          'structure ids must follow canonical one-based result order; '
              'expected $expectedId',
        );
      }
      for (final componentId in structure.componentIds) {
        if (!assignedComponentIds.add(componentId)) {
          throw ArgumentError.value(
            componentId,
            'structures',
            'a component id must belong to exactly one structure',
          );
        }
      }
      if (structure.componentCount > largestStructureSize) {
        largestStructureSize = structure.componentCount;
      }
      if (structure.isIsolated) isolatedStructureCount++;
    }

    return VisionConnectedStructureResult._(
      structures: List<VisionConnectedStructure>.unmodifiable(structureList),
      largestStructureSize: largestStructureSize,
      isolatedStructureCount: isolatedStructureCount,
    );
  }

  VisionConnectedStructureResult._({
    required this.structures,
    required this.largestStructureSize,
    required this.isolatedStructureCount,
  }) : structureCount = structures.length;

  final List<VisionConnectedStructure> structures;
  final int structureCount;
  final int largestStructureSize;
  final int isolatedStructureCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionConnectedStructureResult &&
            _sameStructures(other.structures, structures);
  }

  @override
  int get hashCode => Object.hashAll(structures);

  @override
  String toString() {
    return 'VisionConnectedStructureResult('
        'structureCount: $structureCount, '
        'largestStructureSize: $largestStructureSize, '
        'isolatedStructureCount: $isolatedStructureCount)';
  }

  static bool _sameStructures(
    List<VisionConnectedStructure> first,
    List<VisionConnectedStructure> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
