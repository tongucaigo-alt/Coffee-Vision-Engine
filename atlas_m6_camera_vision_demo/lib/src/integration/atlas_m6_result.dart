import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';

/// Complete, immutable output retained by the M6 integration demo.
final class AtlasM6CameraVisionResult {
  const AtlasM6CameraVisionResult({
    required this.captureResult,
    required this.cupVisionResult,
    required this.saucerVisionResult,
    required this.cupAnalysisDuration,
    required this.saucerAnalysisDuration,
  });

  final CoffeeCameraCaptureResult captureResult;
  final VisionPipelineResult cupVisionResult;
  final VisionPipelineResult saucerVisionResult;
  final Duration cupAnalysisDuration;
  final Duration saucerAnalysisDuration;
}
