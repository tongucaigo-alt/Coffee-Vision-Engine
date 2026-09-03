import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';

import '../config/coffee_camera_config.dart';
import '../models/cup_detection_result.dart';
import '../models/frame_analysis_result.dart';
import 'coffee_detection_stabilizer.dart';
import 'coffee_region_analyzer.dart';
import 'cup_detector.dart';
import 'device_motion_service.dart';
import 'frame_metrics_analyzer.dart';

class FrameAnalysisCoordinator {
  FrameAnalysisCoordinator({
    required this.config,
    required this.detector,
    required this.motionService,
    required this.rotationDegrees,
    required this.isMirrored,
    required this.onResult,
    this.metricsAnalyzer = const FrameMetricsAnalyzer(),
    this.coffeeRegionAnalyzer = const CoffeeRegionAnalyzer(),
  }) : _coffeeStabilizer = CoffeeDetectionStabilizer(config);

  final CoffeeCameraConfig config;
  final CupDetector detector;
  final DeviceMotionService motionService;
  final int Function() rotationDegrees;
  final bool Function() isMirrored;
  final void Function(FrameAnalysisResult result) onResult;
  final FrameMetricsAnalyzer metricsAnalyzer;
  final CoffeeRegionAnalyzer coffeeRegionAnalyzer;
  final CoffeeDetectionStabilizer _coffeeStabilizer;

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
      CupDetectionResult? cup;
      if (detector.isAvailable) {
        try {
          cup = await detector.detect(frame);
        } on Object {
          cup = null;
        }
      }
      final metrics = await metricsFuture;
      final coffee = await coffeeRegionAnalyzer.analyze(
        frame: frame,
        cup: cup,
        config: config,
      );
      final motion = motionService.snapshot;
      if (_paused) return;
      final rawResult = FrameAnalysisResult(
        cupAnalysisAvailable: detector.isAvailable,
        cup: cup,
        brightness: metrics.brightness,
        sharpness: metrics.sharpness,
        darkPixelRatio: coffee.coverage,
        coffeePresenceScore: coffee.score,
        coffeeMask: coffee.mask,
        angleDegrees: motion.angleDegrees,
        isStable: motion.isAvailable && motion.isStable,
        timestamp: timestamp,
      );
      onResult(_coffeeStabilizer.update(rawResult));
    } on Object {
      // A bad frame is skipped; the live camera and next frame keep running.
    } finally {
      _busy = false;
    }
  }

  void pause() {
    _paused = true;
    _coffeeStabilizer.reset();
  }

  void resume() {
    _paused = false;
    _lastStartedAt = null;
    _coffeeStabilizer.reset();
  }
}
