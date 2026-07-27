import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';

import 'atlas_m6_result.dart';

enum AtlasM6Phase {
  idle,
  capturing,
  analyzingCup,
  analyzingSaucer,
  success,
  failure,
}

enum AtlasM6FailureStage { capture, cupAnalysis, saucerAnalysis }

final class AtlasM6State {
  const AtlasM6State._({
    required this.phase,
    this.captureResult,
    this.cupVisionResult,
    this.saucerVisionResult,
    this.cupAnalysisDuration,
    this.saucerAnalysisDuration,
    this.failureStage,
    this.errorMessage,
    this.result,
  });

  const AtlasM6State.idle() : this._(phase: AtlasM6Phase.idle);

  factory AtlasM6State.capturing(AtlasM6State previous) {
    return AtlasM6State._(
      phase: AtlasM6Phase.capturing,
      captureResult: previous.captureResult,
      cupVisionResult: previous.cupVisionResult,
      saucerVisionResult: previous.saucerVisionResult,
      cupAnalysisDuration: previous.cupAnalysisDuration,
      saucerAnalysisDuration: previous.saucerAnalysisDuration,
      result: previous.result,
    );
  }

  const AtlasM6State.analyzingCup({
    required CoffeeCameraCaptureResult captureResult,
  }) : this._(phase: AtlasM6Phase.analyzingCup, captureResult: captureResult);

  const AtlasM6State.analyzingSaucer({
    required CoffeeCameraCaptureResult captureResult,
    required VisionPipelineResult cupVisionResult,
    required Duration cupAnalysisDuration,
  }) : this._(
         phase: AtlasM6Phase.analyzingSaucer,
         captureResult: captureResult,
         cupVisionResult: cupVisionResult,
         cupAnalysisDuration: cupAnalysisDuration,
       );

  AtlasM6State.success(AtlasM6CameraVisionResult result)
    : this._(
        phase: AtlasM6Phase.success,
        captureResult: result.captureResult,
        cupVisionResult: result.cupVisionResult,
        saucerVisionResult: result.saucerVisionResult,
        cupAnalysisDuration: result.cupAnalysisDuration,
        saucerAnalysisDuration: result.saucerAnalysisDuration,
        result: result,
      );

  const AtlasM6State.failure({
    required AtlasM6FailureStage failureStage,
    required String errorMessage,
    CoffeeCameraCaptureResult? captureResult,
    VisionPipelineResult? cupVisionResult,
    Duration? cupAnalysisDuration,
    Duration? saucerAnalysisDuration,
  }) : this._(
         phase: AtlasM6Phase.failure,
         captureResult: captureResult,
         cupVisionResult: cupVisionResult,
         cupAnalysisDuration: cupAnalysisDuration,
         saucerAnalysisDuration: saucerAnalysisDuration,
         failureStage: failureStage,
         errorMessage: errorMessage,
       );

  final AtlasM6Phase phase;
  final CoffeeCameraCaptureResult? captureResult;
  final VisionPipelineResult? cupVisionResult;
  final VisionPipelineResult? saucerVisionResult;
  final Duration? cupAnalysisDuration;
  final Duration? saucerAnalysisDuration;
  final AtlasM6FailureStage? failureStage;
  final String? errorMessage;
  final AtlasM6CameraVisionResult? result;

  bool get isBusy => switch (phase) {
    AtlasM6Phase.capturing ||
    AtlasM6Phase.analyzingCup ||
    AtlasM6Phase.analyzingSaucer => true,
    _ => false,
  };

  bool get canRetry =>
      phase == AtlasM6Phase.failure &&
      captureResult != null &&
      failureStage != AtlasM6FailureStage.capture;
}
