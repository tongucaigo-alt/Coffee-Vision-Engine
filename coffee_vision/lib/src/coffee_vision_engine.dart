import 'connected_component_detector.dart';
import 'component_relation_analyzer.dart';
import 'connected_structure_analyzer.dart';
import 'config/vision_config.dart';
import 'edge_selector.dart';
import 'graph_statistics_analyzer.dart';
import 'models/residue_mask.dart';
import 'models/vision_analysis_region.dart';
import 'models/vision_component_result.dart';
import 'models/vision_component_relation_result.dart';
import 'models/vision_connected_structure_result.dart';
import 'models/vision_edge_selection_profile.dart';
import 'models/vision_edge_selection_result.dart';
import 'models/vision_feature_set.dart';
import 'models/vision_geometry.dart';
import 'models/vision_graph_statistics.dart';
import 'models/vision_image_input.dart';
import 'models/vision_observation.dart';
import 'models/vision_pipeline_result.dart';
import 'models/vision_region_density.dart';
import 'models/vision_spatial_graph.dart';
import 'models/working_image.dart';
import 'residue_density_calculator.dart';
import 'residue_pixel_classifier.dart';
import 'vision_feature_extractor.dart';
import 'working_image_factory.dart';

part 'vision_pipeline.dart';

final class CoffeeVisionEngine {
  const CoffeeVisionEngine({this.config = const VisionConfig()});

  final VisionConfig config;

  Future<WorkingImage> prepareWorkingImage(VisionImageInput input) {
    return Future.sync(() => WorkingImageFactory(config: config).create(input));
  }

  /// Creates fixed normalized bands inside the working image's real content.
  ///
  /// The horizontal [VisionRegionId.middle] band and vertical
  /// [VisionRegionId.center] band intentionally overlap.
  List<VisionAnalysisRegion> createAnalysisRegions({
    required WorkingImage workingImage,
    required VisionSurfaceType surfaceType,
  }) {
    final contentRect = workingImage.contentRect;
    final firstHorizontalBoundary = contentRect.top + contentRect.height / 3;
    final secondHorizontalBoundary =
        contentRect.top + (contentRect.height * 2) / 3;
    final firstVerticalBoundary = contentRect.left + contentRect.width / 3;
    final secondVerticalBoundary =
        contentRect.left + (contentRect.width * 2) / 3;

    return List<VisionAnalysisRegion>.unmodifiable([
      VisionAnalysisRegion(
        id: VisionRegionId.top,
        rect: VisionRect(
          left: contentRect.left,
          top: contentRect.top,
          right: contentRect.right,
          bottom: firstHorizontalBoundary,
        ),
        surfaceType: surfaceType,
      ),
      VisionAnalysisRegion(
        id: VisionRegionId.middle,
        rect: VisionRect(
          left: contentRect.left,
          top: firstHorizontalBoundary,
          right: contentRect.right,
          bottom: secondHorizontalBoundary,
        ),
        surfaceType: surfaceType,
      ),
      VisionAnalysisRegion(
        id: VisionRegionId.bottom,
        rect: VisionRect(
          left: contentRect.left,
          top: secondHorizontalBoundary,
          right: contentRect.right,
          bottom: contentRect.bottom,
        ),
        surfaceType: surfaceType,
      ),
      VisionAnalysisRegion(
        id: VisionRegionId.left,
        rect: VisionRect(
          left: contentRect.left,
          top: contentRect.top,
          right: firstVerticalBoundary,
          bottom: contentRect.bottom,
        ),
        surfaceType: surfaceType,
      ),
      VisionAnalysisRegion(
        id: VisionRegionId.center,
        rect: VisionRect(
          left: firstVerticalBoundary,
          top: contentRect.top,
          right: secondVerticalBoundary,
          bottom: contentRect.bottom,
        ),
        surfaceType: surfaceType,
      ),
      VisionAnalysisRegion(
        id: VisionRegionId.right,
        rect: VisionRect(
          left: secondVerticalBoundary,
          top: contentRect.top,
          right: contentRect.right,
          bottom: contentRect.bottom,
        ),
        surfaceType: surfaceType,
      ),
    ]);
  }

  /// Calculates relative residue-candidate density for each analysis region.
  ///
  /// Work remains synchronous today, while the public Future contract allows
  /// the implementation to move off-isolate later without an API change.
  Future<List<VisionRegionDensity>> analyzeRegionDensities({
    required WorkingImage workingImage,
    required VisionSurfaceType surfaceType,
  }) {
    return Future.sync(() {
      final regions = createAnalysisRegions(
        workingImage: workingImage,
        surfaceType: surfaceType,
      );
      return const ResidueDensityCalculator().calculate(
        workingImage: workingImage,
        regions: regions,
      );
    });
  }

  /// Creates a full-size binary mask using the shared residue classification.
  ///
  /// The current implementation is synchronous internally, while the Future
  /// contract allows processing to move off-isolate later without an API
  /// change. This invocation decodes [workingImage] exactly once.
  Future<ResidueMask> createResidueMask({required WorkingImage workingImage}) {
    return Future.sync(
      () => const ResiduePixelClassifier().classify(workingImage).createMask(),
    );
  }

  /// Detects every 8-connected component in row-major discovery order.
  Future<VisionComponentResult> detectComponents({required ResidueMask mask}) {
    return Future.sync(() => const ConnectedComponentDetector().detect(mask));
  }

  /// Calculates directed geometric relations from existing components.
  Future<VisionComponentRelationResult> analyzeComponentRelations({
    required VisionComponentResult componentResult,
  }) {
    return Future.sync(
      () => const ComponentRelationAnalyzer().analyze(componentResult),
    );
  }

  /// Selects a deterministic subset of an existing full directed relation set.
  VisionEdgeSelectionResult selectEdges({
    required VisionComponentRelationResult relationResult,
    VisionEdgeSelectionProfile profile = const VisionEdgeSelectionProfile(),
  }) {
    return const EdgeSelector().select(
      relationResult: relationResult,
      profile: profile,
    );
  }

  /// Organizes validated components and relations as an immutable graph.
  ///
  /// This method performs no graph analysis, inference, relation filtering, or
  /// relation generation. Future graph analyses must consume the returned
  /// [VisionSpatialGraph] from a separate analysis layer.
  VisionSpatialGraph createSpatialGraph({
    required VisionComponentResult componentResult,
    required VisionComponentRelationResult relationResult,
  }) {
    return const SpatialGraphOrganizer().organize(
      componentResult: componentResult,
      relationResult: relationResult,
    );
  }

  /// Organizes selected directed relations without requiring a complete set.
  VisionSpatialGraph createSparseSpatialGraph({
    required VisionComponentResult componentResult,
    required VisionEdgeSelectionResult edgeSelectionResult,
  }) {
    return const SpatialGraphOrganizer().organizeSparse(
      componentResult: componentResult,
      relations: edgeSelectionResult.selectedRelations,
    );
  }

  /// Summarizes the existing graph through its public outgoing-degree API.
  ///
  /// The graph, its components, and its relations remain unchanged. No graph
  /// organization or new semantic interpretation is performed.
  VisionGraphStatistics analyzeGraphStatistics({
    required VisionSpatialGraph graph,
  }) {
    return const GraphStatisticsAnalyzer().analyze(graph);
  }

  /// Finds deterministic weakly connected structures in an existing graph.
  ///
  /// Relation direction is preserved by the graph and ignored only while
  /// determining structure membership. No graph data is added or changed.
  VisionConnectedStructureResult analyzeConnectedStructures({
    required VisionSpatialGraph graph,
  }) {
    return const ConnectedStructureAnalyzer().analyze(graph);
  }

  /// Runs the existing analysis layers and returns their immutable outputs.
  ///
  /// This entry point adds orchestration only. It does not alter thresholds,
  /// confidence, graph semantics, or the existing [analyze] behavior. It
  /// remains available for backward compatibility and technical inspection;
  /// later semantic layers must not use [VisionPipelineResult] as input.
  Future<VisionPipelineResult> analyzeDetailed(
    VisionImageInput input, {
    VisionEdgeSelectionProfile edgeSelectionProfile =
        const VisionEdgeSelectionProfile(),
  }) {
    return _VisionPipeline(
      this,
    ).analyze(input: input, edgeSelectionProfile: edgeSelectionProfile);
  }

  /// Produces the terminal physical-measurement contract of Coffee Vision.
  ///
  /// This is the canonical complete M7 construction path. It returns approved
  /// provenance and direct physical feature projections from the existing
  /// detailed pipeline, which runs exactly once and remains unchanged. This
  /// output must never contain symbol, semantic, AI, or fortune information.
  Future<VisionFeatureSet> analyzeFeatures(
    VisionImageInput input, {
    VisionEdgeSelectionProfile edgeSelectionProfile =
        const VisionEdgeSelectionProfile(),
  }) {
    return const VisionFeatureExtractor().analyze(
      input: input,
      edgeSelectionProfile: edgeSelectionProfile,
      pipelineRunner: (pipelineInput, profile) =>
          analyzeDetailed(pipelineInput, edgeSelectionProfile: profile),
    );
  }

  Future<VisionObservation> analyze(VisionImageInput input) async {
    final workingImage = await prepareWorkingImage(input);
    return VisionObservation(
      surfaceType: input.surfaceType,
      confidence: 0.0,
      notes: const [
        'Image metadata analysis completed; further Coffee Vision analysis '
            'is not implemented.',
      ],
      imageMetadata: workingImage.metadata,
    );
  }
}
