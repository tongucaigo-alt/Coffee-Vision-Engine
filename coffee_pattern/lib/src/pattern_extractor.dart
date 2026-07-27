import 'package:coffee_vision/coffee_vision.dart';

import 'models/pattern_candidate.dart';
import 'models/pattern_evidence.dart';
import 'models/pattern_geometry.dart';
import 'models/pattern_topology.dart';

/// Internal deterministic projection from complete Vision features to patterns.
///
/// This extractor reads canonical identities only. It performs no Vision
/// analysis and does not copy physical measurements into Pattern contracts.
final class PatternExtractor {
  const PatternExtractor();

  List<PatternCandidate> extract(VisionFeatureSet featureSet) {
    final components = featureSet.componentFeatures.toList(
      growable: false,
    )..sort((first, second) => first.componentId.compareTo(second.componentId));
    final componentIds = components
        .map((component) => component.componentId)
        .toList(growable: false);
    _validateComponentIds(componentIds);
    final componentsById = <int, VisionComponentFeature>{
      for (final component in components) component.componentId: component,
    };

    final structureResult = featureSet.connectedStructureResult;
    if (structureResult == null) {
      throw StateError('A complete FeatureSet must contain structures.');
    }
    final structures = structureResult.structures.toList(growable: false)
      ..sort((first, second) => first.id.compareTo(second.id));

    if (structures.isEmpty) {
      if (componentIds.isNotEmpty) {
        throw StateError(
          'A complete FeatureSet must assign every component to a structure.',
        );
      }
      return const [];
    }

    final knownComponentIds = componentIds.toSet();
    final assignedComponentIds = <int>{};
    final candidates = <PatternCandidate>[];

    for (var index = 0; index < structures.length; index++) {
      final structure = structures[index];
      final expectedId = index + 1;
      if (structure.id != expectedId) {
        throw StateError(
          'Structure IDs must follow canonical one-based order.',
        );
      }

      final memberIds = structure.componentIds.toList(growable: false)..sort();
      if (memberIds.isEmpty) {
        throw StateError('A structure must contain at least one component.');
      }

      final evidence = <PatternEvidence>[];
      final memberComponents = <VisionComponentFeature>[];
      int? previousMemberId;
      for (final memberId in memberIds) {
        if (memberId <= 0) {
          throw StateError('Structure component IDs must be positive.');
        }
        if (previousMemberId == memberId) {
          throw StateError(
            'A structure must not contain duplicate component IDs.',
          );
        }
        previousMemberId = memberId;

        if (!knownComponentIds.contains(memberId)) {
          throw StateError(
            'A structure references an unknown component identity.',
          );
        }
        if (!assignedComponentIds.add(memberId)) {
          throw StateError(
            'A component identity must belong to exactly one structure.',
          );
        }
        memberComponents.add(componentsById[memberId]!);
        evidence.add(PatternEvidence.componentFeature(memberId));
      }

      evidence.add(PatternEvidence.connectedStructure(structure.id));
      final topology = PatternTopology(
        nodeCount: structure.componentCount,
        directedEdgeCount: structure.directedEdgeCount,
      );
      if (topology.isIsolated != structure.isIsolated) {
        throw StateError(
          'Pattern topology must preserve canonical structure isolation.',
        );
      }
      if (topology.nodeCount != memberComponents.length) {
        throw StateError(
          'Pattern topology node count must match canonical membership.',
        );
      }

      candidates.add(
        PatternCandidate.withGeometryAndTopology(
          id: structure.id,
          evidence: evidence,
          geometry: _createGeometry(memberComponents),
          topology: topology,
        ),
      );
    }

    if (assignedComponentIds.length != knownComponentIds.length) {
      throw StateError(
        'A complete FeatureSet must assign every component to a structure.',
      );
    }

    return List<PatternCandidate>.unmodifiable(candidates);
  }

  static PatternGeometry _createGeometry(
    List<VisionComponentFeature> components,
  ) {
    var left = components.first.boundingBox.left;
    var top = components.first.boundingBox.top;
    var right = components.first.boundingBox.right;
    var bottom = components.first.boundingBox.bottom;
    var totalPixelCount = 0;
    var weightedCentroidX = 0.0;
    var weightedCentroidY = 0.0;

    for (final component in components) {
      final boundingBox = component.boundingBox;
      if (boundingBox.left < left) left = boundingBox.left;
      if (boundingBox.top < top) top = boundingBox.top;
      if (boundingBox.right > right) right = boundingBox.right;
      if (boundingBox.bottom > bottom) bottom = boundingBox.bottom;

      totalPixelCount += component.pixelCount;
      weightedCentroidX += component.centroid.x * component.pixelCount;
      weightedCentroidY += component.centroid.y * component.pixelCount;
    }

    if (totalPixelCount <= 0) {
      throw StateError('Pattern geometry requires positive residue evidence.');
    }

    return PatternGeometry(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      centroidX: weightedCentroidX / totalPixelCount,
      centroidY: weightedCentroidY / totalPixelCount,
    );
  }

  static void _validateComponentIds(List<int> componentIds) {
    int? previousId;
    for (final componentId in componentIds) {
      if (componentId <= 0) {
        throw StateError('Component IDs must be positive.');
      }
      if (componentId == previousId) {
        throw StateError('Component IDs must be unique.');
      }
      previousId = componentId;
    }
  }
}
