import 'residue_mask.dart';
import 'vision_analysis_region.dart';
import 'vision_component_result.dart';
import 'vision_component_relation_result.dart';
import 'vision_connected_structure_result.dart';
import 'vision_edge_selection_result.dart';
import 'vision_graph_statistics.dart';
import 'vision_image_input.dart';
import 'vision_region_density.dart';
import 'vision_spatial_graph.dart';
import 'working_image.dart';

/// Immutable output of the detailed Coffee Vision orchestration pipeline.
///
/// This model only collects existing analysis results. It does not add
/// interpretation, confidence, symbols, or fortune semantics.
final class VisionPipelineResult {
  VisionPipelineResult({
    required this.surfaceType,
    this.sourceId,
    required this.workingImage,
    required Iterable<VisionAnalysisRegion> analysisRegions,
    required Iterable<VisionRegionDensity> regionDensities,
    required this.residueMask,
    required this.componentResult,
    required this.relationResult,
    required this.edgeSelectionResult,
    required this.spatialGraph,
    required this.graphStatistics,
    required this.connectedStructureResult,
  }) : analysisRegions = List<VisionAnalysisRegion>.unmodifiable(
         analysisRegions,
       ),
       regionDensities = List<VisionRegionDensity>.unmodifiable(
         regionDensities,
       );

  final VisionSurfaceType surfaceType;
  final String? sourceId;
  final WorkingImage workingImage;
  final List<VisionAnalysisRegion> analysisRegions;
  final List<VisionRegionDensity> regionDensities;
  final ResidueMask residueMask;
  final VisionComponentResult componentResult;
  final VisionComponentRelationResult relationResult;
  final VisionEdgeSelectionResult edgeSelectionResult;
  final VisionSpatialGraph spatialGraph;
  final VisionGraphStatistics graphStatistics;
  final VisionConnectedStructureResult connectedStructureResult;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionPipelineResult &&
            other.surfaceType == surfaceType &&
            other.sourceId == sourceId &&
            other.workingImage == workingImage &&
            _sameList(other.analysisRegions, analysisRegions) &&
            _sameList(other.regionDensities, regionDensities) &&
            other.residueMask == residueMask &&
            other.componentResult == componentResult &&
            other.relationResult == relationResult &&
            other.edgeSelectionResult == edgeSelectionResult &&
            other.spatialGraph == spatialGraph &&
            other.graphStatistics == graphStatistics &&
            other.connectedStructureResult == connectedStructureResult;
  }

  @override
  int get hashCode => Object.hash(
    surfaceType,
    sourceId,
    workingImage,
    Object.hashAll(analysisRegions),
    Object.hashAll(regionDensities),
    residueMask,
    componentResult,
    relationResult,
    edgeSelectionResult,
    spatialGraph,
    graphStatistics,
    connectedStructureResult,
  );

  @override
  String toString() {
    return 'VisionPipelineResult(surfaceType: $surfaceType, '
        'sourceId: $sourceId, '
        'componentCount: ${componentResult.componentCount}, '
        'selectedEdgeCount: ${edgeSelectionResult.selectedRelations.length}, '
        'structureCount: ${connectedStructureResult.structureCount})';
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
