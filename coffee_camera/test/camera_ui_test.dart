import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/coffee_region_mask.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/camera_target_overlay.dart';
import 'package:coffee_camera/src/ui/photo_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target ring width has a configurable density-independent default', () {
    const defaultConfig = CoffeeCameraConfig();
    const customConfig = CoffeeCameraConfig(
      enableReadyLockHaptic: true,
      effectStyle: CoffeeCameraEffectStyle(
        targetRingStrokeWidth: 4.5,
        ringColorTransitionDuration: Duration(milliseconds: 280),
      ),
    );

    expect(defaultConfig.effectStyle.targetRingStrokeWidth, 4.0);
    expect(customConfig.effectStyle.targetRingStrokeWidth, 4.5);
    expect(
      defaultConfig.effectStyle.ringColorTransitionDuration,
      const Duration(milliseconds: 220),
    );
    expect(
      customConfig.effectStyle.ringColorTransitionDuration,
      const Duration(milliseconds: 280),
    );
    expect(defaultConfig.effectStyle.ringPulseMaxScale, 1.010);
    expect(defaultConfig.effectStyle.readyRingPulseMaxScale, 1.006);
    expect(
      defaultConfig.effectStyle.ringPulseDuration,
      const Duration(milliseconds: 1400),
    );
    expect(
      defaultConfig.effectStyle.readyRingPulseDuration,
      const Duration(milliseconds: 2000),
    );
    expect(defaultConfig.effectStyle.scanLightCoreBaseRadius, 0.75);
    expect(defaultConfig.effectStyle.scanLightCoreIntensityRadius, 0.85);
    expect(defaultConfig.effectStyle.scanLightGlowBaseRadius, 2.40);
    expect(defaultConfig.effectStyle.scanLightGlowIntensityRadius, 2.10);
    expect(defaultConfig.effectStyle.scanLightGlowBlurSigma, 3.20);
    expect(defaultConfig.effectStyle.scanLightStarRayCoreRatio, 2.20);
    expect(defaultConfig.effectStyle.scanLightStarCenterCoreRatio, 0.45);
    expect(defaultConfig.effectStyle.scanLightCoreMinimumOpacity, 0.28);
    expect(defaultConfig.effectStyle.scanLightGlowMinimumOpacity, 0.12);
    expect(defaultConfig.effectStyle.scanLightGlowMaximumOpacity, 0.70);
    expect(defaultConfig.effectStyle.scanLightStarMaximumOpacity, 0.82);
    expect(defaultConfig.effectStyle.scanLineWhiteStrokeWidth, 0.90);
    expect(defaultConfig.effectStyle.scanLineBandStrokeWidth, 3.0);
    expect(defaultConfig.effectStyle.scanLineGlowHeight, 20.0);
    expect(defaultConfig.effectStyle.scanLineGlowCenterOpacity, 0.44);
    expect(defaultConfig.effectStyle.scanLineBandOpacity, 0.56);
    expect(defaultConfig.effectStyle.scanLineWhiteOpacity, 0.94);
    expect(defaultConfig.effectStyle.scanLineEdgeFadeFraction, 0.06);
    expect(
      defaultConfig.effectStyle.readyLockDuration,
      const Duration(milliseconds: 240),
    );
    expect(defaultConfig.effectStyle.readyLockMaxScale, 1.012);
    expect(defaultConfig.effectStyle.readyLockWhiteMix, 0.28);
    expect(defaultConfig.enableReadyLockHaptic, isFalse);
    expect(defaultConfig.requireSaucerCapture, isFalse);
    expect(customConfig.enableReadyLockHaptic, isTrue);
  });

  testWidgets('scan light visual sizes stay within the reduced ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraTargetOverlay(
          config: CoffeeCameraConfig(),
          ringColor: Colors.green,
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.byKey(const Key('coffee-camera-target-overlay')),
    );
    final dynamic painter = paint.painter;
    final normalCore = painter.scanLightCoreRadius(0.46) as double;
    final activeCore = painter.scanLightCoreRadius(1.0) as double;
    final normalGlow = painter.scanLightGlowRadius(0.46) as double;
    final activeGlow = painter.scanLightGlowRadius(1.0) as double;
    final activeRay = painter.scanLightStarRayLength(activeCore) as double;
    final whiteCenter = painter.scanLightStarCenterRadius(activeCore) as double;
    final lowCoreOpacity = painter.scanLightCoreOpacity(0.46) as double;
    final normalCoreOpacity = painter.scanLightCoreOpacity(0.64) as double;
    final approachingCoreOpacity = painter.scanLightCoreOpacity(0.80) as double;
    final peakCoreOpacity = painter.scanLightCoreOpacity(1.0) as double;
    final lowGlowOpacity = painter.scanLightGlowOpacity(0.46) as double;
    final normalGlowOpacity = painter.scanLightGlowOpacity(0.64) as double;
    final approachingGlowOpacity = painter.scanLightGlowOpacity(0.80) as double;
    final peakGlowOpacity = painter.scanLightGlowOpacity(1.0) as double;
    final thresholdStarOpacity = painter.scanLightStarOpacity(0.72) as double;
    final strongStarOpacity = painter.scanLightStarOpacity(0.90) as double;
    final peakStarOpacity = painter.scanLightStarOpacity(1.0) as double;
    final scanStartOpacity = painter.scanLineEdgeOpacity(0.0) as double;
    final scanFadeInOpacity = painter.scanLineEdgeOpacity(0.03) as double;
    final scanCenterOpacity = painter.scanLineEdgeOpacity(0.5) as double;
    final scanFadeOutOpacity = painter.scanLineEdgeOpacity(0.97) as double;
    final scanEndOpacity = painter.scanLineEdgeOpacity(1.0) as double;

    expect(normalCore, inInclusiveRange(0.9, 1.3));
    expect(activeCore, inInclusiveRange(1.4, 1.9));
    expect(normalGlow / normalCore, inInclusiveRange(2.5, 3.0));
    expect(activeGlow / activeCore, inInclusiveRange(2.5, 3.0));
    expect(activeRay / activeCore, inInclusiveRange(2.0, 2.5));
    expect(whiteCenter, lessThan(normalCore));
    expect(lowCoreOpacity, inInclusiveRange(0.28, 0.40));
    expect(normalCoreOpacity, inInclusiveRange(0.28, 0.40));
    expect(approachingCoreOpacity, inInclusiveRange(0.55, 0.75));
    expect(peakCoreOpacity, inInclusiveRange(0.90, 1.0));
    expect(lowGlowOpacity, inInclusiveRange(0.12, 0.25));
    expect(normalGlowOpacity, inInclusiveRange(0.12, 0.25));
    expect(approachingGlowOpacity, inInclusiveRange(0.35, 0.55));
    expect(peakGlowOpacity, inInclusiveRange(0.55, 0.75));
    expect(thresholdStarOpacity, 0);
    expect(strongStarOpacity, inInclusiveRange(0.65, 0.90));
    expect(peakStarOpacity, inInclusiveRange(0.65, 0.90));
    expect(scanStartOpacity, 0);
    expect(scanFadeInOpacity, closeTo(0.5, 0.000001));
    expect(scanCenterOpacity, 1);
    expect(scanFadeOutOpacity, closeTo(0.5, 0.000001));
    expect(scanEndOpacity, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('ring pulse does not change target geometry', () {
    const viewport = Size(390, 844);
    const staticConfig = CoffeeCameraConfig(
      effectStyle: CoffeeCameraEffectStyle(ringPulseMaxScale: 1),
    );
    const pulsingConfig = CoffeeCameraConfig(
      effectStyle: CoffeeCameraEffectStyle(ringPulseMaxScale: 1.010),
    );

    final staticTarget = TargetGeometry.fromViewport(viewport, staticConfig);
    final pulsingTarget = TargetGeometry.fromViewport(viewport, pulsingConfig);

    expect(pulsingTarget.center, staticTarget.center);
    expect(pulsingTarget.radius, staticTarget.radius);
    expect(pulsingTarget.bounds, staticTarget.bounds);
  });

  testWidgets('ring pulse stays subtle and is calmer when ready', (
    tester,
  ) async {
    Future<void> showRing({required bool isReady}) {
      return tester.pumpWidget(
        MaterialApp(
          home: CameraTargetOverlay(
            config: const CoffeeCameraConfig(),
            ringColor: isReady ? Colors.green : Colors.red,
            isReady: isReady,
          ),
        ),
      );
    }

    double paintedScale() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('coffee-camera-target-overlay')),
      );
      final dynamic painter = paint.painter;
      return painter.ringVisualScale as double;
    }

    await showRing(isReady: false);
    expect(paintedScale(), 1);
    await tester.pump(const Duration(milliseconds: 700));
    final activeScale = paintedScale();
    expect(activeScale, greaterThan(1));
    expect(activeScale, lessThanOrEqualTo(1.010));

    await tester.pumpWidget(const SizedBox.shrink());
    await showRing(isReady: true);
    await tester.pump(const Duration(milliseconds: 700));
    final readyScale = paintedScale();
    expect(readyScale, greaterThan(1));
    expect(readyScale, lessThan(activeScale));
    expect(readyScale, lessThanOrEqualTo(1.006));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ready lock triggers once per false to true transition', (
    tester,
  ) async {
    var hapticCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls++;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    Future<void> showStatus({
      required bool isReady,
      bool coffeeDetected = false,
      double scanProgress = 0,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: CameraTargetOverlay(
            config: const CoffeeCameraConfig(enableReadyLockHaptic: true),
            ringColor: isReady ? Colors.green : Colors.amber,
            isReady: isReady,
            coffeeDetected: coffeeDetected,
            scanProgress: scanProgress,
          ),
        ),
      );
    }

    dynamic painter() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('coffee-camera-target-overlay')),
      );
      return paint.painter;
    }

    await showStatus(isReady: false);
    expect(hapticCalls, 0);
    expect(painter().readyLockEmphasis, 0);

    await showStatus(isReady: true);
    expect(hapticCalls, 1);
    await tester.pump(const Duration(milliseconds: 120));
    expect(painter().readyLockEmphasis as double, greaterThan(0.99));
    expect(painter().ringVisualScale as double, lessThanOrEqualTo(1.012));
    await tester.pump(const Duration(milliseconds: 120));
    expect(painter().readyLockEmphasis as double, closeTo(0, 0.000001));

    await showStatus(isReady: true, coffeeDetected: true, scanProgress: 0.5);
    expect(hapticCalls, 1);
    expect(painter().readyLockEmphasis as double, closeTo(0, 0.000001));

    await showStatus(isReady: false);
    await showStatus(isReady: true);
    expect(hapticCalls, 2);

    await showStatus(isReady: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await showStatus(isReady: true);
    expect(hapticCalls, 2);
    expect(painter().readyLockEmphasis, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ring pulse pauses with the application lifecycle', (
    tester,
  ) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraTargetOverlay(
          config: CoffeeCameraConfig(),
          ringColor: Colors.red,
        ),
      ),
    );

    double paintedScale() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('coffee-camera-target-overlay')),
      );
      final dynamic painter = paint.painter;
      return painter.ringVisualScale as double;
    }

    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final pausedScale = paintedScale();
    await tester.pump(const Duration(seconds: 1));
    expect(paintedScale(), closeTo(pausedScale, 0.000001));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(paintedScale(), isNot(closeTo(pausedScale, 0.000001)));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ring color safely retargets during rapid status changes', (
    tester,
  ) async {
    const red = Color(0xFFD94747);
    const yellow = Color(0xFFFFC857);
    const green = Color(0xFF45D483);

    Future<void> showRing(Color color) {
      return tester.pumpWidget(
        MaterialApp(
          home: CameraTargetOverlay(
            config: const CoffeeCameraConfig(),
            ringColor: color,
          ),
        ),
      );
    }

    Color paintedRingColor() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('coffee-camera-target-overlay')),
      );
      final dynamic painter = paint.painter;
      return painter.ringColor as Color;
    }

    await showRing(red);
    expect(paintedRingColor(), red);

    await showRing(yellow);
    await tester.pump(const Duration(milliseconds: 60));
    final towardYellow = paintedRingColor();
    expect(towardYellow, isNot(red));
    expect(towardYellow, isNot(yellow));

    await showRing(green);
    expect(paintedRingColor(), towardYellow);
    await tester.pump(const Duration(milliseconds: 220));
    expect(paintedRingColor(), green);

    await showRing(yellow);
    await tester.pump(const Duration(milliseconds: 60));
    final towardYellowAgain = paintedRingColor();
    expect(towardYellowAgain, isNot(green));
    expect(towardYellowAgain, isNot(yellow));

    await showRing(red);
    expect(paintedRingColor(), towardYellowAgain);
    await tester.pump(const Duration(milliseconds: 220));
    expect(paintedRingColor(), red);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('target overlay has stable full-screen dimensions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraTargetOverlay(
          config: CoffeeCameraConfig(),
          ringColor: Colors.green,
          progress: 0.5,
        ),
      ),
    );

    final overlay = find.byKey(const Key('coffee-camera-target-overlay'));
    expect(overlay, findsOneWidget);
    expect(tester.getSize(overlay), const Size(360, 800));
  });

  testWidgets('preview exposes retake and approval actions', (tester) async {
    var retaken = false;
    var approved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoPreview(
          filePath: 'missing-photo.jpg',
          config: const CoffeeCameraConfig(),
          onRetake: () => retaken = true,
          onApprove: () => approved = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Yeniden çek'));
    await tester.tap(find.text('Fotoğrafı onayla'));
    expect(retaken, isTrue);
    expect(approved, isTrue);
  });

  testWidgets('two-step preview exposes its step and back action', (
    tester,
  ) async {
    var backPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoPreview(
          filePath: 'missing-photo.jpg',
          config: const CoffeeCameraConfig(requireSaucerCapture: true),
          title: '2/2 Tabak çekimi',
          onBack: () => backPressed = true,
          onRetake: () {},
          onApprove: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2/2 Tabak çekimi'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri'));
    expect(backPressed, isTrue);
  });

  testWidgets('scan effect stays hidden without a confirmed coffee mask', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraTargetOverlay(
          config: CoffeeCameraConfig(),
          ringColor: Colors.white,
          coffeeDetected: true,
          scanProgress: 0.5,
        ),
      ),
    );

    expect(find.byKey(const Key('coffee-camera-scan-effect')), findsNothing);
  });

  testWidgets('scan effect appears with a dense confirmed coffee mask', (
    tester,
  ) async {
    final values = Uint8List(32 * 32)..fillRange(200, 400, 220);
    final mask = CoffeeRegionMask(
      normalizedBounds: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.3),
      width: 32,
      height: 32,
      intensities: values,
      coverage: 0.25,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CameraTargetOverlay(
          config: const CoffeeCameraConfig(),
          ringColor: Colors.green,
          coffeeDetected: true,
          coffeeMask: mask,
          scanProgress: 0.5,
        ),
      ),
    );

    expect(find.byKey(const Key('coffee-camera-scan-effect')), findsOneWidget);
  });

  testWidgets('scan lights are rebuilt only when the mask changes', (
    tester,
  ) async {
    final values = Uint8List(32 * 32)..fillRange(200, 500, 220);
    final mask = CoffeeRegionMask(
      normalizedBounds: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.3),
      width: 32,
      height: 32,
      intensities: values,
      coverage: 0.3,
    );

    Future<void> showMask(CoffeeRegionMask? value, double progress) {
      return tester.pumpWidget(
        MaterialApp(
          home: CameraTargetOverlay(
            config: const CoffeeCameraConfig(),
            ringColor: Colors.green,
            coffeeDetected: value != null,
            coffeeMask: value,
            scanProgress: progress,
          ),
        ),
      );
    }

    dynamic painter() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('coffee-camera-target-overlay')),
      );
      return paint.painter;
    }

    await showMask(mask, 0.1);
    final firstLights = painter().scanLights as Object;
    expect((painter().scanLights as List).length, 48);

    await showMask(mask, 0.6);
    final animatedFrameLights = painter().scanLights as Object;
    expect(identical(animatedFrameLights, firstLights), isTrue);

    final nextMask = CoffeeRegionMask(
      normalizedBounds: mask.normalizedBounds,
      width: mask.width,
      height: mask.height,
      intensities: values,
      coverage: mask.coverage,
    );
    await showMask(nextMask, 0.7);
    final nextAnalysisLights = painter().scanLights as Object;
    expect(identical(nextAnalysisLights, firstLights), isFalse);
    expect((painter().scanLights as List).length, 48);

    await showMask(null, 0);
    expect(painter().scanLights, isEmpty);
  });
}
