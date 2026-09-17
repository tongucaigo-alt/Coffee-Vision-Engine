import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/camera_focus_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(390, 844);
  final target = TargetGeometry.fromViewport(
    viewport,
    const CoffeeCameraConfig(),
  );

  test(
    'camera focus presentation is opt-in without changing target geometry',
    () {
      const legacy = CoffeeCameraConfig();
      const focused = CoffeeCameraConfig(
        backgroundBlurSigma: 5,
        handleGuide: CameraHandleGuide.right,
      );
      expect(legacy.backgroundBlurSigma, 0);
      expect(legacy.handleGuide, CameraHandleGuide.none);
      expect(
        TargetGeometry.fromViewport(viewport, focused).bounds,
        target.bounds,
      );
      expect(
        () => CoffeeCameraConfig(backgroundBlurSigma: -1),
        throwsAssertionError,
      );
      expect(
        () => CoffeeCameraConfig(backgroundBlurSigma: double.nan),
        throwsAssertionError,
      );
    },
  );

  for (final guide in [CameraHandleGuide.right, CameraHandleGuide.left]) {
    test(
      '$guide clears exactly one attached handle and keeps outer area shaded',
      () {
        final region = CameraFocusRegion(target: target, handleGuide: guide);
        final direction = guide == CameraHandleGuide.right ? 1.0 : -1.0;
        final handleCenter = target.center.translate(
          direction * target.radius * 1.15,
          0,
        );
        final oppositeSide = target.center.translate(
          -direction * target.radius * 1.15,
          0,
        );
        final attachment = target.center.translate(
          direction * target.radius * 0.99,
          0,
        );
        final clear = region.clearArea;
        final shade = region.shadePath(viewport);
        expect(clear.contains(target.center), isTrue);
        expect(clear.contains(handleCenter), isTrue);
        expect(clear.contains(attachment), isTrue);
        expect(clear.contains(oppositeSide), isFalse);
        expect(shade.contains(target.center), isFalse);
        expect(shade.contains(handleCenter), isFalse);
        expect(shade.contains(attachment), isFalse);
        expect(shade.contains(oppositeSide), isTrue);
        expect(shade.contains(const Offset(10, 10)), isTrue);
        final outline = region.handleOutline.getBounds();
        expect(outline.left, greaterThanOrEqualTo(8));
        expect(outline.right, lessThanOrEqualTo(viewport.width - 8));
        expect(
          outline.top,
          closeTo(target.center.dy - target.radius * 0.28, 0.001),
        );
      },
    );
  }

  test(
    'handle adapts to available screen width without changing the cup circle',
    () {
      for (final guide in [CameraHandleGuide.right, CameraHandleGuide.left]) {
        final narrowTarget = TargetGeometry.fromViewport(
          viewport,
          const CoffeeCameraConfig(targetDiameterWidthRatio: 0.94),
        );
        final region = CameraFocusRegion(
          target: narrowTarget,
          handleGuide: guide,
        );
        expect(region.handleOutline.getBounds().left, greaterThanOrEqualTo(8));
        expect(
          region.handleOutline.getBounds().right,
          lessThanOrEqualTo(viewport.width - 8),
        );
        expect(region.clearArea.contains(narrowTarget.center), isTrue);
      }
    },
  );

  test('free angle has the same circular clear area as the legacy camera', () {
    final region = CameraFocusRegion(
      target: target,
      handleGuide: CameraHandleGuide.none,
    );
    expect(region.handleOutline.computeMetrics(), isEmpty);
    final clearBounds = region.clearArea.getBounds();
    expect(clearBounds.left, closeTo(target.bounds.left, 0.001));
    expect(clearBounds.top, closeTo(target.bounds.top, 0.001));
    expect(clearBounds.right, closeTo(target.bounds.right, 0.001));
    expect(clearBounds.bottom, closeTo(target.bounds.bottom, 0.001));
    expect(region.shadePath(viewport).contains(target.center), isFalse);
  });

  testWidgets(
    'blur clips only outside target and handle without intercepting taps',
    (tester) async {
      var taps = 0;
      final region = CameraFocusRegion(
        target: target,
        handleGuide: CameraHandleGuide.right,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.fromSize(
              size: viewport,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => taps++,
                    behavior: HitTestBehavior.opaque,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                  CameraBackgroundFocus(region: region, sigma: 5),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Text('Net yönlendirme'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      final clip = tester.widget<ClipPath>(find.byType(ClipPath));
      final mask = clip.clipper!.getClip(viewport);
      expect(mask.contains(target.center), isFalse);
      expect(
        mask.contains(target.center.translate(target.radius * 1.15, 0)),
        isFalse,
      );
      expect(mask.contains(const Offset(10, 10)), isTrue);
      expect(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      await tester.tap(find.byType(CameraBackgroundFocus));
      expect(taps, 1);
      await tester.pumpWidget(
        MaterialApp(home: CameraBackgroundFocus(region: region, sigma: 0)),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );
}
