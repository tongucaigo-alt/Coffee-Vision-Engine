import 'dart:io';
import 'dart:ui' as ui;

import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:atlas_contribution_app/src/umay_home_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/umay_annotation_guide.dart';
import '../tool/umay_guide_preview.dart';

Widget _app(
  Widget home, {
  double scale = 1,
  bool reduced = true,
  bool bold = false,
  EdgeInsets insets = const EdgeInsets.only(top: 24, bottom: 24),
  GlobalKey? capture,
}) => MaterialApp(
  theme: atlasTheme(),
  debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
      boldText: bold,
      padding: insets,
      viewPadding: insets,
    ),
    child: child!,
  ),
  home: capture == null ? home : RepaintBoundary(key: capture, child: home),
);

Future<void> _ready(WidgetTester tester) async {
  await tester.pump();
  final context = find.byType(UmayHomeTour).evaluate().firstOrNull;
  if (context != null) {
    await tester.runAsync(
      () => Future.wait([
        for (final asset in [
          'assets/umay/umay-speaking-left.png',
          'assets/umay/umay-speaking-right.png',
          'assets/umay/umay-calm-right.png',
          'assets/guide/example-cup.png',
        ])
          precacheImage(AssetImage(asset), context),
      ]),
    );
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['UMAY_ANNOTATION_CAPTURE_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void _unchanged(AnnotationGuideAudit a) {
  expect(a.draftChanges, 0);
  expect(a.finishActions, 0);
  expect(a.saveActions, 0);
  expect(a.skipActions, 0);
  expect(a.photoChanges, 0);
  expect(a.focusChanges, 0);
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'Literata': 'assets/brand/Literata.ttf',
      'packages/lucide_icons_flutter/Lucide':
          'packages/lucide_icons_flutter/assets/lucide.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  testWidgets(
    '18 actual annotation targets, prepared sample states and no save/generation actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 892);
      addTearDown(tester.view.reset);
      final audit = AnnotationGuideAudit();
      final key = GlobalKey();
      bool? complete;
      await tester.pumpWidget(
        _app(
          UmayAnnotationGuide(
            audit: audit,
            onFinish: (done) {
              complete = done;
            },
          ),
          capture: key,
        ),
      );
      await _ready(tester);
      for (var i = 0; i < umayAnnotationSteps.length; i++) {
        expect(find.text('${i + 1}/18'), findsOneWidget);
        expect(find.byType(AnnotationPage), findsOneWidget);
        final marker = find.byKey(const ValueKey('umay-tour-target'));
        final target = find.byKey(ValueKey(umayAnnotationSteps[i].target));
        expect(
          marker,
          findsOneWidget,
          reason: 'step ${i + 1}: ${umayAnnotationSteps[i].target}',
        );
        expect(tester.getRect(marker), tester.getRect(target));
        expect(find.byKey(const ValueKey('umay-tour-avatar')), findsOneWidget);
        final bubble = tester.getRect(
          find.byKey(const ValueKey('umay-tour-bubble')),
        );
        expect(
          bubble.overlaps(tester.getRect(marker)),
          isFalse,
          reason: 'step ${i + 1} overlaps target',
        );
        if (i == 1) {
          expect(
            tester
                .widget<Semantics>(
                  find
                      .ancestor(
                        of: target,
                        matching: find.byWidgetPredicate(
                          (w) => w is Semantics && w.properties.label == 'Taşı',
                        ),
                      )
                      .first,
                )
                .properties
                .selected,
            true,
          );
        }
        if ([3, 4].contains(i)) {
          expect(find.byType(LabelPicker), findsOneWidget);
        }
        if ([5, 7, 8].contains(i)) {
          expect(find.byKey(const ValueKey('selected-region')), findsOneWidget);
        }
        _unchanged(audit);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(
          tester.getRect(marker),
          tester.getRect(target),
          reason: 'settled target at step ${i + 1}',
        );
        if (i == 0) {
          final message = tester.widget<SingleChildScrollView>(
            find.byKey(const ValueKey('umay-tour-message')),
          );
          expect(message.controller!.position.maxScrollExtent, 0);
        }
        expect(find.text('${i + 1}/18'), findsOneWidget);
        await _capture(
          tester,
          key,
          'step-${(i + 1).toString().padLeft(2, '0')}',
        );
        await tester.tap(marker);
        await _ready(tester);
      }
      expect(complete, true);
      _unchanged(audit);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'back through picker and selection restores the right sample without writing',
    (tester) async {
      final audit = AnnotationGuideAudit();
      await tester.pumpWidget(
        _app(UmayAnnotationGuide(audit: audit, onFinish: (_) {})),
      );
      await _ready(tester);
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
        await _ready(tester);
      }
      expect(find.text('8/18'), findsOneWidget);
      for (var i = 7; i > 2; i--) {
        await tester.tap(find.byKey(const ValueKey('umay-tour-back')));
        await _ready(tester);
        expect(find.text('$i/18'), findsOneWidget);
        expect(find.byKey(const ValueKey('umay-tour-target')), findsOneWidget);
      }
      expect(find.byType(LabelPicker), findsNothing);
      _unchanged(audit);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('native resume restores the current picker step and avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(UmayAnnotationGuide(onFinish: (_) {}), reduced: false),
    );
    await _ready(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
      await _ready(tester);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(const ValueKey('umay-tour-avatar')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _ready(tester);
    expect(find.text('4/18'), findsOneWidget);
    expect(find.byType(LabelPicker), findsOneWidget);
    expect(find.byKey(const ValueKey('umay-tour-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('umay-tour-target')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'preview opens the new tour, restarts and retains the four-step home guide',
    (tester) async {
      await tester.pumpWidget(
        _app(const UmayGuidePreview(startWithAnnotationTour: true)),
      );
      await _ready(tester);
      expect(find.text('1/18'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('umay-tour-skip')));
      await _ready(tester);
      expect(find.text('İşaretlemeyi yeniden göster'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('umay-tour-restart')));
      await _ready(tester);
      expect(find.text('1/18'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('umay-tour-skip')));
      await _ready(tester);
      await tester.tap(find.byKey(const ValueKey('umay-tour-other')));
      await _ready(tester);
      expect(find.text('1/4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'phone-sized bold text shows the full messages at normal text size',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          UmayAnnotationGuide(onFinish: (_) {}),
          bold: true,
          insets: const EdgeInsets.only(top: 32, bottom: 48),
          capture: key,
        ),
      );
      await _ready(tester);
      for (var i = 0; i < umayAnnotationSteps.length; i++) {
        final message = tester.widget<SingleChildScrollView>(
          find.byKey(const ValueKey('umay-tour-message')),
        );
        expect(
          message.controller!.position.maxScrollExtent,
          0,
          reason: 'bold message at step ${i + 1}',
        );
        expect(tester.takeException(), isNull);
        if ([0, 1, 3, 5].contains(i)) {
          await _capture(tester, key, 'phone-bold-step-${i + 1}');
        }
        await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
        await _ready(tester);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px, ${scale}x text, every step remains navigable without overflow',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final audit = AnnotationGuideAudit();
        await tester.pumpWidget(
          _app(
            UmayAnnotationGuide(audit: audit, onFinish: (_) {}),
            scale: scale,
            capture: key,
          ),
        );
        await _ready(tester);
        for (var i = 0; i < umayAnnotationSteps.length; i++) {
          expect(find.text('${i + 1}/18'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('umay-tour-next')).hitTestable(),
            findsOneWidget,
          );
          final rect = tester.getRect(
            find.byKey(const ValueKey('umay-tour-bubble')),
          );
          expect(rect.top, greaterThanOrEqualTo(24));
          expect(rect.bottom, lessThanOrEqualTo(616));
          expect(
            tester
                .widget<Transform>(
                  find.byKey(const ValueKey('umay-tour-avatar-motion')),
                )
                .transform
                .getTranslation()
                .y,
            0,
          );
          expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
          if ([0, 3, 5, 7, 9, 17].contains(i)) {
            await _capture(tester, key, 'small-${scale}x-step-${i + 1}');
          }
          await tester.tap(find.byKey(const ValueKey('umay-tour-next')));
          await _ready(tester);
        }
        _unchanged(audit);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
