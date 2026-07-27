part of 'coffee_vision_engine.dart';

/// Internal orchestration of existing Coffee Vision analysis layers.
final class _VisionPipeline {
  const _VisionPipeline(this._engine);

  final CoffeeVisionEngine _engine;

  Future<VisionPipelineResult> analyze({
    required VisionImageInput input,
    required VisionEdgeSelectionProfile edgeSelectionProfile,
  }) async {
    final workingImage = await _engine.prepareWorkingImage(input);
    final analysisRegions = _engine.createAnalysisRegions(
      workingImage: workingImage,
      surfaceType: input.surfaceType,
    );
    final regionDensities = await _engine.analyzeRegionDensities(
      workingImage: workingImage,
      surfaceType: input.surfaceType,
    );
    final residueMask = await _engine.createResidueMask(
      workingImage: workingImage,
    );
    final componentResult = await _engine.detectComponents(mask: residueMask);
    final relationResult = await _engine.analyzeComponentRelations(
      componentResult: componentResult,
    );
    final edgeSelectionResult = _engine.selectEdges(
      relationResult: relationResult,
      profile: edgeSelectionProfile,
    );
    final spatialGraph = _engine.createSparseSpatialGraph(
      componentResult: componentResult,
      edgeSelectionResult: edgeSelectionResult,
    );
    final graphStatistics = _engine.analyzeGraphStatistics(graph: spatialGraph);
    final connectedStructureResult = _engine.analyzeConnectedStructures(
      graph: spatialGraph,
    );

    return VisionPipelineResult(
      surfaceType: input.surfaceType,
      sourceId: input.sourceId,
      workingImage: workingImage,
      analysisRegions: analysisRegions,
      regionDensities: regionDensities,
      residueMask: residueMask,
      componentResult: componentResult,
      relationResult: relationResult,
      edgeSelectionResult: edgeSelectionResult,
      spatialGraph: spatialGraph,
      graphStatistics: graphStatistics,
      connectedStructureResult: connectedStructureResult,
    );
  }
}
