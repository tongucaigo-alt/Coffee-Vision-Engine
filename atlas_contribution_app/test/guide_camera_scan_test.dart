import 'dart:io';
import 'dart:ui' as ui;
import 'package:atlas_contribution_app/src/capture_settings.dart';
import 'package:atlas_contribution_app/src/coffee_guide_page.dart';
import 'package:atlas_contribution_app/src/guide_scan_sample.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_camera/src/analysis/coffee_region_analyzer.dart';
import 'package:coffee_camera/src/ui/camera_target_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Widget _guide({bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: CoffeeGuidePage(onComplete: (_) async {}),
  ),
);

void main() {
  test(
    'sample mask is the actual analyzer result for the teaching photograph',
    () async {
      final photo = img.decodePng(
        File('assets/guide/example-cup.png').readAsBytesSync(),
      )!;
      final size = ui.Size(photo.width.toDouble(), photo.height.toDouble());
      final result = await const CoffeeRegionAnalyzer().analyze(
        frame: AnalysisFrame(
          width: photo.width,
          height: photo.height,
          rotationDegrees: 0,
          format: AnalysisFrameFormat.bgra8888,
          bytes: photo.getBytes(order: img.ChannelOrder.bgra),
          bytesPerRow: photo.width * 4,
          bytesPerPixel: 4,
          previewTransform: PreviewTransform.oriented(
            sourceSize: size,
            viewportSize: size,
          ),
        ),
        cup: const CupDetectionResult(
          confidence: 1,
          normalizedBounds: ui.Rect.fromLTRB(.14, .10, .87, .79),
        ),
        config: cameraConfigForRole(CaptureRole.free),
      );
      expect(result.mask, isNotNull);
      expect(
        result.mask!.normalizedBounds,
        guideScanSampleMask.normalizedBounds,
      );
      expect(
        result.mask!.intensities,
        orderedEquals(guideScanSampleMask.intensities),
      );
      expect(result.mask!.coverage, guideScanSampleMask.coverage);
      expect(
        result.mask!.requiresStrictPhotoVerification,
        guideScanSampleMask.requiresStrictPhotoVerification,
      );
    },
  );

  testWidgets(
    'capture guide replays the camera renderer then stops without capture',
    (tester) async {
      await tester.pumpWidget(_guide());
      await tester.tap(find.byKey(const ValueKey('guide-next')));
      await tester.pump();
      CameraTargetOverlay overlay() =>
          tester.widget<CameraTargetOverlay>(find.byType(CameraTargetOverlay));
      expect(overlay().coffeeDetected, false);
      await tester.pump(const Duration(milliseconds: 950));
      expect(overlay().coffeeDetected, true);
      expect(overlay().coffeeMask, same(guideScanSampleMask));
      expect(overlay().scanProgress, closeTo(350 / 1350, .001));
      expect(
        find.byKey(const Key('coffee-camera-scan-effect')),
        findsOneWidget,
      );
      expect(overlay().isReady, false);
      expect(overlay().progress, 0);
      expect(overlay().flash, false);
      expect(find.byType(CoffeeCameraScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 1350));
      expect(overlay().scanProgress, closeTo(350 / 1350, .001));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(overlay().scanProgress, .5);
      await tester.ensureVisible(find.byKey(const ValueKey('guide-replay')));
      await tester.tap(find.byKey(const ValueKey('guide-replay')));
      await tester.pump();
      expect(overlay().coffeeDetected, false);
      await tester.pump(const Duration(milliseconds: 950));
      expect(overlay().coffeeDetected, true);
      expect(overlay().scanProgress, closeTo(350 / 1350, .001));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion keeps the real scan renderer static', (
    tester,
  ) async {
    await tester.pumpWidget(_guide(reduced: true));
    await tester.tap(find.byKey(const ValueKey('guide-next')));
    await tester.pumpAndSettle();
    final overlay = tester.widget<CameraTargetOverlay>(
      find.byType(CameraTargetOverlay),
    );
    expect(overlay.coffeeMask, same(guideScanSampleMask));
    expect(overlay.scanProgress, .5);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byKey(const ValueKey('guide-replay')), findsNothing);
  });
}
