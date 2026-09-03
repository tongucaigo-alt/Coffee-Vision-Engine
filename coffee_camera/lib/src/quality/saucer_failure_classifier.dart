import 'dart:math' as math;
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/saucer_analysis_result.dart';
import '../models/target_geometry.dart';

class SaucerFailureClassifier {
  const SaucerFailureClassifier();

  bool isHardFailure({
    required SaucerAnalysisResult result,
    required Size viewportSize,
    required CoffeeCameraConfig config,
  }) {
    if (viewportSize.isEmpty || !result.residue.analysisPerformed) return true;

    final thresholds = config.saucerConfig.thresholds;
    final severeLowLight = math.max(0.08, thresholds.minimumBrightness * 0.50);
    if (result.brightness < severeLowLight || result.brightness > 0.96) {
      return true;
    }

    final residueBounds = result.residue.residueBounds;
    if (residueBounds != null) {
      final analysisBounds =
          config.saucerConfig.residueProfile.normalizedAnalysisBounds;
      final overlap = residueBounds.intersect(analysisBounds);
      if (overlap.isEmpty ||
          overlap.width * overlap.height <
              residueBounds.width * residueBounds.height * 0.35) {
        return true;
      }
    }

    final saucer = result.saucer;
    if (saucer == null) return false;
    final normalized = saucer.normalizedBounds;
    if (normalized.isEmpty) return true;
    final visible = normalized.intersect(const Rect.fromLTWH(0, 0, 1, 1));
    if (visible.isEmpty ||
        visible.width * visible.height <
            normalized.width * normalized.height * 0.72) {
      return true;
    }

    final target = TargetGeometry.forSaucer(viewportSize, config.saucerConfig);
    final bounds = target.normalizedRectToPixels(normalized);
    final radius = math.max(bounds.width, bounds.height) / 2;
    final diameterRatio = radius / target.radius;
    if (diameterRatio < thresholds.minimumSaucerDiameterRatio - 0.22 ||
        diameterRatio > thresholds.maximumSaucerDiameterRatio + 0.18) {
      return true;
    }
    final centerRatio =
        (bounds.center - target.center).distance / target.radius;
    return centerRatio > thresholds.maximumCenterDistanceRatio * 2.25;
  }
}
