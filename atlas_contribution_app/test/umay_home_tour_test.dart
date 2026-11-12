import 'dart:io';
import 'dart:ui' as ui;

import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_home_hints.dart';
import 'package:atlas_contribution_app/src/coffee_guide_page.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/umay_home_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/umay_guide_preview.dart';

Widget app(
  Widget home, {
  double scale = 1,
  bool reduced = true,
  double keyboard = 0,
  GlobalKey? capture,
}) => MaterialApp(
  theme: atlasTheme(),
  debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
      viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: child!,
  ),
  home: capture == null ? home : RepaintBoundary(key: capture, child: home),
);

Future<void> ready(WidgetTester tester) async {
  await tester.pump();
  final contexts = find.byType(UmayGuidePreview).evaluate();
  if (contexts.isNotEmpty) {
    await tester.runAsync(
      () => Future.wait([
        for (final asset in [
          'assets/umay/umay-speaking-left.png',
          'assets/umay/umay-speaking-right.png',
          'assets/umay/umay-calm-right.png',
          'assets/brand/atlas-logo.png',
          'assets/buttons/atlas_camera_button.webp',
          'assets/buttons/atlas_gallery_button.webp',
        ])
          precacheImage(AssetImage(asset), contexts.first),
      ]),
    );
  }
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['UMAY_CAPTURE_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final box =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'Literata': 'assets/brand/Literata.ttf',
      'EB Garamond': 'assets/brand/EBGaramond.ttf',
      'packages/lucide_icons_flutter/Lucide':
          'packages/lucide_icons_flutter/assets/lucide.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  testWidgets(
    'four actual V131 targets, user-paced steps, no underlying actions or layout changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 892);
      addTearDown(tester.view.reset);
      final store = GuidePreviewStore();
      final inputs = GuidePreviewInputs();
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          UmayGuidePreview(store: store, inputs: inputs),
          capture: key,
        ),
      );
      await ready(tester);
      final bounds = <String, Rect>{};
      for (var i = 0; i < 4; i++) {
        final target = find.byKey(ValueKey(umayTourSteps[i].target));
        final marker = find.byKey(const ValueKey('umay-tour-target'));
        expect(marker, findsOneWidget);
        expect(tester.getRect(marker), tester.getRect(target));
        bounds[umayTourSteps[i].target] = tester.getRect(target);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('umay-tour-bubble')))
              .overlaps(tester.getRect(marker)),
          isFalse,
        );
        expect(find.text('${i + 1}/4'), findsOneWidget);
        // The tour remains until the user acts; neither timeout nor old home hints advances it.
        await tester.pump(const Duration(seconds: 8));
        expect(find.text('${i + 1}/4'), findsOneWidget);
        await capture(tester, key, 'step-${i + 1}');
        await tester.tap(marker);
        await ready(tester);
      }
      expect(find.text('Tanıtım tamamlandı'), findsOneWidget);
      expect(store.writes, 0);
      expect(inputs.cameraLaunches, 0);
      expect(inputs.galleryLaunches, 0);
      await capture(tester, key, 'complete');
      // Compare the same controls without the overlay, not just their decorations.
      final preferences = AtlasHomeHintPreferences()..automaticEnabled = false;
      await tester.pumpWidget(
        app(
          AtlasHomeHintScope(
            preferences: preferences,
            child: ContributionHome(
              modern: true,
              store: store,
              service: OfflineContributionService(store),
              tarotPage: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await ready(tester);
      for (final entry in bounds.entries) {
        expect(tester.getRect(find.byKey(ValueKey(entry.key))), entry.value);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      preferences.dispose();
    },
  );

  testWidgets(
    'back, skip, restart and original detailed guide never persist state',
    (tester) async {
      final store = GuidePreviewStore();
      await tester.pumpWidget(app(UmayGuidePreview(store: store)));
      await ready(tester);
      await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(tester);
      expect(find.text('2/4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('umay-tour-back')));
      await ready(tester);
      expect(find.text('1/4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('umay-tour-skip')));
      await ready(tester);
      expect(find.text('Tanıtımı kapattın'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('umay-tour-detail')));
      await ready(tester);
      expect(find.byType(CoffeeGuidePage), findsOneWidget);
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
      for (var i = 1; i < coffeeGuideCardCount; i++) {
        await tester.tap(find.byKey(const ValueKey('guide-next')));
        await ready(tester);
      }
      await tester.tap(find.byKey(const ValueKey('guide-next')));
      await ready(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CoffeeGuidePage), findsNothing);
      await tester.tap(find.byKey(const ValueKey('umay-tour-restart')));
      await ready(tester);
      expect(find.text('1/4'), findsOneWidget);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native background and resume preserves step and restores avatar',
    (tester) async {
      await tester.pumpWidget(app(const UmayGuidePreview(), reduced: false));
      await ready(tester);
      await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await ready(tester);
      expect(find.text('2/4'), findsOneWidget);
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsOneWidget);
      expect(find.byKey(const ValueKey('umay-tour-target')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      double y() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('umay-tour-avatar-motion')),
          )
          .transform
          .getTranslation()
          .y;
      expect(y(), closeTo(0, .001));
      await tester.pump(const Duration(seconds: 1));
      expect(y(), closeTo(0, .001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px screen at ${scale}x text: all controls fit and reduced motion is still',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          app(const UmayGuidePreview(), scale: scale, capture: key),
        );
        await ready(tester);
        for (var i = 0; i < 4; i++) {
          final target = find.byKey(const ValueKey('umay-tour-target'));
          final bubble = tester.getRect(
            find.byKey(const ValueKey('umay-tour-bubble')),
          );
          final next = tester.getRect(
            find.byKey(const ValueKey('umay-tour-next')),
          );
          expect(
            (const Rect.fromLTWH(0, 24, 320, 592)).contains(bubble.topLeft),
            isTrue,
          );
          expect(bubble.contains(next.center), isTrue);
          if (target.evaluate().isNotEmpty) {
            expect(bubble.overlaps(tester.getRect(target)), isFalse);
          } else {
            expect(scale, 2.0);
            expect(i, 0);
            expect(find.textContaining('kamera tuşuyla'), findsOneWidget);
          }
          final motion = tester.widget<Transform>(
            find.byKey(const ValueKey('umay-tour-avatar-motion')),
          );
          expect(motion.transform.getTranslation().y, 0);
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'small-${scale}x-step-${i + 1}');
          await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
          await ready(tester);
        }
        expect(find.text('Tanıtım tamamlandı'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'keyboard and missing targets use a readable fallback without an incorrect marker',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        app(const UmayGuidePreview(), scale: 2, keyboard: 280, capture: key),
      );
      await ready(tester);
      final bubble = tester.getRect(
        find.byKey(const ValueKey('umay-tour-bubble')),
      );
      expect(bubble.bottom, lessThanOrEqualTo(360));
      expect(find.byKey(const ValueKey('umay-tour-target')), findsNothing);
      expect(find.textContaining('kamera tuşuyla'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('umay-tour-next')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'keyboard-2x');
      await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(tester);
      expect(find.text('2/4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
