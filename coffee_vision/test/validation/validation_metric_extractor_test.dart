import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

import '../../tool/validation/src/validation_metric_extractor.dart';
import 'validation_test_support.dart';

void main() {
  const extractor = ValidationMetricExtractor();

  group('ValidationMetricExtractor', () {
    test('maps every metric from the existing pipeline result', () async {
      final result = await createPipelineResult();
      final entry = createEntry();

      final metrics = extractor.extract(result: result, entry: entry);

      expect(
        metrics.workingImageWidth,
        result.workingImage.workingMetadata.width,
      );
      expect(
        metrics.workingImageHeight,
        result.workingImage.workingMetadata.height,
      );
      expect(
        metrics.workingResiduePixelCount,
        result.residueMask.residuePixelCount,
      );
      expect(
        metrics.workingContentResidueAreaRatio,
        result.residueMask.residueRatio,
      );
      expect(metrics.componentCount, result.componentResult.componentCount);
      expect(metrics.relationCount, result.relationResult.relations.length);
      expect(
        metrics.selectedEdgeCount,
        result.edgeSelectionResult.selectedRelations.length,
      );
      expect(metrics.graphNodeCount, result.graphStatistics.componentCount);
      expect(metrics.graphEdgeCount, result.graphStatistics.relationCount);
      expect(
        metrics.structureCount,
        result.connectedStructureResult.structureCount,
      );
      expect(
        metrics.largestStructureSize,
        result.connectedStructureResult.largestStructureSize,
      );
      expect(
        metrics.isolatedStructureCount,
        result.connectedStructureResult.isolatedStructureCount,
      );
    });

    test('preserves cup and saucer context independently', () async {
      final result = await createPipelineResult(
        surfaceType: VisionSurfaceType.saucer,
        sourceId: 'saucer-001',
      );
      final entry = createEntry(
        sourceId: 'saucer-001',
        surfaceType: VisionSurfaceType.saucer,
      );

      final metrics = extractor.extract(result: result, entry: entry);

      expect(metrics.surfaceType, VisionSurfaceType.saucer);
      expect(metrics.sourceId, 'saucer-001');
    });

    test(
      'represents empty residue and graph results without alternatives',
      () async {
        final result = await createPipelineResult(withResidue: false);

        final metrics = extractor.extract(result: result, entry: createEntry());

        expect(metrics.workingResiduePixelCount, 0);
        expect(metrics.componentCount, 0);
        expect(metrics.relationCount, 0);
        expect(metrics.selectedEdgeCount, 0);
        expect(metrics.graphNodeCount, 0);
        expect(metrics.graphEdgeCount, 0);
        expect(metrics.structureCount, 0);
        expect(metrics.largestStructureSize, 0);
        expect(metrics.isolatedStructureCount, 0);
      },
    );

    test('maps isolated structures from the pipeline result', () async {
      final result = await createPipelineResult(
        edgeSelectionProfile: const VisionEdgeSelectionProfile(
          maxOutgoingPerSource: 0,
        ),
      );

      final metrics = extractor.extract(result: result, entry: createEntry());

      expect(metrics.selectedEdgeCount, 0);
      expect(metrics.structureCount, 2);
      expect(metrics.largestStructureSize, 1);
      expect(metrics.isolatedStructureCount, 2);
    });

    test('rejects mismatched input and pipeline context', () async {
      final result = await createPipelineResult(sourceId: 'pipeline-id');
      final entry = createEntry(sourceId: 'manifest-id');

      expect(
        () => extractor.extract(result: result, entry: entry),
        throwsStateError,
      );
    });
  });
}
