import 'dart:math' as math;
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/frame_analysis_result.dart';
import '../models/quality_assessment.dart';
import '../models/target_geometry.dart';

class QualityChecker {
  const QualityChecker();

  QualityAssessment assess({
    required FrameAnalysisResult result,
    required Size viewportSize,
    required CoffeeCameraConfig config,
  }) {
    if (viewportSize.isEmpty) return QualityAssessment.unavailable();

    final thresholds = config.thresholds;
    final target = TargetGeometry.fromViewport(viewportSize, config);
    final cup = result.cup;
    final cupDetected =
        result.cupAnalysisAvailable &&
        cup != null &&
        cup.confidence >= thresholds.minimumDetectionConfidence;

    var centered = false;
    var rightSize = false;
    var contained = false;
    var notClipped = true;
    var cupDiameterRatio = 0.0;

    if (cupDetected) {
      final cupRect = target.normalizedRectToPixels(cup.normalizedBounds);
      final centerDistance = (cupRect.center - target.center).distance;
      final cupRadius = math.max(cupRect.width, cupRect.height) / 2;
      cupDiameterRatio = cupRadius / target.radius;
      centered =
          centerDistance / target.radius <=
          thresholds.maximumCenterDistanceRatio;
      rightSize =
          cupDiameterRatio >= thresholds.minimumCupDiameterRatio &&
          cupDiameterRatio <= thresholds.maximumCupDiameterRatio;
      contained = centerDistance + cupRadius <= target.radius;
      final bounds = cup.normalizedBounds;
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
    if (cupDetected) score += 20;
    if (centered) score += 20;
    if (rightSize) score += 15;
    if (sharpEnough) score += 15;
    if (lightEnough) score += 10;
    if (angleOk) score += 20;

    final level = switch (score) {
      < 60 => CaptureQualityLevel.unsuitable,
      < 85 => CaptureQualityLevel.guidance,
      _ => CaptureQualityLevel.ready,
    };
    final autoCaptureReady =
        score >= 85 &&
        cupDetected &&
        centered &&
        rightSize &&
        contained &&
        notClipped &&
        lightEnough &&
        sharpEnough &&
        angleOk &&
        result.isStable;

    return QualityAssessment(
      score: score,
      level: level,
      cupDetected: cupDetected,
      centered: centered,
      rightSize: rightSize,
      contained: contained,
      notClipped: notClipped,
      lightEnough: lightEnough,
      sharpEnough: sharpEnough,
      angleOk: angleOk,
      stable: result.isStable,
      cupDiameterRatio: cupDiameterRatio,
      autoCaptureReady: autoCaptureReady,
    );
  }
}
