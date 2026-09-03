import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_app.dart';
import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_models.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tolerates the zero-size Android warm-up frame', (tester) async {
    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('presents the three roles in their canonical order', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Fincanını üç açıdan çek'), findsOneWidget);
    final positions = [
      tester.getTopLeft(find.text('Üst açı')).dy,
      tester.getTopLeft(find.text('Yan açı · Kulp sağda')).dy,
      tester.getTopLeft(find.text('Yan açı · Kulp solda')).dy,
    ];
    expect(positions[0], lessThan(positions[1]));
    expect(positions[1], lessThan(positions[2]));
  });

  testWidgets('runs one camera attempt per step and completes the session', (
    tester,
  ) async {
    final roles = <AtlasCupCaptureRole>[];
    await tester.pumpWidget(
      _app(
        launcher: (_, role) async {
          roles.add(role);
          return _capture('missing-${role.name}.jpg');
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
    await tester.pumpAndSettle();
    expect(find.text('Üst açıyı çek'), findsOneWidget);

    for (final expectedLabel in [
      'Kulp sağdayken çek',
      'Kulp soldayken çek',
      'Çekimleri tamamla',
    ]) {
      await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
      await tester.pumpAndSettle();
      expect(find.text(expectedLabel), findsOneWidget);
    }

    expect(roles, AtlasCupCaptureRole.values);
    await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('three-angle-complete')), findsOneWidget);
    expect(find.text('Üç açı hazır'), findsOneWidget);
  });

  testWidgets('partial back flow can preserve or discard the session', (
    tester,
  ) async {
    final released = <CameraCaptureResult>[];
    await tester.pumpWidget(
      _app(release: (captures) async => released.addAll(captures)),
    );
    await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Çekimden çıkılsın mı?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('keep-capturing')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(released, isEmpty);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discard-captures')));
    await tester.pumpAndSettle();
    expect(find.text('Fincanını üç açıdan çek'), findsOneWidget);
    expect(released, hasLength(1));
  });

  testWidgets('retake is transactional in the app-local flow', (tester) async {
    final original = _capture('missing-top-original.jpg');
    final replacement = _capture('missing-top-replacement.jpg');
    final responses = <CameraCaptureResult?>[
      original,
      _capture('missing-right.jpg'),
      _capture('missing-left.jpg'),
      null,
      replacement,
    ];
    final released = <CameraCaptureResult>[];
    await tester.pumpWidget(
      _app(
        launcher: (_, _) async => responses.removeAt(0),
        release: (captures) async => released.addAll(captures),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('retake-top')));
    await tester.pumpAndSettle();
    expect(released, isEmpty);
    expect(find.text('Çekimleri tamamla'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retake-top')));
    await tester.pumpAndSettle();
    expect(released, hasLength(1));
    expect(identical(released.single, original), isTrue);
  });

  testWidgets('has no layout overflow on supported phone viewports', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final size in [const Size(360, 800), const Size(412, 915)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'intro at $size');

      await tester.ensureVisible(
        find.byKey(const ValueKey('start-three-angle-capture')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
      await tester.pumpAndSettle();
      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: 'session at $size');

      await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'complete at $size');
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Widget _app({
  Future<CameraCaptureResult?> Function(
    BuildContext context,
    AtlasCupCaptureRole role,
  )?
  launcher,
  Future<void> Function(Iterable<CameraCaptureResult> captures)? release,
}) {
  return AtlasThreeAngleCaptureApp(
    cameraLauncher:
        launcher ?? (_, role) async => _capture('missing-${role.name}.jpg'),
    releaseCaptures: release ?? (_) async {},
  );
}

CameraCaptureResult _capture(String path) {
  return CameraCaptureResult(
    filePath: path,
    cropRect: const Rect.fromLTWH(0, 0, 10, 10),
    widthPixels: 100,
    heightPixels: 100,
    fileSizeBytes: 10,
    capturedAt: DateTime.utc(2026, 9, 3),
    qualityScore: 80,
    coffeePresenceScore: 0.8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}
