import 'vision_feature_image_provenance.dart';
import 'vision_global_features.dart';
import 'vision_analysis_region.dart';
import 'vision_component_feature.dart';
import 'vision_connected_structure_result.dart';
import 'vision_edge_selection_profile.dart';
import 'vision_edge_selection_decision.dart';
import 'vision_graph_statistics.dart';
import 'vision_image_input.dart';
import 'vision_region_feature.dart';
import 'vision_spatial_relation_feature.dart';

/// The terminal physical-measurement contract of Coffee Vision.
///
/// [CoffeeVisionEngine.analyzeFeatures] is the canonical construction path for
/// a complete M7 feature set. The unnamed constructor and the M7B/M7C factories
/// remain available only as additive compatibility paths and intentionally
/// leave features from later milestones empty or null.
///
/// This model must never contain symbols, semantic interpretation, AI output,
/// or fortune meaning. After M7 is declared stable, later semantic layers must
/// consume complete engine-produced feature sets rather than
/// [VisionPipelineResult].
final class VisionFeatureSet {
  /// Creates the legacy M7A metadata-only contract.
  const VisionFeatureSet({
    required this.surfaceType,
    this.sourceId,
    required this.imageProvenance,
  }) : globalFeatures = null,
       regionFeatures = const [],
       componentFeatures = const [],
       edgeSelectionProfile = null,
       spatialRelationFeatures = const [],
       graphStatistics = null,
       connectedStructureResult = null;

  /// Creates the legacy M7B contract without component or connectivity data.
  factory VisionFeatureSet.withGlobalAndRegionalFeatures({
    required VisionSurfaceType surfaceType,
    String? sourceId,
    required VisionFeatureImageProvenance imageProvenance,
    required VisionGlobalFeatures globalFeatures,
    required Iterable<VisionRegionFeature> regionFeatures,
  }) {
    final canonicalRegions = _validatedCanonicalRegions(regionFeatures);
    return VisionFeatureSet._(
      surfaceType: surfaceType,
      sourceId: sourceId,
      imageProvenance: imageProvenance,
      globalFeatures: globalFeatures,
      regionFeatures: canonicalRegions,
      componentFeatures: const [],
      edgeSelectionProfile: null,
      spatialRelationFeatures: const [],
      graphStatistics: null,
      connectedStructureResult: null,
    );
  }

  /// Creates the legacy M7C contract without spatial or connectivity data.
  factory VisionFeatureSet.withComponentFeatures({
    required VisionSurfaceType surfaceType,
    String? sourceId,
    required VisionFeatureImageProvenance imageProvenance,
    required VisionGlobalFeatures globalFeatures,
    required Iterable<VisionRegionFeature> regionFeatures,
    required Iterable<VisionComponentFeature> componentFeatures,
  }) {
    final canonicalRegions = _validatedCanonicalRegions(regionFeatures);
    final canonicalComponents = _validatedCanonicalComponents(
      componentFeatures,
      globalFeatures,
    );
    return VisionFeatureSet._(
      surfaceType: surfaceType,
      sourceId: sourceId,
      imageProvenance: imageProvenance,
      globalFeatures: globalFeatures,
      regionFeatures: canonicalRegions,
      componentFeatures: canonicalComponents,
      edgeSelectionProfile: null,
      spatialRelationFeatures: const [],
      graphStatistics: null,
      connectedStructureResult: null,
    );
  }

  /// Creates the complete M7 physical feature contract.
  factory VisionFeatureSet.withSpatialAndConnectivityFeatures({
    required VisionSurfaceType surfaceType,
    String? sourceId,
    required VisionFeatureImageProvenance imageProvenance,
    required VisionGlobalFeatures globalFeatures,
    required Iterable<VisionRegionFeature> regionFeatures,
    required Iterable<VisionComponentFeature> componentFeatures,
    required VisionEdgeSelectionProfile edgeSelectionProfile,
    required Iterable<VisionSpatialRelationFeature> spatialRelationFeatures,
    required VisionGraphStatistics graphStatistics,
    required VisionConnectedStructureResult connectedStructureResult,
  }) {
    final canonicalRegions = _validatedCanonicalRegions(regionFeatures);
    final canonicalComponents = _validatedCanonicalComponents(
      componentFeatures,
      globalFeatures,
    );
    final canonicalRelations = _validatedCanonicalRelations(
      values: spatialRelationFeatures,
      componentFeatures: canonicalComponents,
      globalFeatures: globalFeatures,
      edgeSelectionProfile: edgeSelectionProfile,
    );
    _validateConnectivityResults(
      componentFeatures: canonicalComponents,
      globalFeatures: globalFeatures,
      graphStatistics: graphStatistics,
      connectedStructureResult: connectedStructureResult,
    );
    return VisionFeatureSet._(
      surfaceType: surfaceType,
      sourceId: sourceId,
      imageProvenance: imageProvenance,
      globalFeatures: globalFeatures,
      regionFeatures: canonicalRegions,
      componentFeatures: canonicalComponents,
      edgeSelectionProfile: edgeSelectionProfile,
      spatialRelationFeatures: canonicalRelations,
      graphStatistics: graphStatistics,
      connectedStructureResult: connectedStructureResult,
    );
  }

  const VisionFeatureSet._({
    required this.surfaceType,
    this.sourceId,
    required this.imageProvenance,
    required this.globalFeatures,
    required this.regionFeatures,
    required this.componentFeatures,
    required this.edgeSelectionProfile,
    required this.spatialRelationFeatures,
    required this.graphStatistics,
    required this.connectedStructureResult,
  });

  /// The physical surface represented by every projected feature.
  final VisionSurfaceType surfaceType;

  /// The caller-provided source identity, when one was supplied.
  final String? sourceId;

  /// Physical source and prepared-working-image provenance.
  final VisionFeatureImageProvenance imageProvenance;

  /// Existing global physical measurements, or null for the M7A contract.
  final VisionGlobalFeatures? globalFeatures;

  /// Canonically ordered regional measurements, empty for the M7A contract.
  final List<VisionRegionFeature> regionFeatures;

  /// Canonically ordered component measurements, empty before M7C.
  final List<VisionComponentFeature> componentFeatures;

  /// Existing edge-selection profile, or null before the complete M7 contract.
  final VisionEdgeSelectionProfile? edgeSelectionProfile;

  /// Canonically ordered directed-relation decisions, empty before M7D.
  final List<VisionSpatialRelationFeature> spatialRelationFeatures;

  /// Existing graph statistics, or null before the complete M7 contract.
  final VisionGraphStatistics? graphStatistics;

  /// Existing weak-connectivity result, or null before the complete contract.
  final VisionConnectedStructureResult? connectedStructureResult;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionFeatureSet &&
            other.surfaceType == surfaceType &&
            other.sourceId == sourceId &&
            other.imageProvenance == imageProvenance &&
            other.globalFeatures == globalFeatures &&
            _sameList(other.regionFeatures, regionFeatures) &&
            _sameList(other.componentFeatures, componentFeatures) &&
            other.edgeSelectionProfile == edgeSelectionProfile &&
            _sameList(other.spatialRelationFeatures, spatialRelationFeatures) &&
            other.graphStatistics == graphStatistics &&
            other.connectedStructureResult == connectedStructureResult;
  }

  @override
  int get hashCode => Object.hash(
    surfaceType,
    sourceId,
    imageProvenance,
    globalFeatures,
    Object.hashAll(regionFeatures),
    Object.hashAll(componentFeatures),
    edgeSelectionProfile,
    Object.hashAll(spatialRelationFeatures),
    graphStatistics,
    connectedStructureResult,
  );

  @override
  String toString() {
    return 'VisionFeatureSet(surfaceType: $surfaceType, '
        'sourceIdPresent: ${sourceId != null}, '
        'imageProvenance: $imageProvenance, '
        'globalFeaturesPresent: ${globalFeatures != null}, '
        'regionFeatureCount: ${regionFeatures.length}, '
        'componentFeatureCount: ${componentFeatures.length}, '
        'spatialRelationFeatureCount: ${spatialRelationFeatures.length}, '
        'connectivityFeaturesPresent: '
        '${graphStatistics != null && connectedStructureResult != null})';
  }

  static List<VisionRegionFeature> _validatedCanonicalRegions(
    Iterable<VisionRegionFeature> values,
  ) {
    final byId = <VisionRegionId, VisionRegionFeature>{};
    for (final value in values) {
      if (byId.containsKey(value.regionId)) {
        throw ArgumentError.value(
          value.regionId,
          'regionFeatures',
          'must contain each VisionRegionId exactly once',
        );
      }
      byId[value.regionId] = value;
    }
    if (byId.length != VisionRegionId.values.length) {
      throw ArgumentError.value(
        byId.keys.toList(growable: false),
        'regionFeatures',
        'must contain all six canonical VisionRegionId values',
      );
    }
    return List<VisionRegionFeature>.unmodifiable(
      VisionRegionId.values.map((id) => byId[id]!),
    );
  }

  static List<VisionComponentFeature> _validatedCanonicalComponents(
    Iterable<VisionComponentFeature> values,
    VisionGlobalFeatures globalFeatures,
  ) {
    final byId = <int, VisionComponentFeature>{};
    for (final value in values) {
      if (byId.containsKey(value.componentId)) {
        throw ArgumentError.value(
          value.componentId,
          'componentFeatures',
          'must contain unique canonical component IDs',
        );
      }
      byId[value.componentId] = value;
    }

    final canonical = byId.values.toList()
      ..sort(
        (first, second) => first.componentId.compareTo(second.componentId),
      );
    if (canonical.length != globalFeatures.componentCount) {
      throw ArgumentError.value(
        canonical.length,
        'componentFeatures',
        'must match globalFeatures.componentCount',
      );
    }

    final pixelTotal = canonical.fold<int>(
      0,
      (total, feature) => total + feature.pixelCount,
    );
    if (pixelTotal != globalFeatures.residuePixelCount) {
      throw ArgumentError.value(
        pixelTotal,
        'componentFeatures',
        'pixel total must match globalFeatures.residuePixelCount',
      );
    }

    if (canonical.isEmpty) {
      return List<VisionComponentFeature>.unmodifiable(canonical);
    }

    final residuePixelCount = globalFeatures.residuePixelCount;
    if (residuePixelCount <= 0) {
      throw ArgumentError.value(
        residuePixelCount,
        'globalFeatures.residuePixelCount',
        'must be greater than zero when components exist',
      );
    }

    for (final feature in canonical) {
      final expectedShare = feature.pixelCount / residuePixelCount;
      if (feature.residueShare != expectedShare) {
        throw ArgumentError.value(
          feature.residueShare,
          'componentFeatures',
          'residueShare must equal pixelCount / residuePixelCount',
        );
      }
      final nearestId = feature.nearestNeighborComponentId;
      if (canonical.length == 1) {
        if (nearestId != null) {
          throw ArgumentError.value(
            nearestId,
            'componentFeatures',
            'a single component must have no nearest neighbor',
          );
        }
      } else if (nearestId == null || !byId.containsKey(nearestId)) {
        throw ArgumentError.value(
          nearestId,
          'componentFeatures',
          'nearest neighbor must reference another projected component',
        );
      }
    }

    return List<VisionComponentFeature>.unmodifiable(canonical);
  }

  static List<VisionSpatialRelationFeature> _validatedCanonicalRelations({
    required Iterable<VisionSpatialRelationFeature> values,
    required List<VisionComponentFeature> componentFeatures,
    required VisionGlobalFeatures globalFeatures,
    required VisionEdgeSelectionProfile edgeSelectionProfile,
  }) {
    final componentIds = componentFeatures
        .map((feature) => feature.componentId)
        .toSet();
    final canonical = values.toList()
      ..sort((first, second) {
        final sourceComparison = first.sourceComponentId.compareTo(
          second.sourceComponentId,
        );
        if (sourceComparison != 0) return sourceComparison;
        return first.targetComponentId.compareTo(second.targetComponentId);
      });

    final pairs = <({int source, int target})>{};
    var selectedCount = 0;
    for (final feature in canonical) {
      if (!componentIds.contains(feature.sourceComponentId) ||
          !componentIds.contains(feature.targetComponentId)) {
        throw ArgumentError.value(
          feature,
          'spatialRelationFeatures',
          'must reference only projected component IDs',
        );
      }
      if (feature.sourceComponentId == feature.targetComponentId) {
        throw ArgumentError.value(
          feature,
          'spatialRelationFeatures',
          'must not contain self relations',
        );
      }
      final pair = (
        source: feature.sourceComponentId,
        target: feature.targetComponentId,
      );
      if (!pairs.add(pair)) {
        throw ArgumentError.value(
          feature,
          'spatialRelationFeatures',
          'must not contain duplicate directed component pairs',
        );
      }
      _validateSelectionReason(edgeSelectionProfile, feature);
      if (feature.selected) selectedCount++;
    }

    final expectedCandidateCount =
        componentFeatures.length * (componentFeatures.length - 1);
    if (canonical.length != expectedCandidateCount ||
        canonical.length != globalFeatures.candidateRelationCount) {
      throw ArgumentError.value(
        canonical.length,
        'spatialRelationFeatures',
        'must contain every directed component pair exactly once and match '
            'globalFeatures.candidateRelationCount',
      );
    }
    for (final sourceId in componentIds) {
      for (final targetId in componentIds) {
        if (sourceId == targetId) continue;
        if (!pairs.contains((source: sourceId, target: targetId))) {
          throw ArgumentError.value(
            canonical,
            'spatialRelationFeatures',
            'must contain every directed component pair exactly once',
          );
        }
      }
    }
    if (selectedCount != globalFeatures.selectedRelationCount) {
      throw ArgumentError.value(
        selectedCount,
        'spatialRelationFeatures',
        'selected count must match globalFeatures.selectedRelationCount',
      );
    }

    return List<VisionSpatialRelationFeature>.unmodifiable(canonical);
  }

  static void _validateSelectionReason(
    VisionEdgeSelectionProfile profile,
    VisionSpatialRelationFeature feature,
  ) {
    if (profile.isPassThrough) {
      if (feature.selectionReason !=
          VisionEdgeSelectionReason.selectedByPassThrough) {
        throw ArgumentError.value(
          feature.selectionReason,
          'spatialRelationFeatures',
          'pass-through profiles require selectedByPassThrough decisions',
        );
      }
      return;
    }
    if (feature.selected &&
        feature.selectionReason !=
            VisionEdgeSelectionReason.selectedByActiveFilters) {
      throw ArgumentError.value(
        feature.selectionReason,
        'spatialRelationFeatures',
        'active profiles require selectedByActiveFilters for selected edges',
      );
    }
    if (feature.selectionReason ==
        VisionEdgeSelectionReason.selectedByPassThrough) {
      throw ArgumentError.value(
        feature.selectionReason,
        'spatialRelationFeatures',
        'selectedByPassThrough is valid only for pass-through profiles',
      );
    }
  }

  static void _validateConnectivityResults({
    required List<VisionComponentFeature> componentFeatures,
    required VisionGlobalFeatures globalFeatures,
    required VisionGraphStatistics graphStatistics,
    required VisionConnectedStructureResult connectedStructureResult,
  }) {
    if (graphStatistics.componentCount != globalFeatures.componentCount ||
        graphStatistics.relationCount != globalFeatures.selectedRelationCount) {
      throw ArgumentError.value(
        graphStatistics,
        'graphStatistics',
        'component and relation counts must match global features',
      );
    }

    final componentIds = componentFeatures
        .map((feature) => feature.componentId)
        .toSet();
    final structureComponentIds = <int>{};
    var directedEdgeCount = 0;
    for (final structure in connectedStructureResult.structures) {
      directedEdgeCount += structure.directedEdgeCount;
      for (final componentId in structure.componentIds) {
        if (!componentIds.contains(componentId) ||
            !structureComponentIds.add(componentId)) {
          throw ArgumentError.value(
            connectedStructureResult,
            'connectedStructureResult',
            'structures must reference each projected component exactly once',
          );
        }
      }
    }
    if (structureComponentIds.length != componentIds.length ||
        !componentIds.every(structureComponentIds.contains)) {
      throw ArgumentError.value(
        connectedStructureResult,
        'connectedStructureResult',
        'structures must cover all projected component IDs',
      );
    }
    if (directedEdgeCount != globalFeatures.selectedRelationCount) {
      throw ArgumentError.value(
        directedEdgeCount,
        'connectedStructureResult',
        'directed edge total must match selectedRelationCount',
      );
    }
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
