import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/coffee_camera_config.dart';
import '../models/coffee_region_mask.dart';
import '../models/target_geometry.dart';
import 'scan_light_layout.dart';

enum CaptureEffectProfile { cup, saucer }

class CameraTargetOverlay extends StatefulWidget {
  const CameraTargetOverlay({
    super.key,
    required this.config,
    required this.ringColor,
    this.effectProfile = CaptureEffectProfile.cup,
    this.progress = 0,
    this.scanProgress = 0,
    this.saucerSweepProgress = 0,
    this.isReady = false,
    this.subjectDetected = false,
    this.coffeeDetected = false,
    this.coffeeMask,
    this.targetGeometry,
    this.flash = false,
  });

  final CoffeeCameraConfig config;
  final Color ringColor;
  final CaptureEffectProfile effectProfile;
  final double progress;
  final double scanProgress;
  final double saucerSweepProgress;
  final bool isReady;
  final bool subjectDetected;
  final bool coffeeDetected;
  final CoffeeRegionMask? coffeeMask;
  final TargetGeometry? targetGeometry;
  final bool flash;

  @override
  State<CameraTargetOverlay> createState() => _CameraTargetOverlayState();
}

class _CameraTargetOverlayState extends State<CameraTargetOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ringColorController;
  late final AnimationController _ringPulseController;
  late final AnimationController _readyLockController;
  late final Listenable _painterRepaint;
  late Animation<Color?> _ringColorAnimation;
  CoffeeRegionMask? _scanLightsMask;
  List<ScanLight> _scanLights = const [];
  var _scanMaskHasEnoughActiveCells = false;
  var _tickerModeEnabled = false;
  var _appIsActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appIsActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _ringColorController = AnimationController(
      vsync: this,
      duration: widget.config.effectStyle.ringColorTransitionDuration,
    );
    _ringPulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );
    _readyLockController = AnimationController(
      vsync: this,
      duration: widget.config.effectStyle.readyLockDuration,
    );
    _painterRepaint = Listenable.merge([
      _ringColorController,
      _ringPulseController,
      _readyLockController,
    ]);
    _ringColorAnimation = AlwaysStoppedAnimation<Color?>(widget.ringColor);
    _updateScanLights(
      widget.effectProfile == CaptureEffectProfile.cup
          ? widget.coffeeMask
          : null,
    );
  }

  Duration get _pulseDuration => widget.isReady
      ? widget.config.effectStyle.readyRingPulseDuration
      : widget.config.effectStyle.ringPulseDuration;

  bool get _canAnimate => _appIsActive && _tickerModeEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerModeEnabled == tickerModeEnabled) return;
    _tickerModeEnabled = tickerModeEnabled;
    _syncVisualAnimations();
  }

  @override
  void didUpdateWidget(CameraTargetOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.coffeeMask, oldWidget.coffeeMask) ||
        widget.effectProfile != oldWidget.effectProfile) {
      _updateScanLights(
        widget.effectProfile == CaptureEffectProfile.cup
            ? widget.coffeeMask
            : null,
      );
    }
    _ringColorController.duration =
        widget.config.effectStyle.ringColorTransitionDuration;
    _readyLockController.duration = widget.config.effectStyle.readyLockDuration;
    if (widget.ringColor != oldWidget.ringColor) {
      final currentColor = _ringColorAnimation.value ?? oldWidget.ringColor;
      _ringColorAnimation =
          ColorTween(begin: currentColor, end: widget.ringColor).animate(
            CurvedAnimation(
              parent: _ringColorController,
              curve: Curves.easeOutCubic,
            ),
          );
      if (_canAnimate) {
        _ringColorController.forward(from: 0);
      } else {
        _ringColorController.value = 1;
      }
    }

    final oldPulseDuration = oldWidget.isReady
        ? oldWidget.config.effectStyle.readyRingPulseDuration
        : oldWidget.config.effectStyle.ringPulseDuration;
    if (_pulseDuration != oldPulseDuration) {
      _syncVisualAnimations(restartPulse: true);
    }

    if (!oldWidget.isReady && widget.isReady) {
      _triggerReadyLock();
    } else if (oldWidget.isReady && !widget.isReady) {
      _readyLockController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appIsActive = state == AppLifecycleState.resumed;
    if (_appIsActive == appIsActive) return;
    _appIsActive = appIsActive;
    _syncVisualAnimations();
  }

  void _syncVisualAnimations({bool restartPulse = false}) {
    if (!_canAnimate) {
      _ringColorController.stop(canceled: false);
      _ringPulseController.stop(canceled: false);
      _readyLockController
        ..stop()
        ..value = 0;
      return;
    }

    if (_ringColorController.value < 1 &&
        _ringColorAnimation.value != widget.ringColor) {
      _ringColorController.forward();
    }
    _ringPulseController.duration = _pulseDuration;
    if (restartPulse || !_ringPulseController.isAnimating) {
      _ringPulseController.repeat(reverse: true, period: _pulseDuration);
    }
  }

  void _triggerReadyLock() {
    if (!_canAnimate) {
      _readyLockController.value = 0;
      return;
    }
    _readyLockController.forward(from: 0);
    if (widget.config.enableReadyLockHaptic) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _updateScanLights(CoffeeRegionMask? mask) {
    if (identical(mask, _scanLightsMask)) return;
    _scanLightsMask = mask;
    _scanMaskHasEnoughActiveCells = mask != null && mask.activeCellCount >= 24;
    final lights = buildScanLights(mask);
    _scanLights = lights.isEmpty ? const [] : List.unmodifiable(lights);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readyLockController.dispose();
    _ringPulseController.dispose();
    _ringColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanVisible =
        widget.effectProfile == CaptureEffectProfile.cup &&
        widget.coffeeDetected &&
        widget.coffeeMask != null &&
        _scanMaskHasEnoughActiveCells &&
        widget.scanProgress > 0;
    return CustomPaint(
      key: const Key('coffee-camera-target-overlay'),
      painter: _TargetPainter(
        repaint: _painterRepaint,
        config: widget.config,
        effectProfile: widget.effectProfile,
        ringColorAnimation: _ringColorAnimation,
        ringColorFallback: widget.ringColor,
        ringPulseAnimation: _ringPulseController,
        readyLockAnimation: _readyLockController,
        isReady: widget.isReady,
        progress: widget.progress,
        scanProgress: widget.scanProgress,
        saucerSweepProgress: widget.saucerSweepProgress,
        subjectDetected: widget.subjectDetected,
        coffeeDetected: widget.coffeeDetected,
        coffeeMask: widget.coffeeMask,
        scanLights: _scanLights,
        targetGeometry: widget.targetGeometry,
        flash: widget.flash,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (scanVisible)
            const SizedBox.expand(key: Key('coffee-camera-scan-effect')),
          if (widget.effectProfile == CaptureEffectProfile.saucer &&
              widget.subjectDetected &&
              widget.saucerSweepProgress > 0)
            const SizedBox.expand(
              key: Key('coffee-camera-saucer-sweep-effect'),
            ),
        ],
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  _TargetPainter({
    required Listenable repaint,
    required this.config,
    required this.effectProfile,
    required this.ringColorAnimation,
    required this.ringColorFallback,
    required this.ringPulseAnimation,
    required this.readyLockAnimation,
    required this.isReady,
    required this.progress,
    required this.scanProgress,
    required this.saucerSweepProgress,
    required this.subjectDetected,
    required this.coffeeDetected,
    required this.coffeeMask,
    required this.scanLights,
    required this.targetGeometry,
    required this.flash,
  }) : super(repaint: repaint);

  final CoffeeCameraConfig config;
  final CaptureEffectProfile effectProfile;
  final Animation<Color?> ringColorAnimation;
  final Color ringColorFallback;
  final Animation<double> ringPulseAnimation;
  final Animation<double> readyLockAnimation;
  final bool isReady;
  final double progress;
  final double scanProgress;
  final double saucerSweepProgress;
  final bool subjectDetected;
  final bool coffeeDetected;
  final CoffeeRegionMask? coffeeMask;
  final List<ScanLight> scanLights;
  final TargetGeometry? targetGeometry;
  final bool flash;

  Color get ringColor => ringColorAnimation.value ?? ringColorFallback;
  bool get isSaucer => effectProfile == CaptureEffectProfile.saucer;

  double get readyLockEmphasis {
    final pulse = math.sin(math.pi * readyLockAnimation.value);
    return pulse.clamp(0.0, 1.0);
  }

  Color get ringVisualColor => Color.lerp(
    ringColor,
    Colors.white,
    readyLockEmphasis * config.effectStyle.readyLockWhiteMix,
  )!;

  double get ringPulseProgress =>
      Curves.easeInOutSine.transform(ringPulseAnimation.value);

  double get ringVisualScale {
    final maxScale = isReady
        ? isSaucer
              ? config.effectStyle.saucerReadyRingPulseMaxScale
              : config.effectStyle.readyRingPulseMaxScale
        : isSaucer
        ? config.effectStyle.saucerRingPulseMaxScale
        : config.effectStyle.ringPulseMaxScale;
    final breathingScale = 1 + (maxScale - 1) * ringPulseProgress;
    final lockScale =
        1 + (config.effectStyle.readyLockMaxScale - 1) * readyLockEmphasis;
    return math.max(breathingScale, lockScale);
  }

  double get ringVisualStrokeWidth {
    final delta = isReady
        ? isSaucer
              ? config.effectStyle.saucerReadyRingPulseStrokeWidthDelta
              : config.effectStyle.readyRingPulseStrokeWidthDelta
        : isSaucer
        ? config.effectStyle.saucerRingPulseStrokeWidthDelta
        : config.effectStyle.ringPulseStrokeWidthDelta;
    final base = isSaucer
        ? config.effectStyle.saucerRingStrokeWidth
        : config.effectStyle.targetRingStrokeWidth;
    return base + delta * ringPulseProgress;
  }

  double get ringVisualOpacity {
    final minimum = isReady
        ? isSaucer
              ? config.effectStyle.saucerReadyRingPulseMinOpacity
              : config.effectStyle.readyRingPulseMinOpacity
        : isSaucer
        ? config.effectStyle.saucerRingPulseMinOpacity
        : config.effectStyle.ringPulseMinOpacity;
    final breathingOpacity = minimum + (1 - minimum) * ringPulseProgress;
    return breathingOpacity + (1 - breathingOpacity) * readyLockEmphasis;
  }

  double scanLightCoreRadius(double intensity) =>
      config.effectStyle.scanLightCoreBaseRadius +
      config.effectStyle.scanLightCoreIntensityRadius * intensity;

  double scanLightGlowRadius(double intensity) =>
      config.effectStyle.scanLightGlowBaseRadius +
      config.effectStyle.scanLightGlowIntensityRadius * intensity;

  double scanLightStarRayLength(double coreRadius) =>
      coreRadius * config.effectStyle.scanLightStarRayCoreRatio;

  double scanLightStarCenterRadius(double coreRadius) =>
      coreRadius * config.effectStyle.scanLightStarCenterCoreRatio;

  double scanLightCoreOpacity(double intensity) {
    final visualLevel = _scanLightVisualLevel(intensity);
    final curvedLevel = visualLevel * visualLevel;
    final minimum = config.effectStyle.scanLightCoreMinimumOpacity;
    return minimum + (1 - minimum) * curvedLevel;
  }

  double scanLightGlowOpacity(double intensity) {
    final visualLevel = _scanLightVisualLevel(intensity);
    final curvedLevel = visualLevel * visualLevel;
    final minimum = config.effectStyle.scanLightGlowMinimumOpacity;
    final maximum = config.effectStyle.scanLightGlowMaximumOpacity;
    return minimum + (maximum - minimum) * curvedLevel;
  }

  double scanLightStarOpacity(double intensity) {
    final starProgress = ((intensity - 0.72) / 0.28).clamp(0.0, 1.0);
    final inverseProgress = 1 - starProgress;
    final easedProgress =
        1 - inverseProgress * inverseProgress * inverseProgress;
    return config.effectStyle.scanLightStarMaximumOpacity * easedProgress;
  }

  double _scanLightVisualLevel(double intensity) =>
      ((intensity - 0.42) / 0.58).clamp(0.0, 1.0);

  double scanLineEdgeOpacity(double progress) {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final fadeFraction = config.effectStyle.scanLineEdgeFadeFraction;
    if (fadeFraction <= 0) return 1;
    final fadeIn = normalizedProgress / fadeFraction;
    final fadeOut = (1 - normalizedProgress) / fadeFraction;
    return math.min(1.0, math.min(fadeIn, fadeOut)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final target = targetGeometry ?? TargetGeometry.fromViewport(size, config);
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(target.bounds);
    canvas.drawPath(shade, Paint()..color = config.theme.overlay);

    if (isSaucer && subjectDetected && !flash) {
      final innerOpacity = isReady
          ? config.effectStyle.saucerInnerGlowReadyOpacity
          : config.effectStyle.saucerInnerGlowWarningOpacity;
      canvas.drawCircle(
        target.center,
        target.radius,
        Paint()..color = ringVisualColor.withValues(alpha: innerOpacity),
      );
    }

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = flash ? 7 : ringVisualStrokeWidth
      ..color = flash
          ? Colors.white
          : ringVisualColor.withValues(
              alpha: ringVisualColor.a * ringVisualOpacity,
            );
    canvas.drawCircle(
      target.center,
      target.radius * (flash ? 1 : ringVisualScale),
      basePaint,
    );

    if (isSaucer && subjectDetected && !flash) {
      _drawSaucerEffect(canvas, target);
    }

    if (!isSaucer && scanProgress > 0 && coffeeDetected && coffeeMask != null) {
      _drawScanner(canvas, size, coffeeMask!);
    }

    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = config.theme.readyRing;
      canvas.drawArc(
        target.bounds,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  void _drawSaucerEffect(Canvas canvas, TargetGeometry target) {
    final animatedBounds = Rect.fromCircle(
      center: target.center,
      radius: target.radius * ringVisualScale,
    );
    if (saucerSweepProgress > 0) {
      final sweep = isReady
          ? config.effectStyle.saucerSweepReadyLength
          : config.effectStyle.saucerSweepWarningLength;
      final opacity = isReady
          ? config.effectStyle.saucerSweepReadyOpacity
          : config.effectStyle.saucerSweepWarningOpacity;
      final startAngle =
          -math.pi / 2 + math.pi * 2 * saucerSweepProgress.clamp(0.0, 1.0);
      final sweepPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.effectStyle.saucerSweepStrokeWidth
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          ringVisualColor,
          Colors.white,
          isReady ? 0.48 : 0.22,
        )!.withValues(alpha: opacity);
      canvas.drawArc(animatedBounds, startAngle, sweep, false, sweepPaint);
    }

    if (isReady && readyLockAnimation.value > 0) {
      final expansion =
          config.effectStyle.saucerReadyExpansion * readyLockAnimation.value;
      final opacity =
          config.effectStyle.saucerReadyExpansionOpacity *
          readyLockEmphasis *
          (1 - readyLockAnimation.value);
      final lockPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.effectStyle.saucerRingStrokeWidth * 0.72
        ..color = config.theme.readyRing.withValues(alpha: opacity);
      canvas.drawCircle(
        target.center,
        target.radius * (1 + expansion),
        lockPaint,
      );
    }
  }

  void _drawScanner(Canvas canvas, Size size, CoffeeRegionMask mask) {
    if (scanLights.length < 24) return;
    final bounds = Rect.fromLTRB(
      mask.normalizedBounds.left * size.width,
      mask.normalizedBounds.top * size.height,
      mask.normalizedBounds.right * size.width,
      mask.normalizedBounds.bottom * size.height,
    );
    final clipped = Path()..addOval(bounds);
    canvas.save();
    canvas.clipPath(clipped);

    final activeColor = config.theme.readyRing;
    final scanY = bounds.top + bounds.height * scanProgress.clamp(0.0, 1.0);
    final edgeOpacity = scanLineEdgeOpacity(scanProgress);
    final glowHeight = config.effectStyle.scanLineGlowHeight;
    final glowBounds = Rect.fromLTWH(
      bounds.left,
      scanY - glowHeight / 2,
      bounds.width,
      glowHeight,
    );
    final lineGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          activeColor.withValues(alpha: 0),
          activeColor.withValues(
            alpha: config.effectStyle.scanLineGlowCenterOpacity * edgeOpacity,
          ),
          activeColor.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(glowBounds);
    canvas.drawRect(glowBounds, lineGlowPaint);

    final lineBandPaint = Paint()
      ..strokeWidth = config.effectStyle.scanLineBandStrokeWidth
      ..strokeCap = StrokeCap.round
      ..color = activeColor.withValues(
        alpha: config.effectStyle.scanLineBandOpacity * edgeOpacity,
      );
    canvas.drawLine(
      Offset(bounds.left, scanY),
      Offset(bounds.right, scanY),
      lineBandPaint,
    );

    final linePaint = Paint()
      ..strokeWidth = config.effectStyle.scanLineWhiteStrokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(
        alpha: config.effectStyle.scanLineWhiteOpacity * edgeOpacity,
      );
    canvas.drawLine(
      Offset(bounds.left, scanY),
      Offset(bounds.right, scanY),
      linePaint,
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        config.effectStyle.scanLightGlowBlurSigma,
      );
    final corePaint = Paint()..style = PaintingStyle.fill;
    final sparklePaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final starCenterPaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < scanLights.length; index++) {
      final light = scanLights[index];
      final point = Offset(
        light.normalizedPosition.dx * size.width,
        light.normalizedPosition.dy * size.height,
      );
      final distanceFromLine = (point.dy - scanY).abs();
      final wave = (1 - distanceFromLine / (bounds.height * 0.16)).clamp(
        0.0,
        1.0,
      );
      final twinklePhase = (scanProgress * 2 + (index % 17) / 17) * math.pi * 2;
      final twinkle = math
          .pow(math.max(0, math.sin(twinklePhase)), 5)
          .toDouble();
      final intensity = math.max(
        0.42 + light.intensity * 0.22,
        math.max(wave, twinkle * 0.92),
      );

      final glowRadius = scanLightGlowRadius(intensity);
      glowPaint.color = activeColor.withValues(
        alpha: scanLightGlowOpacity(intensity),
      );
      canvas.drawCircle(point, glowRadius, glowPaint);

      final coreRadius = scanLightCoreRadius(intensity);
      corePaint.color = Color.lerp(
        activeColor,
        Colors.white,
        0.28 + intensity * 0.72,
      )!.withValues(alpha: scanLightCoreOpacity(intensity));
      canvas.drawCircle(point, coreRadius, corePaint);

      if (intensity > 0.72) {
        final starOpacity = scanLightStarOpacity(intensity);
        final maximumStarOpacity =
            config.effectStyle.scanLightStarMaximumOpacity;
        final starStrength = maximumStarOpacity == 0
            ? 0.0
            : starOpacity / maximumStarOpacity;
        final starWhiteMix = 0.55 + starStrength * 0.40;
        sparklePaint.color = Color.lerp(
          activeColor,
          Colors.white,
          starWhiteMix,
        )!.withValues(alpha: starOpacity);
        final ray = scanLightStarRayLength(coreRadius);
        canvas.drawLine(
          point.translate(-ray, 0),
          point.translate(ray, 0),
          sparklePaint,
        );
        canvas.drawLine(
          point.translate(0, -ray),
          point.translate(0, ray),
          sparklePaint,
        );
        canvas.drawCircle(
          point,
          scanLightStarCenterRadius(coreRadius),
          starCenterPaint
            ..color = Colors.white.withValues(
              alpha: (starOpacity + 0.10).clamp(0.0, 1.0),
            ),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TargetPainter oldDelegate) {
    return ringColorAnimation != oldDelegate.ringColorAnimation ||
        effectProfile != oldDelegate.effectProfile ||
        ringColorFallback != oldDelegate.ringColorFallback ||
        ringPulseAnimation != oldDelegate.ringPulseAnimation ||
        readyLockAnimation != oldDelegate.readyLockAnimation ||
        isReady != oldDelegate.isReady ||
        progress != oldDelegate.progress ||
        scanProgress != oldDelegate.scanProgress ||
        saucerSweepProgress != oldDelegate.saucerSweepProgress ||
        subjectDetected != oldDelegate.subjectDetected ||
        coffeeDetected != oldDelegate.coffeeDetected ||
        coffeeMask != oldDelegate.coffeeMask ||
        scanLights != oldDelegate.scanLights ||
        targetGeometry != oldDelegate.targetGeometry ||
        flash != oldDelegate.flash ||
        config != oldDelegate.config;
  }
}
