import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../analysis/cup_detector.dart';
import '../analysis/debug_analysis_settings.dart';
import '../analysis/device_motion_service.dart';
import '../analysis/frame_analysis_coordinator.dart';
import '../analysis/saucer_analysis_coordinator.dart';
import '../analysis/saucer_detector.dart';
import '../analysis/saucer_residue_analyzer.dart';
import '../camera/camera_service.dart';
import '../config/coffee_camera_config.dart';
import '../guidance/guidance_engine.dart';
import '../guidance/saucer_residue_guidance_engine.dart';
import '../models/camera_capture_result.dart';
import '../models/coffee_camera_capture_result.dart';
import '../models/coffee_region_mask.dart';
import '../models/frame_analysis_result.dart';
import '../models/quality_assessment.dart';
import '../models/residue_analysis_result.dart';
import '../models/saucer_analysis_result.dart';
import '../models/target_geometry.dart';
import '../quality/quality_checker.dart';
import '../quality/saucer_quality_checker.dart';
import '../quality/saucer_ready_stabilizer.dart';
import 'auto_capture_controller.dart';
import 'captured_image_processor.dart';

enum CameraExperiencePhase {
  initializing,
  live,
  capturing,
  reviewing,
  paused,
  completed,
  error,
}

class CoffeeCameraController extends ChangeNotifier {
  CoffeeCameraController({
    required this.config,
    CupDetector? detector,
    SaucerDetector? saucerDetector,
    SaucerResidueAnalyzer? saucerResidueAnalyzer,
    CameraService? cameraService,
    DeviceMotionService? motionService,
    CapturedImageProcessor? imageProcessor,
  }) : detector = detector ?? LightCupDetector(config),
       saucerDetector = saucerDetector ?? LightSaucerDetector(config),
       cameraService = cameraService ?? PluginCameraService(),
       motionService = motionService ?? DeviceMotionService(),
       _imageProcessor = imageProcessor ?? const CapturedImageProcessor(),
       _autoCapture = AutoCaptureController(
         stableDuration: config.autoCaptureStableDuration,
         enabled:
             config.initialAutoCaptureEnabled &&
             (kDebugMode || config.enableReleaseAutoCapture),
       ) {
    _saucerReadyStabilizer = SaucerReadyStabilizer(config);
    _analysis = FrameAnalysisResult.initial(
      cupAnalysisAvailable: this.detector.isAvailable,
    );
    _saucerAnalysis = SaucerAnalysisResult.initial(
      analysisAvailable: this.saucerDetector.isAvailable,
    );
    _coordinator = FrameAnalysisCoordinator(
      config: config,
      detector: this.detector,
      motionService: this.motionService,
      rotationDegrees: () =>
          this.cameraService.description?.sensorOrientation ?? 0,
      isMirrored: () =>
          this.cameraService.description?.lensDirection ==
          CameraLensDirection.front,
      onResult: _onAnalysis,
    );
    _saucerCoordinator = SaucerAnalysisCoordinator(
      config: config,
      detector: this.saucerDetector,
      motionService: this.motionService,
      rotationDegrees: () =>
          this.cameraService.description?.sensorOrientation ?? 0,
      isMirrored: () =>
          this.cameraService.description?.lensDirection ==
          CameraLensDirection.front,
      onResult: _onSaucerAnalysis,
      residueAnalyzer: saucerResidueAnalyzer,
    );
  }

  final CoffeeCameraConfig config;
  final CupDetector detector;
  final SaucerDetector saucerDetector;
  final CameraService cameraService;
  final DeviceMotionService motionService;
  final QualityChecker _qualityChecker = const QualityChecker();
  final SaucerQualityChecker _saucerQualityChecker =
      const SaucerQualityChecker();
  final GuidanceEngine _guidanceEngine = const GuidanceEngine();
  final SaucerResidueGuidanceEngine _saucerGuidanceEngine =
      const SaucerResidueGuidanceEngine();
  final CapturedImageProcessor _imageProcessor;
  final AutoCaptureController _autoCapture;
  late final SaucerReadyStabilizer _saucerReadyStabilizer;
  late final FrameAnalysisCoordinator _coordinator;
  late final SaucerAnalysisCoordinator _saucerCoordinator;

  CameraExperiencePhase _phase = CameraExperiencePhase.initializing;
  CoffeeCaptureStep _currentStep = CoffeeCaptureStep.cup;
  late FrameAnalysisResult _analysis;
  late SaucerAnalysisResult _saucerAnalysis;
  QualityAssessment _assessment = QualityAssessment.unavailable();
  QualityAssessment _saucerAssessment = QualityAssessment.unavailable();
  DebugAnalysisSettings _debugSettings = const DebugAnalysisSettings();
  AutoCaptureUpdate _autoUpdate = const AutoCaptureUpdate(
    phase: AutoCapturePhase.idle,
    progress: 0,
    shouldCapture: false,
  );
  Size _viewportSize = Size.zero;
  String _guidance = '';
  String _saucerGuidance = '';
  CameraCaptureResult? _draftResult;
  CameraCaptureResult? _confirmedCup;
  String? _errorMessage;
  CameraFailureType? _failureType;
  Future<void>? _captureOperation;
  Future<void>? _closeOperation;
  bool _captureInFlight = false;
  bool _cupAnalysisActive = false;
  bool _saucerAnalysisActive = false;
  bool _stabilizedSaucerReady = false;
  bool _closed = false;

  CameraExperiencePhase get phase => _phase;
  CoffeeCaptureStep get currentStep => _currentStep;
  FrameAnalysisResult get analysis => _analysis;
  SaucerAnalysisResult get saucerAnalysis => _saucerAnalysis;
  ResidueAnalysisResult get saucerResidueAnalysis => _saucerAnalysis.residue;
  QualityAssessment get assessment =>
      isCupStep ? _assessment : _saucerAssessment;
  DebugAnalysisSettings get debugSettings => _debugSettings;
  AutoCaptureUpdate get autoUpdate => _autoUpdate;
  CameraCaptureResult? get draftResult => _draftResult;
  CameraCaptureResult? get confirmedCup => _confirmedCup;
  bool get isCupStep => _currentStep == CoffeeCaptureStep.cup;
  bool get cupAnalysisActive => isCupStep && _cupAnalysisActive;
  bool get saucerAnalysisActive => !isCupStep && _saucerAnalysisActive;
  bool get isReviewingConfirmedCup =>
      isCupStep &&
      _phase == CameraExperiencePhase.reviewing &&
      _draftResult == null &&
      _confirmedCup != null;
  bool get canGoBackToCup =>
      config.requireSaucerCapture &&
      _currentStep == CoffeeCaptureStep.saucer &&
      _confirmedCup != null;
  String get guidance => _phase == CameraExperiencePhase.capturing
      ? config.strings.capturing
      : isCupStep
      ? _guidance
      : _saucerGuidance;
  String? get previewPath => _previewResult?.filePath;
  String? get errorMessage => _errorMessage;
  CameraFailureType? get failureType => _failureType;
  CameraController? get cameraController => cameraService.controller;
  bool get hasMultipleCameras => cameraService.hasMultipleCameras;
  FlashMode get flashMode => cameraService.flashMode;
  bool get autoCaptureVisible =>
      isCupStep &&
      _analysis.cupAnalysisAvailable &&
      (kDebugMode || config.enableReleaseAutoCapture);
  bool get autoCaptureEnabled => _autoCapture.enabled;
  bool get coffeeDetected => isCupStep && _analysis.coffeeDetected;
  bool get captureReady =>
      isCupStep ? _assessment.autoCaptureReady : _stabilizedSaucerReady;
  bool get stabilizedSaucerReady => _stabilizedSaucerReady;
  int get displayQualityScore =>
      !isCupStep && !_stabilizedSaucerReady && _saucerAssessment.score == 100
      ? 99
      : assessment.score;
  double get coffeePresenceScore =>
      isCupStep ? _analysis.coffeePresenceScore : 0;
  CoffeeRegionMask? get coffeeMask => isCupStep ? _analysis.coffeeMask : null;
  bool get scanActive =>
      isCupStep &&
      coffeeDetected &&
      (_phase == CameraExperiencePhase.live ||
          _phase == CameraExperiencePhase.capturing);
  String? get previewDisplayPath {
    final result = _previewResult;
    return result?.croppedImagePath ?? result?.filePath;
  }

  bool get canCapture =>
      _phase == CameraExperiencePhase.live && !_captureInFlight;

  CameraCaptureResult? get _previewResult =>
      _draftResult ?? (isCupStep ? _confirmedCup : null);

  Future<void> initialize() async {
    if (_closed) return;
    _phase = CameraExperiencePhase.initializing;
    _errorMessage = null;
    _failureType = null;
    _notify();
    try {
      await cameraService.initialize();
      await _enterLiveStep();
    } on CameraFailure catch (error) {
      _setError(error);
    } on Object catch (error) {
      _setError(CameraFailure(CameraFailureType.unknown, error.toString()));
    }
  }

  Future<void> retry() async {
    if (_closed) return;
    _coordinator.pause();
    _saucerCoordinator.pause();
    await motionService.stop();
    await cameraService.dispose();
    await initialize();
  }

  void setViewportSize(Size value) {
    if (value == _viewportSize || value.isEmpty) return;
    _viewportSize = value;
    _coordinator.setViewportSize(value);
    _saucerCoordinator.setViewportSize(value);
    if (isCupStep) {
      _evaluate(DateTime.now());
    } else {
      _evaluateSaucer();
    }
  }

  void setDebugSettings(DebugAnalysisSettings value) {
    if (!kDebugMode || !isCupStep) return;
    _debugSettings = value;
    _evaluate(DateTime.now());
  }

  void setAutoCaptureEnabled(bool value) {
    if (!autoCaptureVisible) return;
    _autoCapture.setEnabled(value);
    _resetAutoCapture();
    _notify();
  }

  void _onAnalysis(FrameAnalysisResult result) {
    if (!cupAnalysisActive) return;
    _analysis = result;
    _evaluate(result.timestamp);
  }

  void _onSaucerAnalysis(SaucerAnalysisResult result) {
    if (!saucerAnalysisActive) return;
    _saucerAnalysis = result;
    _evaluateSaucer();
  }

  void _evaluate(DateTime now) {
    if (_viewportSize.isEmpty) return;
    final effective = kDebugMode
        ? _debugSettings.apply(
            source: _analysis,
            viewportSize: _viewportSize,
            config: config,
          )
        : _analysis;
    _analysis = effective;
    _assessment = _qualityChecker.assess(
      result: effective,
      viewportSize: _viewportSize,
      config: config,
    );
    _guidance = _guidanceEngine.message(
      result: effective,
      assessment: _assessment,
      config: config,
    );
    if (cupAnalysisActive && _phase == CameraExperiencePhase.live) {
      _autoUpdate = _autoCapture.update(
        ready: _assessment.autoCaptureReady && effective.coffeeDetected,
        now: now,
      );
      if (_autoUpdate.shouldCapture) {
        unawaited(capture(CameraCaptureMode.automatic));
      }
    }
    _notify();
  }

  void _evaluateSaucer() {
    if (_viewportSize.isEmpty) return;
    _saucerAssessment = _saucerQualityChecker.assess(
      result: _saucerAnalysis,
      viewportSize: _viewportSize,
      config: config,
    );
    _stabilizedSaucerReady = _saucerReadyStabilizer.update(
      result: _saucerAnalysis,
      assessment: _saucerAssessment,
      viewportSize: _viewportSize,
    );
    _saucerGuidance = _saucerGuidanceEngine.message(
      residue: _saucerAnalysis.residue,
      assessment: _saucerAssessment,
      config: config,
    );
    _notify();
  }

  Future<void> capture(CameraCaptureMode mode) {
    if (!canCapture || (!isCupStep && mode == CameraCaptureMode.automatic)) {
      return Future<void>.value();
    }
    final operation = _performCapture(mode);
    _captureOperation = operation;
    return operation.whenComplete(() {
      if (identical(_captureOperation, operation)) _captureOperation = null;
    });
  }

  Future<void> _performCapture(CameraCaptureMode requestedMode) async {
    final step = _currentStep;
    final mode = step == CoffeeCaptureStep.cup
        ? requestedMode
        : CameraCaptureMode.manual;
    final qualityScore = step == CoffeeCaptureStep.cup
        ? _assessment.score
        : _saucerAssessment.score;
    final coffeeDetected =
        step == CoffeeCaptureStep.cup && _analysis.coffeeDetected;
    final coffeeScore = step == CoffeeCaptureStep.cup
        ? _analysis.coffeePresenceScore
        : 0.0;
    final detectedBounds = step == CoffeeCaptureStep.cup
        ? _analysis.cup?.normalizedBounds
        : _saucerAnalysis.saucer?.normalizedBounds;
    final targetGeometry = step == CoffeeCaptureStep.saucer
        ? TargetGeometry.forSaucer(_viewportSize, config.saucerConfig)
        : null;
    _captureInFlight = true;
    _cupAnalysisActive = false;
    _saucerAnalysisActive = false;
    _phase = CameraExperiencePhase.capturing;
    _resetAutoCapture();
    _coordinator.pause();
    _saucerCoordinator.pause();
    _notify();

    String? originalPath;
    String? croppedPath;
    try {
      final file = await cameraService.takePicture();
      originalPath = file.path;
      final capturedAt = DateTime.now();
      final processed = await _imageProcessor.process(
        path: file.path,
        viewportSize: _viewportSize,
        config: config,
        normalizedSubjectBounds: detectedBounds,
        previewMirrored:
            cameraService.description?.lensDirection ==
            CameraLensDirection.front,
        createCrop: true,
        targetGeometry: targetGeometry,
        cropPaddingRatio: step == CoffeeCaptureStep.saucer
            ? config.saucerConfig.cropPaddingRatio
            : null,
        cropFileSuffix: step == CoffeeCaptureStep.saucer
            ? 'saucer_crop'
            : 'cup_crop',
      );
      croppedPath = processed.croppedPath;
      if (_closed) {
        await _deletePaths([originalPath, croppedPath]);
        return;
      }
      await motionService.stop();
      if (_closed) {
        await _deletePaths([originalPath, croppedPath]);
        return;
      }
      _draftResult = CameraCaptureResult(
        filePath: processed.originalPath,
        croppedCupPath: step == CoffeeCaptureStep.cup
            ? processed.croppedPath
            : null,
        croppedSaucerPath: step == CoffeeCaptureStep.saucer
            ? processed.croppedPath
            : null,
        cropRect: processed.cropRect,
        widthPixels: processed.originalWidth,
        heightPixels: processed.originalHeight,
        fileSizeBytes: processed.originalBytes,
        croppedWidthPixels: processed.croppedWidth,
        croppedHeightPixels: processed.croppedHeight,
        croppedFileSizeBytes: processed.croppedBytes,
        capturedAt: capturedAt,
        qualityScore: qualityScore,
        coffeePresenceScore: coffeeScore,
        coffeeDetected: coffeeDetected,
        mode: mode,
      );
      originalPath = null;
      croppedPath = null;
      _phase = CameraExperiencePhase.reviewing;
    } on CameraFailure catch (error) {
      await _deletePaths([originalPath, croppedPath]);
      if (!_closed) _setError(error);
    } on Object catch (error) {
      await _deletePaths([originalPath, croppedPath]);
      if (!_closed) {
        _setError(CameraFailure(CameraFailureType.unknown, error.toString()));
      }
    } finally {
      _captureInFlight = false;
      _notify();
    }
  }

  Future<void> retake() async {
    if (_phase != CameraExperiencePhase.reviewing || _closed) return;
    if (isReviewingConfirmedCup) {
      await _deleteConfirmedCup();
    } else {
      await _deleteDraft();
    }
    try {
      await _enterLiveStep();
    } on CameraFailure catch (error) {
      _setError(error);
    }
  }

  Future<CameraCaptureResult?> takeApprovedResult() async {
    if (config.requireSaucerCapture) {
      throw StateError(
        'Use takeApprovedFlowResult when requireSaucerCapture is enabled.',
      );
    }
    final result = await takeApprovedFlowResult();
    return result?.cup;
  }

  Future<CoffeeCameraCaptureResult?> takeApprovedFlowResult() async {
    if (_phase != CameraExperiencePhase.reviewing || _closed) return null;
    if (isCupStep) {
      final draft = _draftResult;
      if (draft != null) {
        _confirmedCup = draft;
        _draftResult = null;
      }
      final cup = _confirmedCup;
      if (cup == null) return null;
      if (config.requireSaucerCapture) {
        _currentStep = CoffeeCaptureStep.saucer;
        try {
          await _enterLiveStep();
        } on CameraFailure catch (error) {
          _setError(error);
        }
        return null;
      }
      return _complete(CoffeeCameraCaptureResult(cup: cup));
    }

    final cup = _confirmedCup;
    final saucer = _draftResult;
    if (cup == null || saucer == null) return null;
    return _complete(CoffeeCameraCaptureResult(cup: cup, saucer: saucer));
  }

  CoffeeCameraCaptureResult _complete(CoffeeCameraCaptureResult result) {
    _draftResult = null;
    _confirmedCup = null;
    _phase = CameraExperiencePhase.completed;
    _resetAutoCapture();
    _notify();
    return result;
  }

  Future<bool> backToPreviousStep() async {
    if (!canGoBackToCup || _closed) return false;
    final capture = _captureOperation;
    if (capture != null) await capture;
    if (_closed) return false;
    await _deleteDraft();
    _coordinator.pause();
    _saucerCoordinator.pause();
    _cupAnalysisActive = false;
    _saucerAnalysisActive = false;
    await motionService.stop();
    await cameraService.stopFrameStream();
    _currentStep = CoffeeCaptureStep.cup;
    _phase = CameraExperiencePhase.reviewing;
    _clearTransientDetection();
    _resetAutoCapture();
    _notify();
    return true;
  }

  Future<void> switchCamera() async {
    if (_phase != CameraExperiencePhase.live) return;
    _cupAnalysisActive = false;
    _saucerAnalysisActive = false;
    _coordinator.pause();
    _saucerCoordinator.pause();
    await cameraService.switchCamera();
    if (isCupStep) {
      _resetCupAnalysisState();
      _coordinator.resume();
      _cupAnalysisActive = true;
    } else {
      _resetSaucerAnalysisState();
      _saucerCoordinator.resume();
      _saucerAnalysisActive = true;
    }
    _notify();
  }

  Future<void> cycleFlashMode() async {
    await cameraService.cycleFlashMode();
    _notify();
  }

  Future<void> focusAt(Offset normalizedPoint) {
    return cameraService.setFocusPoint(normalizedPoint);
  }

  Future<void> pause() async {
    if (_closed) return;
    _cupAnalysisActive = false;
    _saucerAnalysisActive = false;
    _coordinator.pause();
    _saucerCoordinator.pause();
    final capture = _captureOperation;
    if (capture != null) await capture;
    await motionService.stop();
    await cameraService.pause();
    if (_phase == CameraExperiencePhase.live) {
      _phase = CameraExperiencePhase.paused;
      _notify();
    }
  }

  Future<void> resume() async {
    if (_closed || _phase != CameraExperiencePhase.paused) return;
    try {
      await _enterLiveStep();
    } on CameraFailure catch (error) {
      _setError(error);
    }
  }

  Future<void> _enterLiveStep() async {
    if (_closed) return;
    if (!cameraService.isInitialized) await cameraService.resume();
    _resetAutoCapture();
    if (isCupStep) {
      _resetCupAnalysisState();
      motionService.start();
      _coordinator.resume();
      _saucerCoordinator.pause();
      _cupAnalysisActive = true;
      _saucerAnalysisActive = false;
      await cameraService.startFrameStream(_coordinator.onFrame);
    } else {
      _cupAnalysisActive = false;
      _saucerAnalysisActive = true;
      _resetSaucerAnalysisState();
      _coordinator.pause();
      _saucerCoordinator.resume();
      motionService.start();
      await cameraService.startFrameStream(_saucerCoordinator.onFrame);
    }
    _phase = CameraExperiencePhase.live;
    _notify();
  }

  void _setError(CameraFailure error) {
    if (_closed) return;
    _cupAnalysisActive = false;
    _saucerAnalysisActive = false;
    _coordinator.pause();
    _saucerCoordinator.pause();
    _saucerReadyStabilizer.reset();
    _stabilizedSaucerReady = false;
    _resetAutoCapture();
    _failureType = error.type;
    _errorMessage = error.message;
    _phase = CameraExperiencePhase.error;
    _notify();
  }

  void _clearTransientDetection() {
    _analysis = _analysis.copyWith(
      coffeeDetected: false,
      clearCoffeeMask: true,
      clearCup: true,
      coffeePresenceScore: 0,
      darkPixelRatio: 0,
    );
    _assessment = QualityAssessment.unavailable();
    _saucerAnalysis = _saucerAnalysis.copyWith(
      clearSaucer: true,
      clearResidue: true,
    );
    _saucerAssessment = QualityAssessment.unavailable();
    _saucerReadyStabilizer.reset();
    _stabilizedSaucerReady = false;
    _saucerGuidance = config.strings.positionSaucerResidue;
    _guidance = config.strings.bringCupToTarget;
  }

  void _resetCupAnalysisState() {
    _analysis = FrameAnalysisResult.initial(
      cupAnalysisAvailable: detector.isAvailable,
      timestamp: DateTime.now(),
    );
    _assessment = QualityAssessment.unavailable();
    _guidance = config.strings.bringCupToTarget;
  }

  void _resetSaucerAnalysisState() {
    _saucerAnalysis = SaucerAnalysisResult.initial(
      analysisAvailable: saucerDetector.isAvailable,
      timestamp: DateTime.now(),
    );
    _saucerAssessment = QualityAssessment.unavailable();
    _saucerReadyStabilizer.reset();
    _stabilizedSaucerReady = false;
    _saucerGuidance = config.strings.positionSaucerResidue;
  }

  void _resetAutoCapture() {
    _autoCapture.reset();
    _autoUpdate = const AutoCaptureUpdate(
      phase: AutoCapturePhase.idle,
      progress: 0,
      shouldCapture: false,
    );
  }

  Future<void> _deleteDraft() async {
    final result = _draftResult;
    _draftResult = null;
    await _deleteResults([result]);
  }

  Future<void> _deleteConfirmedCup() async {
    final result = _confirmedCup;
    _confirmedCup = null;
    await _deleteResults([result]);
  }

  Future<void> _deleteOwnedResults() async {
    final draft = _draftResult;
    final cup = _confirmedCup;
    _draftResult = null;
    _confirmedCup = null;
    await _deleteResults([draft, cup]);
  }

  Future<void> _deleteResults(Iterable<CameraCaptureResult?> results) {
    final paths = <String>{};
    for (final result in results) {
      if (result == null) continue;
      paths.add(result.filePath);
      final croppedPath = result.croppedCupPath;
      if (croppedPath != null) paths.add(croppedPath);
      final croppedSaucerPath = result.croppedSaucerPath;
      if (croppedSaucerPath != null) paths.add(croppedSaucerPath);
    }
    return _deletePaths(paths);
  }

  Future<void> _deletePaths(Iterable<String?> paths) async {
    for (final path in paths.whereType<String>().toSet()) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Cleanup is best effort; ownership is still released by the module.
      }
    }
  }

  Future<void> close() => _closeOperation ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _cupAnalysisActive = false;
    _saucerAnalysisActive = false;
    _coordinator.pause();
    _saucerCoordinator.pause();
    final capture = _captureOperation;
    if (capture != null) await capture;
    await _deleteOwnedResults();
    await motionService.stop();
    await cameraService.dispose();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
