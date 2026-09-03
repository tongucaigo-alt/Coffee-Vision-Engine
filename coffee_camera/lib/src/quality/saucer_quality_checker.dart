import 'dart:math' as math;
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/quality_assessment.dart';
import '../models/saucer_analysis_result.dart';
import '../models/target_geometry.dart';

class SaucerQualityChecker {
  const SaucerQualityChecker();

  QualityAssessment assess({
    required SaucerAnalysisResult result,
    required Size viewportSize,
    required CoffeeCameraConfig config,
  }) {
    if (viewportSize.isEmpty) return QualityAssessment.unavailable();

    final thresholds = config.saucerConfig.thresholds;
    final target = TargetGeometry.forSaucer(viewportSize, config.saucerConfig);
    final saucer = result.saucer;
    final saucerDetected =
        result.analysisAvailable &&
        saucer != null &&
        saucer.confidence >= thresholds.minimumDetectionConfidence;

    var centered = false;
    var rightSize = false;
    var contained = false;
    var notClipped = true;
    var diameterRatio = 0.0;

    if (saucerDetected) {
      final saucerRect = target.normalizedRectToPixels(saucer.normalizedBounds);
      final centerDistance = (saucerRect.center - target.center).distance;
      final saucerRadius = math.max(saucerRect.width, saucerRect.height) / 2;
      diameterRatio = saucerRadius / target.radius;
      centered =
          centerDistance / target.radius <=
          thresholds.maximumCenterDistanceRatio;
      final roundness =
          math.min(saucerRect.width, saucerRect.height) /
          math.max(saucerRect.width, saucerRect.height);
      rightSize =
          diameterRatio >= thresholds.minimumSaucerDiameterRatio &&
          diameterRatio <= thresholds.maximumSaucerDiameterRatio &&
          roundness >= thresholds.minimumRoundness;
      contained = centerDistance + saucerRadius <= target.radius;
      final bounds = saucer.normalizedBounds;
      final margin = thresholds.screenEdgeMargin;
      notClipped =
          bounds.left > margin &&
          bounds.top > margin &&
          bounds.right < 1 - margin &&
          bounds.bottom < 1 - margin;
    }

    final lightEnough = result.brightness >= thresholds.minimumBrightness;
    final sharpEnough = result.sharpness >= thresholds.minimumSharpness;
    final angleOk = result.angleDegrees.abs() <= thresholds.maximumAngleDegrees;

    var score = 0;
    if (saucerDetected) score += 15;
    if (centered) score += 20;
    if (rightSize && contained && notClipped) score += 25;
    if (sharpEnough) score += 15;
    if (lightEnough) score += 10;
    if (angleOk) score += 10;
    if (result.isStable) score += 5;

    final ready =
        score >= 85 &&
        saucerDetected &&
        centered &&
        rightSize &&
        contained &&
        notClipped &&
        lightEnough &&
        sharpEnough &&
        angleOk &&
        result.isStable;
    final level = ready
        ? CaptureQualityLevel.ready
        : score < 60
        ? CaptureQualityLevel.unsuitable
        : CaptureQualityLevel.guidance;

    return QualityAssessment(
      score: score,
      level: level,
      cupDetected: saucerDetected,
      centered: centered,
      rightSize: rightSize,
      contained: contained,
      notClipped: notClipped,
      lightEnough: lightEnough,
      sharpEnough: sharpEnough,
      angleOk: angleOk,
      stable: result.isStable,
      cupDiameterRatio: diameterRatio,
      autoCaptureReady: ready,
    );
  }
}
