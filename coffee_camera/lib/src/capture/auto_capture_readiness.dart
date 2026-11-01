import '../config/coffee_camera_config.dart';
import '../models/frame_analysis_result.dart';
import '../models/quality_assessment.dart';

/// Classifies interruptions only. Capture still requires every normal quality
/// condition on a fresh frame; a recoverable interruption never permits capture.
bool requiresAutoCaptureReset({
  required FrameAnalysisResult analysis,
  required QualityAssessment assessment,
  required CoffeeCameraConfig config,
  required bool currentCoffeeValid,
}) {
  if (!assessment.cupDetected ||
      !assessment.notClipped ||
      !currentCoffeeValid ||
      !analysis.coffeeDetected ||
      !analysis.brightness.isFinite ||
      !analysis.sharpness.isFinite) {
    return true;
  }
  // A small metering/focus fluctuation may pause the counter, but distinctly
  // poor light or focus must discard it. These are interruption margins, not
  // lower acceptance thresholds for the photograph.
  const recoveryRatio = 0.90;
  return analysis.brightness <
          config.thresholds.minimumBrightness * recoveryRatio ||
      analysis.sharpness < config.thresholds.minimumSharpness * recoveryRatio;
}
