import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/quality_assessment.dart';
import '../models/saucer_analysis_result.dart';
import '../models/target_geometry.dart';

class SaucerGuidanceEngine {
  const SaucerGuidanceEngine();

  String message({
    required SaucerAnalysisResult result,
    required QualityAssessment assessment,
    required Size viewportSize,
    required CoffeeCameraConfig config,
    required bool stabilizedReady,
  }) {
    final strings = config.strings;
    final saucer = result.saucer;
    if (!assessment.cupDetected || saucer == null) {
      return strings.positionSaucer;
    }
    final target = TargetGeometry.forSaucer(viewportSize, config.saucerConfig);
    final bounds = target.normalizedRectToPixels(saucer.normalizedBounds);
    final thresholds = config.saucerConfig.thresholds;
    if (assessment.cupDiameterRatio < thresholds.minimumSaucerDiameterRatio) {
      return strings.moveSaucerCloser;
    }
    if (assessment.cupDiameterRatio > thresholds.maximumSaucerDiameterRatio ||
        !assessment.notClipped) {
      return strings.moveSaucerFarther;
    }
    final offset = bounds.center - target.center;
    final maximumCenterDistance = thresholds.maximumCenterDistanceRatio;
    if (offset.distance / target.radius > maximumCenterDistance) {
      return strings.centerSaucer;
    }
    if (!assessment.contained) return strings.moveSaucerFarther;
    if (!assessment.angleOk) return strings.levelOverSaucer;
    if (!assessment.stable) return strings.holdCameraStill;
    if (!assessment.sharpEnough) return strings.adjustingFocus;
    if (!assessment.lightEnough) return strings.moveToBrighterArea;
    if (stabilizedReady) return strings.saucerReady;
    return strings.holdCameraStill;
  }
}
