import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';

import '../config/coffee_camera_config.dart';
import '../models/saucer_analysis_result.dart';
import '../models/saucer_detection_result.dart';
import '../quality/saucer_failure_classifier.dart';
import 'device_motion_service.dart';
import 'frame_metrics_analyzer.dart';
import 'saucer_detector.dart';
import 'saucer_residue_analyzer.dart';
import 'saucer_residue_stabilizer.dart';

class SaucerAnalysisCoordinator {
  SaucerAnalysisCoordinator({
    required this.config,
    required this.detector,
    required this.motionService,
    required this.rotationDegrees,
    required this.isMirrored,
    required this.onResult,
    this.metricsAnalyzer = const FrameMetricsAnalyzer(),
    SaucerResidueAnalyzer? residueAnalyzer,
  }) : residueAnalyzer = residueAnalyzer ?? const SaucerResidueAnalyzer(),
       _residueStabilizer = SaucerResidueStabilizer(
         config.saucerConfig.residueProfile,
       );

  final CoffeeCameraConfig config;
  final SaucerDetector detector;
  final DeviceMotionService motionService;
  final int Function() rotationDegrees;
  final bool Function() isMirrored;
  final void Function(SaucerAnalysisResult result) onResult;
  final FrameMetricsAnalyzer metricsAnalyzer;
  final SaucerResidueAnalyzer residueAnalyzer;
  final SaucerResidueStabilizer _residueStabilizer;
  final SaucerFailureClassifier _failureClassifier =
      const SaucerFailureClassifier();

  bool _busy = false;
  bool _paused = false;
  DateTime? _lastStartedAt;
  Size _viewportSize = Size.zero;

  void setViewportSize(Size value) {
    _viewportSize = value;
  }

  void onFrame(CameraImage image) {
    final now = DateTime.now();
    if (_paused || _busy || _viewportSize.isEmpty) return;
    final previous = _lastStartedAt;
    if (previous != null &&
        now.difference(previous) < config.analysisInterval) {
      return;
    }
    _lastStartedAt = now;
    _busy = true;
    unawaited(_process(image, now));
  }

  Future<void> _process(CameraImage image, DateTime timestamp) async {
    try {
      final frame = metricsAnalyzer.copyFrame(
        image,
        rotationDegrees: rotationDegrees(),
        viewportSize: _viewportSize,
        mirrored: isMirrored(),
      );
      final metricsFuture = metricsAnalyzer.analyze(frame);
      SaucerDetectionResult? saucer;
      if (detector.isAvailable) {
        try {
          saucer = await detector.detect(frame);
        } on Object {
          saucer = null;
        }
      }
      final residue = await residueAnalyzer.analyze(
        frame: frame,
        saucer: saucer,
        profile: config.saucerConfig.residueProfile,
      );
      final metrics = await metricsFuture;
      final motion = motionService.snapshot;
      if (_paused) return;
      final rawResult = SaucerAnalysisResult(
        analysisAvailable: detector.isAvailable,
        saucer: saucer,
        brightness: metrics.brightness,
        sharpness: metrics.sharpness,
        angleDegrees: motion.angleDegrees,
        isStable: motion.isAvailable && motion.isStable,
        timestamp: timestamp,
        residue: residue,
      );
      final hardFailure = _failureClassifier.isHardFailure(
        result: rawResult,
        viewportSize: _viewportSize,
        config: config,
      );
      onResult(
        rawResult.copyWith(
          residue: _residueStabilizer.update(residue, hardFailure: hardFailure),
        ),
      );
    } on Object {
      // A bad frame is skipped so the next camera frame can be analyzed.
    } finally {
      _busy = false;
    }
  }

  void pause() {
    _paused = true;
    _residueStabilizer.reset();
  }

  void resume() {
    _paused = false;
    _lastStartedAt = null;
    _residueStabilizer.reset();
  }
}
