import 'package:coffee_vision/coffee_vision.dart';

import 'models/pattern_analysis_result.dart';
import 'models/pattern_surface_type.dart';
import 'pattern_extractor.dart';

/// Deterministic entry point for physical Pattern Engine analysis.
///
/// Projects each existing connected structure to one physical pattern
/// candidate with canonical evidence, normalized geometry, and direct
/// structure-level topology.
///
/// It performs no Vision analysis or semantic inference.
final class PatternEngine {
  const PatternEngine();

  /// Consumes one complete VisionFeatureSet through the public Vision API.
  Future<PatternAnalysisResult> analyzePatterns(VisionFeatureSet featureSet) {
    _validateCompleteFeatureSet(featureSet);
    final candidates = const PatternExtractor().extract(featureSet);
    return Future<PatternAnalysisResult>.value(
      PatternAnalysisResult(
        surfaceType: switch (featureSet.surfaceType) {
          VisionSurfaceType.cup => PatternSurfaceType.cup,
          VisionSurfaceType.saucer => PatternSurfaceType.saucer,
        },
        sourceId: featureSet.sourceId,
        candidates: candidates,
      ),
    );
  }

  static void _validateCompleteFeatureSet(VisionFeatureSet featureSet) {
    if (featureSet.globalFeatures == null ||
        featureSet.edgeSelectionProfile == null ||
        featureSet.graphStatistics == null ||
        featureSet.connectedStructureResult == null) {
      throw ArgumentError.value(
        featureSet,
        'featureSet',
        'must be a complete result produced by '
            'CoffeeVisionEngine.analyzeFeatures()',
      );
    }
  }
}
