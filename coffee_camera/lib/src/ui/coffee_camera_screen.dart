import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../analysis/cup_detector.dart';
import '../analysis/device_motion_service.dart';
import '../analysis/saucer_detector.dart';
import '../camera/camera_service.dart';
import '../capture/coffee_camera_controller.dart';
import '../capture/captured_image_processor.dart';
import '../config/coffee_camera_config.dart';
import '../models/camera_capture_result.dart';
import '../models/coffee_camera_capture_result.dart';
import '../models/residue_analysis_result.dart';
import '../models/target_geometry.dart';
import 'camera_target_overlay.dart';
import 'debug_analysis_panel.dart';
import 'photo_preview.dart';
import 'saucer_residue_painter.dart';

class CoffeeCameraScreen extends StatefulWidget {
  const CoffeeCameraScreen({
    super.key,
    required this.onApproved,
    required this.onCancelled,
    this.config = const CoffeeCameraConfig(),
    this.detector,
    this.saucerDetector,
    this.cameraService,
    this.motionService,
    this.imageProcessor,
    this.onSaucerResidueAnalysis,
  }) : onCompleted = null,
       flowMode = false;

  const CoffeeCameraScreen.flow({
    super.key,
    required this.onCompleted,
    required this.onCancelled,
    this.config = const CoffeeCameraConfig(),
    this.detector,
    this.saucerDetector,
    this.cameraService,
    this.motionService,
    this.imageProcessor,
    this.onSaucerResidueAnalysis,
  }) : onApproved = null,
       flowMode = true;

  final ValueChanged<CameraCaptureResult>? onApproved;
  final ValueChanged<CoffeeCameraCaptureResult>? onCompleted;
  final VoidCallback onCancelled;
  final CoffeeCameraConfig config;
  final CupDetector? detector;
  final SaucerDetector? saucerDetector;
  final bool flowMode;
  final ValueChanged<ResidueAnalysisResult>? onSaucerResidueAnalysis;

  @visibleForTesting
  final CameraService? cameraService;

  @visibleForTesting
  final DeviceMotionService? motionService;

  @visibleForTesting
  final CapturedImageProcessor? imageProcessor;

  @override
  State<CoffeeCameraScreen> createState() => _CoffeeCameraScreenState();
}

class _CoffeeCameraScreenState extends State<CoffeeCameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _effectAnimationPeriod = Duration(milliseconds: 5400);

  late final CoffeeCameraController _controller;
  late final AnimationController _scanAnimation;
  bool _closing = false;
  bool _backInFlight = false;
  bool _approvalInFlight = false;
  bool _appIsActive = true;
  ResidueAnalysisResult? _lastReportedResidueAnalysis;

  @override
  void initState() {
    super.initState();
    if (!widget.flowMode && widget.config.requireSaucerCapture) {
      throw ArgumentError.value(
        widget.config.requireSaucerCapture,
        'config.requireSaucerCapture',
        'Use CoffeeCameraScreen.flow for two-step capture.',
      );
    }
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appIsActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _controller = CoffeeCameraController(
      config: widget.config,
      detector: widget.detector,
      saucerDetector: widget.saucerDetector,
      cameraService: widget.cameraService,
      motionService: widget.motionService,
      imageProcessor: widget.imageProcessor,
    )..addListener(_onChanged);
    _scanAnimation = AnimationController(
      vsync: this,
      duration: _effectAnimationPeriod,
    );
    unawaited(_controller.initialize());
  }

  void _onChanged() {
    if (!mounted) return;
    final residue = _controller.saucerResidueAnalysis;
    if (_controller.currentStep == CoffeeCaptureStep.saucer &&
        residue.analysisPerformed &&
        !identical(residue, _lastReportedResidueAnalysis)) {
      _lastReportedResidueAnalysis = residue;
      widget.onSaucerResidueAnalysis?.call(residue);
    }
    _syncScanAnimation();
    setState(() {});
  }

  bool get _cameraAnimationsActive =>
      _appIsActive &&
      (_controller.phase == CameraExperiencePhase.live ||
          _controller.phase == CameraExperiencePhase.capturing);

  void _syncScanAnimation() {
    if (_cameraAnimationsActive) {
      if (!_scanAnimation.isAnimating) _scanAnimation.repeat();
      return;
    }
    _scanAnimation.stop(canceled: false);
    if (_scanAnimation.value != 0) _scanAnimation.value = 0;
  }

  double _loopProgress(int cycles) {
    final progress = (_scanAnimation.value * cycles) % 1;
    return progress == 0 ? 0.0001 : progress;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _syncScanAnimation();
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.resume());
    }
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _closing = true;
    await _controller.close();
    widget.onCancelled();
  }

  Future<void> _back() async {
    if (_closing || _backInFlight) return;
    _backInFlight = true;
    try {
      if (await _controller.backToPreviousStep()) return;
      await _cancel();
    } finally {
      _backInFlight = false;
    }
  }

  Future<void> _approve() async {
    if (_closing || _approvalInFlight) return;
    _approvalInFlight = true;
    try {
      final result = await _controller.takeApprovedFlowResult();
      if (result == null) return;
      _closing = true;
      if (widget.flowMode) {
        widget.onCompleted!(result);
      } else {
        widget.onApproved!(result.cup);
      }
    } finally {
      _approvalInFlight = false;
    }
  }

  String? get _stepLabel {
    if (!widget.config.requireSaucerCapture) return null;
    return switch (_controller.currentStep) {
      CoffeeCaptureStep.cup => widget.config.strings.cupCaptureStep,
      CoffeeCaptureStep.saucer => widget.config.strings.saucerCaptureStep,
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimation.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: widget.config.theme.background,
        body: switch (_controller.phase) {
          CameraExperiencePhase.initializing => _buildLoading(),
          CameraExperiencePhase.error => _buildError(),
          CameraExperiencePhase.reviewing => _buildPreview(),
          _ => _buildCamera(),
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Stack(
      children: [
        const Center(child: CircularProgressIndicator()),
        _topBar(showCameraActions: false),
      ],
    );
  }

  Widget _buildError() {
    final permissionDenied =
        _controller.failureType == CameraFailureType.permissionDenied ||
        _controller.failureType == CameraFailureType.restricted;
    final message = permissionDenied
        ? widget.config.strings.cameraPermissionDenied
        : widget.config.strings.cameraUnavailable;
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  permissionDenied
                      ? Icons.no_photography_outlined
                      : Icons.camera_alt_outlined,
                  size: 52,
                  color: widget.config.theme.mutedForeground,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_controller.errorMessage case final detail?) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.config.theme.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(widget.config.strings.retry),
                ),
              ],
            ),
          ),
        ),
        _topBar(showCameraActions: false),
      ],
    );
  }

  Widget _buildPreview() {
    return PhotoPreview(
      filePath: _controller.previewDisplayPath!,
      config: widget.config,
      title: _stepLabel,
      onBack: widget.config.requireSaucerCapture ? _back : null,
      onRetake: _controller.retake,
      onApprove: _approve,
    );
  }

  Widget _buildCamera() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controller.setViewportSize(size);
        });
        final assessment = _controller.assessment;
        final isCupStep = _controller.isCupStep;
        final isReady = _controller.captureReady;
        final ringColor = isReady
            ? widget.config.theme.readyRing
            : !assessment.cupDetected
            ? widget.config.theme.idleRing
            : widget.config.theme.warningRing;
        final targetGeometry = isCupStep
            ? TargetGeometry.fromViewport(size, widget.config)
            : TargetGeometry.forSaucer(size, widget.config.saucerConfig);
        return Stack(
          fit: StackFit.expand,
          children: [
            _cameraPreview(size),
            IgnorePointer(
              child: TickerMode(
                key: const Key('coffee-camera-effects-ticker'),
                enabled: _appIsActive,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, _) => CameraTargetOverlay(
                        config: widget.config,
                        effectProfile: isCupStep
                            ? CaptureEffectProfile.cup
                            : CaptureEffectProfile.saucer,
                        ringColor: ringColor,
                        isReady: isReady,
                        progress: isCupStep
                            ? _controller.autoUpdate.progress
                            : 0,
                        scanProgress: _controller.scanActive
                            ? _loopProgress(4)
                            : 0,
                        saucerSweepProgress:
                            !isCupStep && assessment.cupDetected
                            ? _loopProgress(2)
                            : 0,
                        subjectDetected: assessment.cupDetected,
                        coffeeDetected: isCupStep && _controller.coffeeDetected,
                        coffeeMask: isCupStep ? _controller.coffeeMask : null,
                        targetGeometry: targetGeometry,
                        flash:
                            _controller.phase ==
                            CameraExperiencePhase.capturing,
                      ),
                    ),
                    if (!isCupStep)
                      SaucerResidueEffect(
                        config: widget.config,
                        analysis: _controller.saucerResidueAnalysis,
                        assessment: assessment,
                        animation: _scanAnimation,
                        animationPeriod: _effectAnimationPeriod,
                        targetGeometry: targetGeometry,
                        normalizedSaucerBounds:
                            _controller.saucerAnalysis.saucer?.normalizedBounds,
                      ),
                  ],
                ),
              ),
            ),
            _topBar(showCameraActions: true),
            _guidanceAndControls(),
          ],
        );
      },
    );
  }

  Widget _cameraPreview(Size viewportSize) {
    final camera = _controller.cameraController;
    if (camera == null || !camera.value.isInitialized) {
      return ColoredBox(
        color: widget.config.theme.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final preview = camera.value.previewSize;
    final previewWidth = preview?.height ?? viewportSize.width;
    final previewHeight = preview?.width ?? viewportSize.height;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final point = Offset(
          (details.localPosition.dx / viewportSize.width).clamp(0.0, 1.0),
          (details.localPosition.dy / viewportSize.height).clamp(0.0, 1.0),
        );
        unawaited(_controller.focusAt(point));
      },
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: CameraPreview(camera),
          ),
        ),
      ),
    );
  }

  Widget _topBar({required bool showCameraActions}) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _cameraIconButton(
                  tooltip: 'Geri',
                  icon: Icons.arrow_back,
                  onPressed: _back,
                ),
                const Spacer(),
                if (showCameraActions) ...[
                  if (kDebugMode && _controller.isCupStep)
                    _cameraIconButton(
                      tooltip: 'Analiz testi',
                      icon: Icons.bug_report_outlined,
                      onPressed: () => showDebugAnalysisPanel(
                        context: context,
                        initialValue: _controller.debugSettings,
                        onChanged: _controller.setDebugSettings,
                      ),
                    ),
                  _cameraIconButton(
                    tooltip: 'Flaş',
                    icon: switch (_controller.flashMode) {
                      FlashMode.auto => Icons.flash_auto,
                      FlashMode.torch => Icons.flash_on,
                      _ => Icons.flash_off,
                    },
                    onPressed: _controller.cycleFlashMode,
                  ),
                  _cameraIconButton(
                    tooltip: 'Kamerayı değiştir',
                    icon: Icons.cameraswitch_outlined,
                    onPressed: _controller.hasMultipleCameras
                        ? _controller.switchCamera
                        : null,
                  ),
                ],
              ],
            ),
            if (_stepLabel case final label?) ...[
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.config.theme.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cameraIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0x66000000),
        foregroundColor: widget.config.theme.foreground,
        fixedSize: const Size.square(44),
      ),
      icon: Icon(icon),
    );
  }

  Widget _guidanceAndControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _controller.guidance,
              key: const Key('coffee-camera-guidance'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.config.theme.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
            const SizedBox(height: 10),
            if (widget.config.showQualityScore)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.signal_cellular_alt,
                    size: 18,
                    color: widget.config.theme.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_controller.displayQualityScore}/100',
                    key: const Key('coffee-camera-quality-score'),
                    style: TextStyle(
                      color: widget.config.theme.mutedForeground,
                    ),
                  ),
                ],
              ),
            if (_controller.autoCaptureVisible) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.config.strings.autoCapture,
                    style: TextStyle(color: widget.config.theme.foreground),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    key: const Key('coffee-camera-auto-switch'),
                    value: _controller.autoCaptureEnabled,
                    onChanged: _controller.setAutoCaptureEnabled,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            IconButton.filled(
              key: const Key('coffee-camera-shutter'),
              tooltip: 'Fotoğraf çek',
              onPressed: _controller.canCapture
                  ? () => _controller.capture(CameraCaptureMode.manual)
                  : null,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(76),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111417),
                disabledBackgroundColor: const Color(0x88FFFFFF),
              ),
              iconSize: 34,
              icon: const Icon(Icons.camera_alt),
            ),
          ],
        ),
      ),
    );
  }
}
