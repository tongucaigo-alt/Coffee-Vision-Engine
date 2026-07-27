import 'package:coffee_vision/coffee_vision.dart';

import 'validation_models.dart';

final class ValidationMetricExtractor {
  const ValidationMetricExtractor();

  ValidationImageMetrics extract({
    required VisionPipelineResult result,
    required ValidationDatasetEntry entry,
  }) {
    if (result.surfaceType != entry.surfaceType ||
        result.sourceId != entry.sourceId) {
      throw StateError('Pipeline result context does not match dataset entry.');
    }
    return ValidationImageMetrics(
      surfaceType: result.surfaceType,
      sourceId: entry.sourceId,
      workingImageWidth: result.workingImage.workingMetadata.width,
      workingImageHeight: result.workingImage.workingMetadata.height,
      workingResiduePixelCount: result.residueMask.residuePixelCount,
      workingContentResidueAreaRatio: result.residueMask.residueRatio,
      componentCount: result.componentResult.componentCount,
      relationCount: result.relationResult.relations.length,
      selectedEdgeCount: result.edgeSelectionResult.selectedRelations.length,
      graphNodeCount: result.graphStatistics.componentCount,
      graphEdgeCount: result.graphStatistics.relationCount,
      structureCount: result.connectedStructureResult.structureCount,
      largestStructureSize:
          result.connectedStructureResult.largestStructureSize,
      isolatedStructureCount:
          result.connectedStructureResult.isolatedStructureCount,
    );
  }
}
