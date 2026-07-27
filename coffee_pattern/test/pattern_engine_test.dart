import 'dart:convert';
import 'dart:typed_data';

import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('PatternEngine.analyzePatterns', () {
    test('keeps a complete zero-structure cup FeatureSet empty', () async {
      final features = await _completeFeatures(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'cup-source',
      );
      expect(features.connectedStructureResult!.structures, isEmpty);

      final result = await const PatternEngine().analyzePatterns(features);

      expect(result.surfaceType, PatternSurfaceType.cup);
      expect(result.sourceId, 'cup-source');
      expect(result.candidates, isEmpty);
    });

    test(
      'preserves zero-structure saucer context without Vision result types',
      () async {
        final features = await _completeFeatures(
          surfaceType: VisionSurfaceType.saucer,
          sourceId: null,
        );
        expect(features.connectedStructureResult!.structures, isEmpty);

        final result = await const PatternEngine().analyzePatterns(features);

        expect(result.surfaceType, PatternSurfaceType.saucer);
        expect(result.sourceId, isNull);
        expect(result.candidates, isEmpty);
      },
    );

    test('is deterministic for repeated identical input', () async {
      final features = await _completeFeatures(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'repeatable',
      );
      const engine = PatternEngine();

      final first = await engine.analyzePatterns(features);
      final second = await engine.analyzePatterns(features);
      final third = await engine.analyzePatterns(features);

      expect(second, first);
      expect(third, first);
      expect(second.hashCode, first.hashCode);
      expect(third.hashCode, first.hashCode);
    });

    test('rejects every legacy partial FeatureSet tier', () async {
      final complete = await _completeFeatures(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'legacy',
      );
      final m7a = VisionFeatureSet(
        surfaceType: complete.surfaceType,
        sourceId: complete.sourceId,
        imageProvenance: complete.imageProvenance,
      );
      final m7b = VisionFeatureSet.withGlobalAndRegionalFeatures(
        surfaceType: complete.surfaceType,
        sourceId: complete.sourceId,
        imageProvenance: complete.imageProvenance,
        globalFeatures: complete.globalFeatures!,
        regionFeatures: complete.regionFeatures,
      );
      final m7c = VisionFeatureSet.withComponentFeatures(
        surfaceType: complete.surfaceType,
        sourceId: complete.sourceId,
        imageProvenance: complete.imageProvenance,
        globalFeatures: complete.globalFeatures!,
        regionFeatures: complete.regionFeatures,
        componentFeatures: complete.componentFeatures,
      );
      const engine = PatternEngine();

      expect(() => engine.analyzePatterns(m7a), throwsArgumentError);
      expect(() => engine.analyzePatterns(m7b), throwsArgumentError);
      expect(() => engine.analyzePatterns(m7c), throwsArgumentError);
    });

    test('does not mutate the complete VisionFeatureSet', () async {
      final features = await _completeFeatures(
        surfaceType: VisionSurfaceType.cup,
        sourceId: 'unchanged',
      );
      final regions = List<VisionRegionFeature>.of(features.regionFeatures);
      final components = List<VisionComponentFeature>.of(
        features.componentFeatures,
      );
      final relations = List<VisionSpatialRelationFeature>.of(
        features.spatialRelationFeatures,
      );

      await const PatternEngine().analyzePatterns(features);

      expect(features.regionFeatures, regions);
      expect(features.componentFeatures, components);
      expect(features.spatialRelationFeatures, relations);
    });
  });
}

Future<VisionFeatureSet> _completeFeatures({
  required VisionSurfaceType surfaceType,
  required String? sourceId,
}) {
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGN88e41'
      'AwMDEwMYQCkANKQCx3xNMvIAAAAASUVORK5CYII=';
  return const CoffeeVisionEngine(
    config: VisionConfig(workingResolution: 8),
  ).analyzeFeatures(
    VisionImageInput(
      imageBytes: Uint8List.fromList(base64Decode(pngBase64)),
      surfaceType: surfaceType,
      sourceId: sourceId,
    ),
  );
}
