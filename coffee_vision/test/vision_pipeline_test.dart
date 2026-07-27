import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  const engine = CoffeeVisionEngine(config: VisionConfig(workingResolution: 8));

  group('CoffeeVisionEngine.analyzeDetailed', () {
    test('returns a pipeline result and preserves input context', () async {
      final result = await engine.analyzeDetailed(
        _residueInput(
          surfaceType: VisionSurfaceType.cup,
          sourceId: 'cup-sample',
        ),
      );

      expect(result, isA<VisionPipelineResult>());
      expect(result.surfaceType, VisionSurfaceType.cup);
      expect(result.sourceId, 'cup-sample');
    });

    test(
      'propagates saucer surface type through regions and densities',
      () async {
        final result = await engine.analyzeDetailed(
          _residueInput(surfaceType: VisionSurfaceType.saucer),
        );

        expect(result.surfaceType, VisionSurfaceType.saucer);
        expect(
          result.analysisRegions.every(
            (region) => region.surfaceType == VisionSurfaceType.saucer,
          ),
          isTrue,
        );
        expect(
          result.regionDensities.every(
            (density) => density.surfaceType == VisionSurfaceType.saucer,
          ),
          isTrue,
        );
      },
    );

    test('exposes source and working image metadata', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(result.workingImage.sourceMetadata.width, 8);
      expect(result.workingImage.sourceMetadata.height, 8);
      expect(result.workingImage.workingMetadata.width, 8);
      expect(result.workingImage.workingMetadata.height, 8);
      expect(result.workingImage.resolution, 8);
    });

    test('returns all six existing regions and density results', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(
        result.analysisRegions.map((region) => region.id),
        VisionRegionId.values,
      );
      expect(
        result.regionDensities.map((density) => density.regionId),
        VisionRegionId.values,
      );
    });

    test('keeps residue mask and component totals consistent', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(result.residueMask.width, 8);
      expect(result.residueMask.height, 8);
      expect(result.residueMask.residuePixelCount, 3);
      expect(
        result.componentResult.totalResiduePixels,
        result.residueMask.residuePixelCount,
      );
      expect(result.componentResult.componentCount, 2);
    });

    test('produces existing full directed component relations', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(result.relationResult.relations.length, 2);
      expect(
        result.relationResult.relations
            .map(
              (relation) =>
                  (relation.sourceComponentId, relation.targetComponentId),
            )
            .toList(),
        [(1, 2), (2, 1)],
      );
    });

    test('uses pass-through edge selection by default', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(result.edgeSelectionResult.profile.isPassThrough, isTrue);
      expect(result.edgeSelectionResult.selectedRelations.length, 2);
      expect(result.spatialGraph.relations.length, 2);
      for (
        var index = 0;
        index < result.spatialGraph.relations.length;
        index++
      ) {
        expect(
          result.spatialGraph.relations[index],
          same(result.edgeSelectionResult.selectedRelations[index]),
        );
      }
    });

    test('summarizes the produced sparse graph', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(result.graphStatistics.componentCount, 2);
      expect(result.graphStatistics.relationCount, 2);
      expect(result.graphStatistics.minDegree, 1);
      expect(result.graphStatistics.maxDegree, 1);
      expect(result.graphStatistics.averageDegree, 1.0);
    });

    test('analyzes weak structures from the produced graph', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(result.connectedStructureResult.structureCount, 1);
      expect(result.connectedStructureResult.structures.single.componentIds, [
        1,
        2,
      ]);
      expect(
        result.connectedStructureResult.structures.single.directedEdgeCount,
        2,
      );
    });

    test(
      'applies a supplied edge selection profile without tuning it',
      () async {
        final result = await engine.analyzeDetailed(
          _residueInput(),
          edgeSelectionProfile: const VisionEdgeSelectionProfile(
            maxOutgoingPerSource: 0,
          ),
        );

        expect(result.edgeSelectionResult.selectedRelations, isEmpty);
        expect(result.spatialGraph.relations, isEmpty);
        expect(result.graphStatistics.isolatedComponentCount, 2);
        expect(result.connectedStructureResult.structureCount, 2);
        expect(result.connectedStructureResult.isolatedStructureCount, 2);
      },
    );

    test('handles an image with no residue candidates', () async {
      final result = await engine.analyzeDetailed(_whiteInput());

      expect(result.residueMask.residuePixelCount, 0);
      expect(result.componentResult.components, isEmpty);
      expect(result.relationResult.relations, isEmpty);
      expect(result.edgeSelectionResult.selectedRelations, isEmpty);
      expect(result.spatialGraph.components, isEmpty);
      expect(result.connectedStructureResult.structures, isEmpty);
    });

    test('returns deterministic equal results for the same input', () async {
      final input = _residueInput(sourceId: 'deterministic');
      final first = await engine.analyzeDetailed(input);
      final second = await engine.analyzeDetailed(input);

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toString(), contains('componentCount: 2'));
    });

    test('protects result collection fields from mutation', () async {
      final result = await engine.analyzeDetailed(_residueInput());

      expect(() => result.analysisRegions.clear(), throwsUnsupportedError);
      expect(() => result.regionDensities.clear(), throwsUnsupportedError);
    });

    test('does not change the existing analyze placeholder behavior', () async {
      final input = _residueInput(surfaceType: VisionSurfaceType.saucer);
      final observation = await engine.analyze(input);

      expect(observation.surfaceType, VisionSurfaceType.saucer);
      expect(observation.confidence, 0.0);
      expect(
        observation.notes,
        contains(
          'Image metadata analysis completed; further Coffee Vision analysis '
          'is not implemented.',
        ),
      );
    });
  });
}

VisionImageInput _residueInput({
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
  String? sourceId,
}) {
  final source = _solidImage(8, 8, 255);
  _setGray(source, 1, 1, 0);
  _setGray(source, 1, 2, 0);
  _setGray(source, 6, 6, 0);
  return VisionImageInput(
    imageBytes: image.encodePng(source),
    surfaceType: surfaceType,
    sourceId: sourceId,
  );
}

VisionImageInput _whiteInput() {
  return VisionImageInput(
    imageBytes: image.encodePng(_solidImage(8, 8, 255)),
    surfaceType: VisionSurfaceType.cup,
  );
}

image.Image _solidImage(int width, int height, int luminance) {
  final result = image.Image(width: width, height: height, numChannels: 4);
  for (final pixel in result) {
    pixel.setRgba(luminance, luminance, luminance, 255);
  }
  return result;
}

void _setGray(image.Image target, int x, int y, int luminance) {
  target.setPixelRgba(x, y, luminance, luminance, luminance, 255);
}
