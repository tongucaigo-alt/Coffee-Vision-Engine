import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/coffee_loading_animation.dart';
import 'package:atlas_contribution_app/src/cropped_photo.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AssetLottie('assets/animations/coffee-love.json').load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final (name, asset) in [
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
  });
  Widget screen({
    bool reduced = false,
    FortunePhase phase = FortunePhase.generating,
    List<ContributionPhoto>? photos,
    VoidCallback? cancel,
    double scale = 1,
    ImageProvider? image,
    Key? captureKey,
  }) => MaterialApp(
    theme: atlasTheme(),
    home: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 412),
        child: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: captureKey,
            child: Scaffold(
              appBar: AppBar(title: const Text('Fincanının Hikâyesi')),
              body: FortuneScan(
                progress: FortuneProgress(phase),
                photos: photos ?? [testPhoto(CaptureRole.free)],
                imageFor: (_) => image ?? MemoryImage(testImage()),
                showDecorativeSymbols: true,
                onCancel: cancel,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> load(WidgetTester tester) async {
    if (tester.view.physicalSize.width > 500) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pump();
    }
    for (var i = 0; i < 10 && find.byType(Lottie).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(Lottie), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  AnimationController controller(WidgetTester tester) =>
      tester.widget<Lottie>(find.byType(Lottie)).controller!
          as AnimationController;

  test(
    'the supplied vector animation is a complete seven-second composition',
    () async {
      final composition = await AssetLottie(
        'assets/animations/coffee-love.json',
      ).load();
      expect(composition.duration, const Duration(seconds: 7));
      expect(composition.bounds.width, 512);
      expect(composition.bounds.height, 512);
      expect(composition.layers, isNotEmpty);
    },
  );
  testWidgets(
    'photo switches and phase changes keep the same independently running animation',
    (tester) async {
      final photos = [
        testPhoto(CaptureRole.free).asSetPhoto(photoId: 'first'),
        testPhoto(CaptureRole.handleRight).asSetPhoto(photoId: 'second'),
      ];
      await tester.pumpWidget(screen(photos: photos));
      await load(tester);
      final player = controller(tester);
      final photoBefore = tester.widget<CroppedPhoto>(
        find.byType(CroppedPhoto),
      );
      await tester.pump(const Duration(milliseconds: 3800));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<CroppedPhoto>(find.byType(CroppedPhoto)),
        isNot(same(photoBefore)),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == photos[1].title,
        ),
        findsOneWidget,
      );
      expect(controller(tester), same(player));
      expect(player.value, greaterThan(.5));
      final beforePhase = player.value;
      await tester.pumpWidget(
        screen(photos: photos, phase: FortunePhase.repairing),
      );
      expect(controller(tester), same(player));
      expect(player.value, closeTo(beforePhase, .001));
      await tester.pump(const Duration(milliseconds: 400));
      expect(player.value, greaterThan(beforePhase));
      expect(find.byKey(const ValueKey('fortune-orbit-frame')), findsNothing);
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reduced motion shows a stationary cup with an accessible status',
    (tester) async {
      await tester.pumpWidget(screen(reduced: true));
      await load(tester);
      final player = controller(tester);
      final position = player.value;
      expect(position, .4);
      expect(player.isAnimating, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(player.value, position);
      expect(find.text('Fincanının hikâyesi hazırlanıyor'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final phase in [
    FortunePhase.completed,
    FortunePhase.failed,
    FortunePhase.cancelled,
  ]) {
    testWidgets('coffee animation stops for $phase', (tester) async {
      await tester.pumpWidget(screen());
      await load(tester);
      final player = controller(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(player.value, greaterThan(0));
      await tester.pumpWidget(screen(phase: phase));
      final stopped = player.value;
      expect(player.isAnimating, isFalse);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(player.value, stopped);
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'cup stays below unchanged photo and above status: $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var cancelled = 0;
          await tester.pumpWidget(
            screen(scale: scale, cancel: () => cancelled++),
          );
          await load(tester);
          final photo = tester.getRect(find.byType(CroppedPhoto));
          // Original V75 padding/aspect ratio; animation may not consume photo space.
          expect(
            photo,
            Rect.fromLTWH(24, 104, width - 48, (width - 48) * 200 / 160),
          );
          final loading = tester.getRect(find.byType(CoffeeLoadingAnimation));
          expect(loading.size, const Size(72, 72));
          expect(loading.top, greaterThan(photo.bottom));
          expect(
            tester.getRect(find.text('Fincanının hikâyesi hazırlanıyor')).top,
            greaterThan(loading.bottom),
          );
          await tester.scrollUntilVisible(find.text('Durdur'), 100);
          await tester.pump();
          await tester.tap(find.text('Durdur'));
          expect(cancelled, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('capture the approved loading layout without invoking AI', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('ATLAS_LOADING_CAPTURE')) return;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final photo = ContributionPhoto.fromJson({
      ...testPhoto(CaptureRole.free).toJson(),
      'width': 960,
      'height': 1280,
    });
    final image = FileImage(
      File(
        'C:/Users/exzau/Documents/Codex/2026-10-11/atlas-opencv-v49/outputs/coffee-ui-v61/reports/fixture.jpg',
      ),
    );
    await tester.pumpWidget(
      screen(
        photos: [photo],
        reduced: false,
        cancel: () {},
        image: image,
        captureKey: key,
      ),
    );
    await load(tester);
    var imageReady = false;
    precacheImage(
      image,
      key.currentContext!,
    ).whenComplete(() => imageReady = true);
    for (var i = 0; i < 100 && !imageReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(imageReady, isTrue);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels = await boundary.toImage(pixelRatio: 2);
      final data = await pixels.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'C:/Users/exzau/Documents/Codex/2026-10-16/atlas-coffee-loading-ui-output/screenshots/coffee-loading.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      pixels.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
