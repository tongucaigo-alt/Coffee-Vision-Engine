import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/coffee_loading_animation.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'fixtures.dart';

void main() {
  setUpAll(() async {
    await AssetLottie('assets/animations/coffee-love.json').load();
    for (final (name, asset) in [
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
  });

  Future<void> load(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(Lottie), findsOneWidget);
  }

  AnimationController player(WidgetTester tester) =>
      tester.widget<Lottie>(find.byType(Lottie)).controller!
          as AnimationController;

  Widget host(
    FortunePreparationController flow, {
    double scale = 1,
    bool reduced = false,
    Key? captureKey,
  }) => MaterialApp(
    theme: atlasTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduced,
      ),
      child: RepaintBoundary(
        key: captureKey,
        child: FortunePreparationHost(controller: flow, child: child!),
      ),
    ),
    home: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) flow.cancel();
      },
      child: Scaffold(
        body: TextButton(
          onPressed: () => fail('Review must be blocked'),
          child: const Text('review control'),
        ),
      ),
    ),
  );

  void begin(FortunePreparationController flow, {int count = 1}) => flow.begin(
    photos: [
      for (var i = 0; i < count; i++)
        testPhoto(CaptureRole.free).asSetPhoto(photoId: 'p$i'),
    ],
    imageFor: (_) => MemoryImage(testImage()),
    onCancel: () {},
    requireMarkedPhotos: true,
  );

  for (final size in [
    const Size(360, 700),
    const Size(412, 700),
    const Size(320, 480),
    const Size(700, 320),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('minimal stages fit ${size.width}x${size.height} at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final progress = ValueNotifier(
          const FortuneProgress(FortunePhase.saving),
        );
        final flow = FortunePreparationController(progress);
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          host(flow, scale: scale, captureKey: captureKey),
        );
        begin(flow, count: scale == 2 ? 3 : 1);
        await tester.pump();
        await load(tester);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(FortuneScan), findsNothing);
        expect(find.text('Durdur'), findsNothing);
        expect(find.text('review control').hitTestable(), findsNothing);
        expect(find.text('Sıraya alınıyor…'), findsOneWidget);
        final animation = find.byType(CoffeeLoadingAnimation);
        final bounds = tester.getRect(animation);
        final expected = ((size.width - 32) * .52)
            .clamp(160.0, 220.0)
            .clamp(0.0, (size.height - 32) * .4);
        expect(bounds.width, closeTo(expected, .01));
        expect(bounds.height, closeTo(expected, .01));
        final text = tester.getRect(
          find.byKey(const ValueKey('fortune-waiting-status')),
        );
        expect(text.top - bounds.bottom, closeTo(16, .01));
        final group = tester.getRect(
          find.byKey(const ValueKey('fortune-waiting-group')),
        );
        expect(group.center.dy, closeTo(size.height / 2, .01));
        expect(group.top, greaterThanOrEqualTo(16));
        expect(group.bottom, lessThanOrEqualTo(size.height - 16));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('fortune-waiting-status')),
              )
              .textScaler,
          isNull,
        );
        final controller = player(tester);
          await tester.pump(const Duration(milliseconds: 2800));
        final before = controller.value;
        expect(before, greaterThan(0));
        Future<void> capture(String stage) async {
          final out = Platform.environment['ATLAS_V90_SCREENSHOTS'];
          if (out == null) return;
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '$out/$stage-${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('siraya-aliniyor');
        progress.value = const FortuneProgress(FortunePhase.analyzing);
        await tester.pump();
        expect(find.text('Hazırlanıyor…'), findsOneWidget);
        expect(player(tester), same(controller));
        expect(controller.value, closeTo(before, .001));
        expect(tester.getRect(animation), bounds);
        await tester.pump(const Duration(milliseconds: 650));
        expect(controller.value, greaterThan(before));
        await capture('hazirlaniyor');
        expect(tester.takeException(), isNull);
        flow.finish();
        await tester.pumpWidget(const SizedBox());
        flow.dispose();
        progress.dispose();
      });
    }
  }

  testWidgets(
    'back cancels once, stops playback and keeps the safe cancellation message',
    (tester) async {
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.saving),
      );
      final flow = FortunePreparationController(progress);
      var cancellations = 0;
      await tester.pumpWidget(host(flow));
      begin(flow);
      flow.onCancel = () => cancellations++;
      await tester.pump();
      await load(tester);
      final controller = player(tester);
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(cancellations, 1);
      expect(controller.isAnimating, isFalse);
      expect(
        find.text(const FortuneProgress(FortunePhase.cancelled).message),
        findsOneWidget,
      );
      final position = controller.value;
      await tester.pump(const Duration(seconds: 2));
      expect(controller.value, position);
      flow.finish();
      await tester.pump();
      expect(find.text('review control').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
      progress.dispose();
    },
  );

  testWidgets(
    'reduced motion and failure retain a static cup; readiness alone reveals the photo phase',
    (tester) async {
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.analyzing),
      );
      final flow = FortunePreparationController(progress);
      await tester.pumpWidget(host(flow, reduced: true));
      begin(flow, count: 3);
      await tester.pump();
      await load(tester);
      expect(player(tester).value, .4);
      expect(player(tester).isAnimating, isFalse);
      progress.value = const FortuneProgress(FortunePhase.failed);
      await tester.pump();
      expect(find.text(progress.value.message), findsOneWidget);
      expect(player(tester).isAnimating, isFalse);
      flow.finish();
      progress.value = const FortuneProgress(FortunePhase.analyzing);
      begin(flow, count: 3);
      flow.updateTraces(TraceSet(flow.photos, []), complete: true);
      await tester.pump();
      expect(find.byType(FortuneScan), findsNothing);
      flow.permitDisplay();
      await tester.pump();
      expect(find.byType(FortuneScan), findsOneWidget);
      expect(find.text('Fincanının Hikâyesi'), findsOneWidget);
      expect(
        tester
            .widget<CoffeeLoadingAnimation>(find.byType(CoffeeLoadingAnimation))
            .size,
        72,
      );
      expect(find.text('Durdur'), findsOneWidget);
      flow.finish();
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
      progress.dispose();
    },
  );
}
