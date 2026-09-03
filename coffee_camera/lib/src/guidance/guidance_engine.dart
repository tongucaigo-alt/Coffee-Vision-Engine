import '../config/coffee_camera_config.dart';
import '../models/frame_analysis_result.dart';
import '../models/quality_assessment.dart';

class GuidanceEngine {
  const GuidanceEngine();

  String message({
    required FrameAnalysisResult result,
    required QualityAssessment assessment,
    required CoffeeCameraConfig config,
  }) {
    final strings = config.strings;
    if (!assessment.cupDetected) return strings.bringCupToTarget;
    if (!assessment.lightEnough) return strings.lowLight;
    if (!assessment.sharpEnough) return strings.tooBlurry;
    if (!assessment.angleOk) return strings.holdOverCup;

    if (!assessment.centered) {
      final cupX = result.cup?.center.dx ?? config.targetCenter.dx;
      final difference = cupX - config.targetCenter.dx;
      if (difference.abs() < 0.035) return strings.holdOverCup;
      return difference < 0 ? strings.moveRight : strings.moveLeft;
    }

    if (!assessment.rightSize) {
      return assessment.cupDiameterRatio <
              config.thresholds.minimumCupDiameterRatio
          ? strings.moveCloser
          : strings.moveFarther;
    }
    if (!assessment.contained || !assessment.notClipped) {
      return strings.holdOverCup;
    }
    return strings.readyHoldStill;
  }
}
