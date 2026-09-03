import 'package:flutter/material.dart';

import '../analysis/cup_detector.dart';
import '../analysis/saucer_detector.dart';
import '../config/coffee_camera_config.dart';
import '../models/camera_capture_result.dart';
import '../models/coffee_camera_capture_result.dart';
import '../models/residue_analysis_result.dart';
import 'coffee_camera_screen.dart';

/// Opens one camera capture.
///
/// [captureTitle] and [captureInstruction] add host-provided presentation
/// context without changing detection, quality, capture, or ownership rules.
Future<CameraCaptureResult?> showCoffeeCamera(
  BuildContext context, {
  CoffeeCameraConfig config = const CoffeeCameraConfig(),
  CupDetector? detector,
  String? captureTitle,
  String? captureInstruction,
}) {
  if (config.requireSaucerCapture) {
    throw ArgumentError.value(
      config.requireSaucerCapture,
      'config.requireSaucerCapture',
      'Use showCoffeeCameraFlow for two-step capture.',
    );
  }
  return Navigator.of(context).push<CameraCaptureResult>(
    MaterialPageRoute<CameraCaptureResult>(
      fullscreenDialog: true,
      builder: (cameraContext) => CoffeeCameraScreen(
        config: config,
        detector: detector,
        captureTitle: captureTitle,
        captureInstruction: captureInstruction,
        onApproved: (result) => Navigator.of(cameraContext).pop(result),
        onCancelled: () => Navigator.of(cameraContext).pop(),
      ),
    ),
  );
}

Future<CoffeeCameraCaptureResult?> showCoffeeCameraFlow(
  BuildContext context, {
  CoffeeCameraConfig config = const CoffeeCameraConfig(),
  CupDetector? detector,
  SaucerDetector? saucerDetector,
  ValueChanged<ResidueAnalysisResult>? onSaucerResidueAnalysis,
}) {
  return Navigator.of(context).push<CoffeeCameraCaptureResult>(
    MaterialPageRoute<CoffeeCameraCaptureResult>(
      fullscreenDialog: true,
      builder: (cameraContext) => CoffeeCameraScreen.flow(
        config: config,
        detector: detector,
        saucerDetector: saucerDetector,
        onSaucerResidueAnalysis: onSaucerResidueAnalysis,
        onCompleted: (result) => Navigator.of(cameraContext).pop(result),
        onCancelled: () => Navigator.of(cameraContext).pop(),
      ),
    ),
  );
}
