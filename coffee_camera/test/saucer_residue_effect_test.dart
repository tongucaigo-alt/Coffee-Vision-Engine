import 'dart:typed_data';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/quality_assessment.dart';
import 'package:coffee_camera/src/models/residue_analysis_result.dart';
import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/saucer_residue_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the basic effect without drawing mask points', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 5400),
    )..repeat();

    await _pumpEffect(
      tester,
      animation: animation,
      analysis: const ResidueAnalysisResult.empty(),
    );

    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-basic-effect')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-points')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    animation.dispose();
  });

  testWidgets('shows candidate points and locks only on stable edges', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 5400),
    )..repeat();
    final mask = _mask();
    final candidate = _result(mask: mask, stabilized: false);
    final stable = _result(mask: mask, stabilized: true);

    await _pumpEffect(tester, animation: animation, analysis: candidate);
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-points')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-lock-effect')),
      findsNothing,
    );

    await _pumpEffect(tester, animation: animation, analysis: stable);
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-points')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-lock-effect')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 440));
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-lock-effect')),
      findsNothing,
    );
    await _pumpEffect(tester, animation: animation, analysis: stable);
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-lock-effect')),
      findsNothing,
    );
    await _pumpEffect(
      tester,
      animation: animation,
      analysis: ResidueAnalysisResult(
        mask: mask,
        score: 0,
        confidence: 0,
        residueDetected: true,
        residueBounds: mask.residueBounds,
        boundaryUsed: true,
        analysisPerformed: true,
      ),
    );
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-points')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-lock-effect')),
      findsNothing,
    );

    await _pumpEffect(
      tester,
      animation: animation,
      analysis: const ResidueAnalysisResult.empty(analysisPerformed: true),
    );
    await _pumpEffect(tester, animation: animation, analysis: stable);
    expect(
      find.byKey(const Key('coffee-camera-saucer-residue-lock-effect')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    animation.dispose();
  });

  test('confidence continuously controls the visual opacity', () {
    const style = SaucerResidueEffectStyle();
    final floor = saucerResidueConfidenceOpacity(
      style.minimumVisibleConfidence,
      style,
    );
    final low = saucerResidueConfidenceOpacity(0.40, style);
    final high = saucerResidueConfidenceOpacity(0.90, style);

    expect(floor, style.minimumConfidenceOpacity);
    expect(low, greaterThanOrEqualTo(floor));
    expect(low, lessThan(high));
    expect(high, lessThanOrEqualTo(1));
  });

  test('point center stays mint-white and scan wave raises brightness', () {
    const style = SaucerResidueEffectStyle();
    const green = Color(0xFF36D978);
    final body = saucerResiduePointBodyColor(green, 0, style);
    final center = saucerResiduePointCenterColor(green, 0, style);
    final scannedCenter = saucerResiduePointCenterColor(green, 1, style);
    final farStrength = saucerResiduePointVisualStrength(
      intensity: 0.4,
      twinkle: 0,
      scanWave: 0,
      style: style,
    );
    final scannedStrength = saucerResiduePointVisualStrength(
      intensity: 0.4,
      twinkle: 0,
      scanWave: 1,
      style: style,
    );

    expect(center.computeLuminance(), greaterThan(body.computeLuminance()));
    expect(
      scannedCenter.computeLuminance(),
      greaterThan(center.computeLuminance()),
    );
    expect(center, isNot(Colors.white));
    expect(scannedCenter, isNot(Colors.white));
    expect(scannedStrength, greaterThan(farStrength));
    expect(scannedStrength, lessThanOrEqualTo(1));
  });

  test('device-calibrated effect profile stays visible but bounded', () {
    const style = SaucerResidueEffectStyle();

    expect(style.minimumVisiblePoints, 20);
    expect(style.maximumVisiblePoints, 64);
    expect(style.pointMinimumOpacity, 0.28);
    expect(style.pointMaximumOpacity, 0.86);
    expect(style.pointGlowOpacity, 0.245);
    expect(style.pointGlowRadiusRatio, 3.3);
    expect(style.pointBodyWhiteMix, 0.44);
    expect(style.pointCenterWhiteMix, 0.78);
    expect(style.searchingTargetOpacity, 0.42);
    expect(style.searchingBandOpacity, 0.09);
    expect(style.candidateBandOpacity, 0.14);
    expect(style.stableBandOpacity, 0.19);
    expect(style.scanBandCenterWhiteMix, 0.22);
    expect(style.scanBandHeightRatio, 0.295);
    expect(style.scanWaveBrightnessBoost, 0.31);
    expect(style.lockDuration, const Duration(milliseconds: 420));
  });
}

Future<void> _pumpEffect(
  WidgetTester tester, {
  required AnimationController animation,
  required ResidueAnalysisResult analysis,
}) async {
  const size = Size(360, 800);
  const config = CoffeeCameraConfig();
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox.fromSize(
        size: size,
        child: SaucerResidueEffect(
          config: config,
          analysis: analysis,
          assessment: _assessment,
          animation: animation,
          animationPeriod: const Duration(milliseconds: 5400),
          targetGeometry: TargetGeometry.forSaucer(size, config.saucerConfig),
          normalizedSaucerBounds: const Rect.fromLTWH(0.08, 0.20, 0.84, 0.42),
        ),
      ),
    ),
  );
}

ResidueRegionMask _mask() {
  final values = Uint8List(32 * 32);
  for (var row = 8; row < 16; row++) {
    values.fillRange(row * 32 + 6, row * 32 + 18, 225);
  }
  return ResidueRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.09, 0.24, 0.82, 0.36),
    width: 32,
    height: 32,
    intensities: values,
    coverage: 0.12,
    residueBounds: const Rect.fromLTWH(0.24, 0.33, 0.31, 0.10),
    componentCount: 1,
  );
}

ResidueAnalysisResult _result({
  required ResidueRegionMask mask,
  required bool stabilized,
}) {
  return ResidueAnalysisResult(
    mask: mask,
    score: 0.68,
    confidence: 0.82,
    residueDetected: stabilized,
    residueBounds: mask.residueBounds,
    boundaryUsed: true,
    analysisPerformed: true,
  );
}

const _assessment = QualityAssessment(
  score: 88,
  level: CaptureQualityLevel.ready,
  cupDetected: true,
  centered: true,
  rightSize: true,
  contained: true,
  notClipped: true,
  lightEnough: true,
  sharpEnough: true,
  angleOk: true,
  stable: true,
  cupDiameterRatio: 0.9,
  autoCaptureReady: true,
);
