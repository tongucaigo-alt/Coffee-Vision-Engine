import 'package:coffee_camera/coffee_camera.dart';

import 'atlas_k6_result.dart';

enum AtlasK6Phase {
  idle,
  capturing,
  processingCup,
  processingSaucer,
  success,
  failure,
}

enum AtlasK6FailureStage { capture, cupProcessing, saucerProcessing }

final class AtlasK6State {
  const AtlasK6State._({
    required this.phase,
    this.captureResult,
    this.cupResult,
    this.saucerResult,
    this.failureStage,
    this.errorMessage,
    this.result,
  });

  const AtlasK6State.idle() : this._(phase: AtlasK6Phase.idle);

  factory AtlasK6State.capturing(AtlasK6State previous) {
    return AtlasK6State._(
      phase: AtlasK6Phase.capturing,
      captureResult: previous.captureResult,
      cupResult: previous.cupResult,
      saucerResult: previous.saucerResult,
      result: previous.result,
    );
  }

  const AtlasK6State.processingCup({
    required CoffeeCameraCaptureResult captureResult,
  }) : this._(phase: AtlasK6Phase.processingCup, captureResult: captureResult);

  const AtlasK6State.processingSaucer({
    required CoffeeCameraCaptureResult captureResult,
    required AtlasK6SurfaceResult cupResult,
  }) : this._(
         phase: AtlasK6Phase.processingSaucer,
         captureResult: captureResult,
         cupResult: cupResult,
       );

  AtlasK6State.success(AtlasK6EndToEndResult result)
    : this._(
        phase: AtlasK6Phase.success,
        captureResult: result.captureResult,
        cupResult: result.cupResult,
        saucerResult: result.saucerResult,
        result: result,
      );

  const AtlasK6State.failure({
    required AtlasK6FailureStage failureStage,
    required String errorMessage,
    CoffeeCameraCaptureResult? captureResult,
    AtlasK6SurfaceResult? cupResult,
  }) : this._(
         phase: AtlasK6Phase.failure,
         captureResult: captureResult,
         cupResult: cupResult,
         failureStage: failureStage,
         errorMessage: errorMessage,
       );

  final AtlasK6Phase phase;
  final CoffeeCameraCaptureResult? captureResult;
  final AtlasK6SurfaceResult? cupResult;
  final AtlasK6SurfaceResult? saucerResult;
  final AtlasK6FailureStage? failureStage;
  final String? errorMessage;
  final AtlasK6EndToEndResult? result;

  bool get isBusy => switch (phase) {
    AtlasK6Phase.capturing ||
    AtlasK6Phase.processingCup ||
    AtlasK6Phase.processingSaucer => true,
    _ => false,
  };

  bool get canRetry =>
      phase == AtlasK6Phase.failure &&
      captureResult != null &&
      failureStage != AtlasK6FailureStage.capture;

  AtlasK6AggregateOutcome? get aggregateOutcome => switch (phase) {
    AtlasK6Phase.success => result!.outcome,
    AtlasK6Phase.failure => AtlasK6AggregateOutcome.technicalError,
    _ => null,
  };
}
