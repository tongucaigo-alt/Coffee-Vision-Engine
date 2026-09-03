import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/coffee_camera_config.dart';
import '../models/quality_assessment.dart';
import '../models/residue_analysis_result.dart';
import '../models/residue_region_mask.dart';
import '../models/target_geometry.dart';
import 'saucer_residue_light_layout.dart';

enum SaucerResidueVisualState { searching, candidate, stable }

double saucerResidueConfidenceOpacity(
  double confidence,
  SaucerResidueEffectStyle style,
) {
  final minimum = style.minimumVisibleConfidence;
  final opacityFloor = style.minimumConfidenceOpacity.clamp(0.0, 1.0);
  if (confidence <= minimum) return opacityFloor;
  final normalized = ((confidence - minimum) / (1 - minimum)).clamp(0.0, 1.0);
  return (opacityFloor + normalized * (1 - opacityFloor)).clamp(0.0, 1.0);
}

double saucerResiduePointVisualStrength({
  required double intensity,
  required double twinkle,
  required double scanWave,
  required SaucerResidueEffectStyle style,
}) {
  return (0.30 +
          intensity.clamp(0.0, 1.0) * 0.34 +
          twinkle.clamp(0.0, 1.0) * 0.14 +
          scanWave.clamp(0.0, 1.0) * style.scanWaveBrightnessBoost)
      .clamp(0.0, 1.0);
}

Color saucerResiduePointBodyColor(
  Color color,
  double scanWave,
  SaucerResidueEffectStyle style,
) {
  final whiteMix =
      (style.pointBodyWhiteMix +
              scanWave.clamp(0.0, 1.0) * style.pointBodyScanWhiteMix)
          .clamp(0.0, 1.0);
  return Color.lerp(color, Colors.white, whiteMix)!;
}

Color saucerResiduePointCenterColor(
  Color color,
  double scanWave,
  SaucerResidueEffectStyle style,
) {
  final whiteMix =
      (style.pointCenterWhiteMix +
              scanWave.clamp(0.0, 1.0) * style.pointCenterScanWhiteMix)
          .clamp(0.0, 1.0);
  return Color.lerp(color, Colors.white, whiteMix)!;
}

class SaucerResidueEffect extends StatefulWidget {
  const SaucerResidueEffect({
    super.key,
    required this.config,
    required this.analysis,
    required this.assessment,
    required this.animation,
    required this.animationPeriod,
    required this.targetGeometry,
    this.normalizedSaucerBounds,
  });

  final CoffeeCameraConfig config;
  final ResidueAnalysisResult analysis;
  final QualityAssessment assessment;
  final Animation<double> animation;
  final Duration animationPeriod;
  final TargetGeometry targetGeometry;
  final Rect? normalizedSaucerBounds;

  @override
  State<SaucerResidueEffect> createState() => _SaucerResidueEffectState();
}

class _SaucerResidueEffectState extends State<SaucerResidueEffect> {
  ResidueRegionMask? _mask;
  List<SaucerResidueLight> _previousLights = const [];
  List<SaucerResidueLight> _currentLights = const [];
  var _previousLightsVisible = false;
  var _currentLightsVisible = false;
  var _previousConfidence = 0.0;
  var _currentConfidence = 0.0;
  var _transitionStart = 0.0;
  var _transitionActive = false;
  var _lockStart = 0.0;
  var _lockActive = false;
  late Color _colorFrom;
  late Color _colorTo;
  var _colorStart = 0.0;
  var _colorTransitionActive = false;

  SaucerResidueEffectStyle get _style =>
      widget.config.saucerConfig.residueEffectStyle;

  @override
  void initState() {
    super.initState();
    _mask = widget.analysis.mask;
    _currentLights = _buildLights(_mask);
    _currentLightsVisible = _isReliableVisual(widget.analysis, _currentLights);
    _currentConfidence = widget.analysis.confidence;
    _colorFrom = _colorFor(_visualState(widget.analysis));
    _colorTo = _colorFrom;
    widget.animation.addListener(_handleAnimationTick);
  }

  @override
  void didUpdateWidget(SaucerResidueEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_handleAnimationTick);
      widget.animation.addListener(_handleAnimationTick);
    }

    final maskChanged = !identical(widget.analysis.mask, _mask);
    final nextLights = maskChanged
        ? _buildLights(widget.analysis.mask)
        : _currentLights;
    var nextVisible = _isReliableVisual(widget.analysis, nextLights);
    var nextConfidence = widget.analysis.confidence;
    final visuallyHoldingLastValidMask =
        !maskChanged &&
        _currentLightsVisible &&
        oldWidget.analysis.residueDetected &&
        widget.analysis.residueDetected;
    if (visuallyHoldingLastValidMask) {
      nextVisible = true;
      nextConfidence = _currentConfidence;
    }
    if (maskChanged || nextVisible != _currentLightsVisible) {
      _previousLights = _currentLights;
      _previousLightsVisible = _currentLightsVisible;
      _previousConfidence = _currentConfidence;
      _currentLights = nextLights;
      _currentLightsVisible = nextVisible;
      _currentConfidence = nextConfidence;
      _mask = widget.analysis.mask;
      _transitionStart = widget.animation.value;
      _transitionActive = _previousLightsVisible || _currentLightsVisible;
    } else if (nextVisible) {
      _currentConfidence = nextConfidence;
    }

    final nextColor = _colorFor(_visualState(widget.analysis));
    if (nextColor != _colorTo) {
      _colorFrom = _displayColor;
      _colorTo = nextColor;
      _colorStart = widget.animation.value;
      _colorTransitionActive = true;
    }
    if (!oldWidget.analysis.residueDetected &&
        widget.analysis.residueDetected) {
      _lockStart = widget.animation.value;
      _lockActive = true;
    }
  }

  List<SaucerResidueLight> _buildLights(ResidueRegionMask? mask) {
    return buildSaucerResidueLights(
      mask,
      minimumCount: _style.minimumVisiblePoints,
      maximumCount: _style.maximumVisiblePoints,
      maximumSparkles: _style.maximumSparkles,
      sparkleIntensityThreshold: _style.sparkleIntensityThreshold,
    );
  }

  bool _isReliableVisual(
    ResidueAnalysisResult analysis,
    List<SaucerResidueLight> lights,
  ) {
    final profile = widget.config.saucerConfig.residueProfile;
    return analysis.mask != null &&
        analysis.coverage >= profile.minimumCoverage &&
        analysis.coverage <= profile.maximumCoverage &&
        analysis.activeCellCount >= profile.minimumActiveCells &&
        analysis.score >= profile.minimumScore &&
        analysis.confidence >= _style.minimumVisibleConfidence &&
        lights.length >= _style.minimumVisiblePoints;
  }

  SaucerResidueVisualState _visualState(ResidueAnalysisResult result) {
    if (result.residueDetected) return SaucerResidueVisualState.stable;
    final profile = widget.config.saucerConfig.residueProfile;
    final candidate =
        result.mask != null &&
        result.coverage >= profile.minimumCoverage &&
        result.coverage <= profile.maximumCoverage &&
        result.activeCellCount >= profile.minimumActiveCells &&
        result.score >= profile.minimumScore;
    return candidate
        ? SaucerResidueVisualState.candidate
        : SaucerResidueVisualState.searching;
  }

  Color _colorFor(SaucerResidueVisualState state) {
    final theme = widget.config.theme;
    return switch (state) {
      SaucerResidueVisualState.searching => theme.warningRing,
      SaucerResidueVisualState.candidate => Color.lerp(
        theme.warningRing,
        theme.readyRing,
        0.48,
      )!,
      SaucerResidueVisualState.stable => theme.readyRing,
    };
  }

  double _progress(double start, Duration duration) {
    if (duration <= Duration.zero) return 1;
    var phaseDelta = widget.animation.value - start;
    if (phaseDelta < 0) phaseDelta += 1;
    final elapsedMicroseconds =
        phaseDelta * widget.animationPeriod.inMicroseconds;
    return (elapsedMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }

  double get _transitionProgress => _transitionActive
      ? _progress(_transitionStart, _style.maskTransitionDuration)
      : 1;

  double get _lockProgress =>
      _lockActive ? _progress(_lockStart, _style.lockDuration) : 1;

  double get _colorProgress => _colorTransitionActive
      ? Curves.easeOutCubic.transform(
          _progress(_colorStart, _style.maskTransitionDuration),
        )
      : 1;

  Color get _displayColor => Color.lerp(_colorFrom, _colorTo, _colorProgress)!;

  void _handleAnimationTick() {
    var needsBuild = false;
    if (_transitionActive && _transitionProgress >= 1) {
      _transitionActive = false;
      _previousLights = const [];
      _previousLightsVisible = false;
      needsBuild = true;
    }
    if (_colorTransitionActive && _colorProgress >= 1) {
      _colorTransitionActive = false;
      _colorFrom = _colorTo;
    }
    if (_lockActive && _lockProgress >= 1) {
      _lockActive = false;
      needsBuild = true;
    }
    if (needsBuild && mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimationTick);
    _previousLights = const [];
    _currentLights = const [];
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointsVisible =
        _currentLightsVisible ||
        (_previousLightsVisible && _transitionProgress < 1);
    return CustomPaint(
      key: const Key('coffee-camera-saucer-residue-basic-effect'),
      painter: SaucerResiduePainter(
        repaint: widget.animation,
        config: widget.config,
        analysis: widget.analysis,
        assessment: widget.assessment,
        animation: widget.animation,
        animationPeriod: widget.animationPeriod,
        targetGeometry: widget.targetGeometry,
        normalizedSaucerBounds: widget.normalizedSaucerBounds,
        previousLights: _previousLights,
        currentLights: _currentLights,
        previousLightsVisible: _previousLightsVisible,
        currentLightsVisible: _currentLightsVisible,
        previousConfidence: _previousConfidence,
        currentConfidence: _currentConfidence,
        transitionStart: _transitionStart,
        transitionActive: _transitionActive,
        colorFrom: _colorFrom,
        colorTo: _colorTo,
        colorStart: _colorStart,
        colorTransitionActive: _colorTransitionActive,
        lockStart: _lockStart,
        lockActive: _lockActive,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (pointsVisible)
            const SizedBox.expand(
              key: Key('coffee-camera-saucer-residue-points'),
            ),
          if (_lockActive)
            const SizedBox.expand(
              key: Key('coffee-camera-saucer-residue-lock-effect'),
            ),
        ],
      ),
    );
  }
}

class SaucerResiduePainter extends CustomPainter {
  SaucerResiduePainter({
    required Listenable repaint,
    required this.config,
    required this.analysis,
    required this.assessment,
    required this.animation,
    required this.animationPeriod,
    required this.targetGeometry,
    required this.normalizedSaucerBounds,
    required this.previousLights,
    required this.currentLights,
    required this.previousLightsVisible,
    required this.currentLightsVisible,
    required this.previousConfidence,
    required this.currentConfidence,
    required this.transitionStart,
    required this.transitionActive,
    required this.colorFrom,
    required this.colorTo,
    required this.colorStart,
    required this.colorTransitionActive,
    required this.lockStart,
    required this.lockActive,
  }) : super(repaint: repaint);

  final CoffeeCameraConfig config;
  final ResidueAnalysisResult analysis;
  final QualityAssessment assessment;
  final Animation<double> animation;
  final Duration animationPeriod;
  final TargetGeometry targetGeometry;
  final Rect? normalizedSaucerBounds;
  final List<SaucerResidueLight> previousLights;
  final List<SaucerResidueLight> currentLights;
  final bool previousLightsVisible;
  final bool currentLightsVisible;
  final double previousConfidence;
  final double currentConfidence;
  final double transitionStart;
  final bool transitionActive;
  final Color colorFrom;
  final Color colorTo;
  final double colorStart;
  final bool colorTransitionActive;
  final double lockStart;
  final bool lockActive;

  static const _bandStops = <double>[0, 0.28, 0.5, 0.72, 1];
  final List<Color> _bandColors = List<Color>.filled(5, Colors.transparent);
  final Paint _bandPaint = Paint();
  final Paint _pointGlowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _pointBodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _pointCenterPaint = Paint()..style = PaintingStyle.fill;
  final Paint _sparklePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.75
    ..strokeCap = StrokeCap.round;

  SaucerResidueEffectStyle get style => config.saucerConfig.residueEffectStyle;

  double _progress(double start, Duration duration) {
    if (duration <= Duration.zero) return 1;
    var phaseDelta = animation.value - start;
    if (phaseDelta < 0) phaseDelta += 1;
    final elapsedMicroseconds = phaseDelta * animationPeriod.inMicroseconds;
    return (elapsedMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }

  double get scanProgress {
    final scanDuration = style.scanDuration.inMicroseconds;
    if (scanDuration <= 0) return 0;
    final cycles = animationPeriod.inMicroseconds / scanDuration;
    final value = (animation.value * cycles) % 1;
    return value == 0 ? 0.0001 : value;
  }

  double get transitionProgress => transitionActive
      ? Curves.easeOutCubic.transform(
          _progress(transitionStart, style.maskTransitionDuration),
        )
      : 1;

  double get lockProgress =>
      lockActive ? _progress(lockStart, style.lockDuration) : 1;

  double get lockEmphasis =>
      lockActive ? math.sin(math.pi * lockProgress).clamp(0.0, 1.0) : 0;

  Color get displayColor => Color.lerp(
    colorFrom,
    colorTo,
    colorTransitionActive
        ? Curves.easeOutCubic.transform(
            _progress(colorStart, style.maskTransitionDuration),
          )
        : 1,
  )!;

  double confidenceOpacity(double confidence) {
    return saucerResidueConfidenceOpacity(confidence, style);
  }

  bool get hasCandidate {
    final profile = config.saucerConfig.residueProfile;
    return analysis.mask != null &&
        analysis.coverage >= profile.minimumCoverage &&
        analysis.coverage <= profile.maximumCoverage &&
        analysis.activeCellCount >= profile.minimumActiveCells &&
        analysis.score >= profile.minimumScore;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final flexibleBounds = _flexibleBounds(size);
    if (flexibleBounds.isEmpty) return;
    final cornerRadius =
        math.min(flexibleBounds.width, flexibleBounds.height) * 0.14;
    final flexibleTarget = RRect.fromRectAndRadius(
      flexibleBounds,
      Radius.circular(cornerRadius),
    );
    final color = displayColor;
    final breath = (math.sin(scanProgress * math.pi * 2) + 1) * 0.5;
    final scale = 1 + (style.targetBreathingScale - 1) * breath;
    final breathingTarget = _scaleRRect(flexibleTarget, scale);
    final frameOpacity = analysis.residueDetected
        ? style.stableTargetOpacity
        : hasCandidate
        ? style.candidateTargetOpacity
        : assessment.cupDetected
        ? style.searchingTargetOpacity
        : style.searchingTargetOpacity * 0.72;
    canvas.drawRRect(
      breathingTarget,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.targetStrokeWidth + lockEmphasis * 0.35
        ..color = Color.lerp(
          color,
          Colors.white,
          lockEmphasis * 0.30,
        )!.withValues(alpha: frameOpacity + lockEmphasis * 0.28),
    );

    canvas.save();
    canvas.clipRRect(flexibleTarget);
    final safeSaucer = _safeSaucerBounds(size);
    if (safeSaucer != null && !safeSaucer.isEmpty) {
      canvas.clipPath(Path()..addOval(safeSaucer));
    }
    if (analysis.residueDetected) {
      canvas.drawRRect(
        flexibleTarget,
        Paint()
          ..color = config.theme.readyRing.withValues(
            alpha: style.stableInnerGlowOpacity * (0.82 + breath * 0.18),
          ),
      );
    }
    _drawAnalysisBand(canvas, flexibleBounds, color);
    if (previousLightsVisible && previousLights.isNotEmpty) {
      _drawLights(
        canvas,
        size,
        flexibleBounds,
        previousLights,
        confidence: previousConfidence,
        listOpacity: 1 - transitionProgress,
      );
    }
    if (currentLightsVisible && currentLights.isNotEmpty) {
      _drawLights(
        canvas,
        size,
        flexibleBounds,
        currentLights,
        confidence: currentConfidence,
        listOpacity: transitionProgress,
      );
    }
    canvas.restore();

    if (lockActive && lockEmphasis > 0) {
      final expansion =
          style.lockExpansion * Curves.easeOutCubic.transform(lockProgress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          flexibleBounds.inflate(expansion),
          Radius.circular(cornerRadius + expansion),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.targetStrokeWidth * 0.75
          ..color = config.theme.readyRing.withValues(
            alpha: (1 - lockProgress) * style.lockStrokeOpacity,
          ),
      );
    }
  }

  Rect _flexibleBounds(Size size) {
    final normalized =
        config.saucerConfig.residueProfile.normalizedAnalysisBounds;
    final analysisBounds = Rect.fromLTRB(
      normalized.left * size.width,
      normalized.top * size.height,
      normalized.right * size.width,
      normalized.bottom * size.height,
    );
    return analysisBounds.intersect(targetGeometry.bounds);
  }

  Rect? _safeSaucerBounds(Size size) {
    final normalized = normalizedSaucerBounds;
    if (normalized == null) return null;
    final bounds = Rect.fromLTRB(
      normalized.left * size.width,
      normalized.top * size.height,
      normalized.right * size.width,
      normalized.bottom * size.height,
    );
    final ratio = config.saucerConfig.residueProfile.boundaryInnerRatio;
    return Rect.fromCenter(
      center: bounds.center,
      width: bounds.width * ratio,
      height: bounds.height * ratio,
    );
  }

  RRect _scaleRRect(RRect source, double scale) {
    final rect = Rect.fromCenter(
      center: source.center,
      width: source.width * scale,
      height: source.height * scale,
    );
    return RRect.fromRectAndRadius(rect, source.tlRadius * scale);
  }

  void _drawAnalysisBand(Canvas canvas, Rect bounds, Color color) {
    final stateOpacity = analysis.residueDetected
        ? style.stableBandOpacity
        : hasCandidate
        ? style.candidateBandOpacity
        : style.searchingBandOpacity;
    final edgeFade = math
        .pow(math.sin(scanProgress * math.pi), 0.65)
        .toDouble();
    final height = bounds.height * style.scanBandHeightRatio;
    final centerY = bounds.top + bounds.height * scanProgress;
    final bandBounds = Rect.fromLTWH(
      bounds.left - bounds.width * 0.08,
      centerY - height / 2,
      bounds.width * 1.16,
      height,
    );
    final opacity =
        (stateOpacity *
                edgeFade *
                (analysis.analysisPerformed ? 1 : 0.62) *
                (1 + lockEmphasis * 0.45))
            .clamp(0.0, 1.0);
    final centerColor = Color.lerp(
      color,
      Colors.white,
      style.scanBandCenterWhiteMix.clamp(0.0, 1.0),
    )!;
    _bandColors[0] = color.withValues(alpha: 0);
    _bandColors[1] = color.withValues(alpha: (opacity * 0.42).clamp(0.0, 1.0));
    _bandColors[2] = centerColor.withValues(alpha: opacity);
    _bandColors[3] = _bandColors[1];
    _bandColors[4] = _bandColors[0];
    _bandPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: _bandColors,
      stops: _bandStops,
    ).createShader(bandBounds);
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.rotate(style.scanBandAngleRadians);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    canvas.drawRect(bandBounds, _bandPaint);
    canvas.restore();
  }

  void _drawLights(
    Canvas canvas,
    Size size,
    Rect bounds,
    List<SaucerResidueLight> lights, {
    required double confidence,
    required double listOpacity,
  }) {
    if (listOpacity <= 0) return;
    final color = displayColor;
    final confidenceFactor = confidenceOpacity(confidence);
    final scanY = bounds.top + bounds.height * scanProgress;
    final slope = math.tan(style.scanBandAngleRadians);
    final waveDistance = math.max(1.0, bounds.height * 0.13);
    for (var index = 0; index < lights.length; index++) {
      final light = lights[index];
      final point = Offset(
        light.normalizedPosition.dx * size.width,
        light.normalizedPosition.dy * size.height,
      );
      final lineY = scanY + (point.dx - bounds.center.dx) * slope;
      final wave = (1 - (point.dy - lineY).abs() / waveDistance).clamp(
        0.0,
        1.0,
      );
      final phase =
          (scanProgress * 1.4 +
              (light.cellIndex % style.phaseCount) / style.phaseCount) *
          math.pi *
          2;
      final twinkle = math.pow(math.max(0.0, math.sin(phase)), 4).toDouble();
      final visualStrength = saucerResiduePointVisualStrength(
        intensity: light.intensity,
        twinkle: twinkle,
        scanWave: wave,
        style: style,
      );
      final lockBoost = 1 + lockEmphasis * style.lockPointBoost;
      final stateStrength = analysis.residueDetected ? 1.0 : 0.72;
      final coreRadius =
          (style.pointCoreBaseRadius +
              style.pointCoreIntensityRadius * light.intensity) *
          (1 + wave * 0.12) *
          lockBoost;
      final opacity =
          ((style.pointMinimumOpacity +
                      (style.pointMaximumOpacity - style.pointMinimumOpacity) *
                          visualStrength) *
                  confidenceFactor *
                  stateStrength *
                  listOpacity)
              .clamp(0.0, 1.0);

      _pointGlowPaint.color = color.withValues(
        alpha:
            (style.pointGlowOpacity *
                    (0.55 + wave * 0.45) *
                    confidenceFactor *
                    stateStrength *
                    listOpacity)
                .clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        point,
        coreRadius * style.pointGlowRadiusRatio,
        _pointGlowPaint,
      );
      _pointBodyPaint.color = saucerResiduePointBodyColor(
        color,
        wave,
        style,
      ).withValues(alpha: opacity);
      canvas.drawCircle(point, coreRadius, _pointBodyPaint);
      _pointCenterPaint.color =
          saucerResiduePointCenterColor(color, wave, style).withValues(
            alpha: (opacity * style.pointCenterOpacityRatio).clamp(0.0, 1.0),
          );
      canvas.drawCircle(
        point,
        coreRadius * style.pointCenterRadiusRatio.clamp(0.0, 1.0),
        _pointCenterPaint,
      );

      if (analysis.residueDetected &&
          light.sparkleEligible &&
          twinkle > 0.88 &&
          wave > 0.18) {
        final ray = coreRadius * (1.55 + wave * 0.30);
        _sparklePaint.color = Color.lerp(
          color,
          Colors.white,
          style.sparkleWhiteMix.clamp(0.0, 1.0),
        )!.withValues(alpha: (opacity * twinkle * 0.72).clamp(0.0, 1.0));
        canvas.drawLine(
          point.translate(-ray, 0),
          point.translate(ray, 0),
          _sparklePaint,
        );
        canvas.drawLine(
          point.translate(0, -ray),
          point.translate(0, ray),
          _sparklePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SaucerResiduePainter oldDelegate) {
    return config != oldDelegate.config ||
        analysis != oldDelegate.analysis ||
        assessment != oldDelegate.assessment ||
        animation != oldDelegate.animation ||
        animationPeriod != oldDelegate.animationPeriod ||
        targetGeometry != oldDelegate.targetGeometry ||
        normalizedSaucerBounds != oldDelegate.normalizedSaucerBounds ||
        previousLights != oldDelegate.previousLights ||
        currentLights != oldDelegate.currentLights ||
        previousLightsVisible != oldDelegate.previousLightsVisible ||
        currentLightsVisible != oldDelegate.currentLightsVisible ||
        previousConfidence != oldDelegate.previousConfidence ||
        currentConfidence != oldDelegate.currentConfidence ||
        transitionStart != oldDelegate.transitionStart ||
        transitionActive != oldDelegate.transitionActive ||
        colorFrom != oldDelegate.colorFrom ||
        colorTo != oldDelegate.colorTo ||
        colorStart != oldDelegate.colorStart ||
        colorTransitionActive != oldDelegate.colorTransitionActive ||
        lockStart != oldDelegate.lockStart ||
        lockActive != oldDelegate.lockActive;
  }
}
