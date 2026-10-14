import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/coffee_guide_gate.dart';
import 'package:atlas_contribution_app/src/coffee_guide_page.dart';
import 'package:atlas_contribution_app/src/coffee_guide_store.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';

class _ReadOnlyDraftStore extends DraftStore {
  _ReadOnlyDraftStore() : super(Directory('unused-read-only-guide-test'));
  int writes = 0;
  @override
  Future<ContributionDraft?> load() async => null;
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async => [];
  @override
  Future<bool> hasLocalAcceptance() async => false;
  @override
  Future<void> save(ContributionDraft draft) async {
    writes++;
  }

  @override
  Future<void> acceptLocalUse() async {
    writes++;
  }
}

class _MemoryGuide extends CoffeeGuideStore {
  _MemoryGuide([this.state = const CoffeeGuideState()])
    : super(Directory('unused'));
  CoffeeGuideState state;
  final writes = <CoffeeGuideState>[];
  bool fail = false, failRead = false;
  @override
  Future<CoffeeGuideState> read() async {
    if (failRead) throw const FileSystemException('read');
    return state;
  }

  @override
  Future<void> save(CoffeeGuideState next) async {
    if (fail) throw const FileSystemException('write');
    writes.add(next);
    state = next;
  }
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('guide-next')));
  await tester.pump();
}

Future<void> _last(WidgetTester tester) async {
  for (var i = 0; i < 7; i++) {
    await _next(tester);
  }
}

Widget _app(
  Widget home, {
  double scale = 1,
  bool reduced = true,
  GlobalKey? capture,
}) => MaterialApp(
  theme: atlasTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
      padding: const EdgeInsets.only(top: 32, bottom: 24),
    ),
    child: child!,
  ),
  home: capture == null ? home : RepaintBoundary(key: capture, child: home),
);

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    for (final family in ['Literata', 'PlusJakartaSans']) {
      await (FontLoader(
        family == 'PlusJakartaSans' ? 'Plus Jakarta Sans' : family,
      )..addFont(rootBundle.load('assets/brand/$family.ttf'))).load();
    }
  });

  testWidgets(
    'first launch is mandatory, back changes only card, never creates app data',
    (tester) async {
      final store = _MemoryGuide();
      final gate = CoffeeGuideGate(
        store: store,
        child: const Scaffold(body: Text('Existing home')),
      );
      await tester.pumpWidget(_app(gate));
      await tester.pumpAndSettle();
      expect(store.state.shownCount, 1);
      expect(find.text('Existing home'), findsNothing);
      expect(find.text('Bir daha gösterme'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
      await _next(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
      await _last(tester);
      expect(find.text('Bir daha gösterme'), findsNothing);
      await _next(tester);
      await tester.pumpAndSettle();
      expect(find.text('Existing home'), findsOneWidget);
      expect(store.state.dontShowAgain, false);
    },
  );

  testWidgets(
    'second launch checkbox persists only at final button; settings does not modify it',
    (tester) async {
      final store = _MemoryGuide(const CoffeeGuideState(shownCount: 1));
      await tester.pumpWidget(
        _app(
          CoffeeGuideGate(
            store: store,
            child: const Scaffold(body: Text('Existing home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _last(tester);
      expect(find.text('Bir daha gösterme'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('guide-dont-show-again')));
      await tester.pump();
      expect(store.state.dontShowAgain, false);
      await _next(tester);
      await tester.pumpAndSettle();
      expect(store.state.dontShowAgain, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(
          CoffeeGuideGate(
            store: store,
            child: const Scaffold(body: Text('Existing home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CoffeeGuidePage), findsNothing);
      final writes = store.writes.length;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Kullanım Rehberi'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (route) => CoffeeGuidePage(
                      allowClose: true,
                      onClose: () => Navigator.pop(route),
                      onComplete: (_) async => Navigator.pop(route),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Kullanım Rehberi'));
      await tester.pumpAndSettle();
      await _last(tester);
      expect(find.text('Bir daha gösterme'), findsNothing);
      await tester.tap(find.byTooltip('Rehberi kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Kullanım Rehberi'), findsOneWidget);
      expect(store.writes.length, writes);
    },
  );

  testWidgets(
    'interrupted second tour loses checkbox, unchecked tour repeats; resume/rebuild is not another launch',
    (tester) async {
      final store = _MemoryGuide(const CoffeeGuideState(shownCount: 1));
      final gate = CoffeeGuideGate(
        store: store,
        child: const Scaffold(body: Text('Existing home')),
      );
      await tester.pumpWidget(_app(gate));
      await tester.pumpAndSettle();
      expect(store.writes.length, 1);
      await _last(tester);
      await tester.tap(find.byKey(const ValueKey('guide-dont-show-again')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(_app(gate, scale: 1.2));
      await tester.pump();
      expect(store.writes.length, 1);
      expect(find.text('Devam et'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(
          CoffeeGuideGate(
            store: store,
            child: const Scaffold(body: Text('Existing home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
      await _last(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      await _next(tester);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(
          CoffeeGuideGate(
            store: store,
            child: const Scaffold(body: Text('Existing home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
    },
  );

  testWidgets(
    'read/write errors show guide then allow entry with an explicit notice',
    (tester) async {
      final store = _MemoryGuide()
        ..fail = true
        ..failRead = true;
      await tester.pumpWidget(
        _app(
          CoffeeGuideGate(
            store: store,
            child: const Scaffold(body: Text('Existing home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _last(tester);
      await _next(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text('Existing home'), findsOneWidget);
      expect(
        find.textContaining('Rehber tercihi kaydedilemedi'),
        findsOneWidget,
      );
      expect(store.state.dontShowAgain, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'animation plays once, replay restarts it, reduced motion stops it',
    (tester) async {
      await tester.pumpWidget(
        _app(CoffeeGuidePage(onComplete: (_) async {}), reduced: false),
      );
      for (var i = 0; i < 3; i++) {
        await _next(tester);
      }
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('guide-replay')));
      await tester.tap(find.byKey(const ValueKey('guide-replay')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(
        _app(CoffeeGuidePage(onComplete: (_) async {}), reduced: true),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byKey(const ValueKey('guide-replay')), findsNothing);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('eight cards fit width=$width text=$scale with safe areas', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            CoffeeGuidePage(allowSuppression: true, onComplete: (_) async {}),
            scale: scale,
          ),
        );
        for (var card = 0; card < 8; card++) {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'card ${card + 1}');
          final button = tester.getRect(
            find.byKey(const ValueKey('guide-next')),
          );
          expect(button.height, greaterThanOrEqualTo(48));
          expect(
            button.bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height - 24),
          );
          expect(button.width, greaterThanOrEqualTo(48));
          await tester.drag(
            find.byKey(const ValueKey('coffee-guide-scroll')),
            const Offset(0, -2000),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (card < 7) await _next(tester);
        }
      });
    }
  }

  testWidgets(
    'actual settings callback opens guide and preserves the settings destination',
    (tester) async {
      final store = _ReadOnlyDraftStore();
      var opened = 0;
      await tester.pumpWidget(
        _app(
          ContributionHome(
            modern: true,
            store: store,
            service: OfflineContributionService(store),
            onOpenGuide: () async {
              opened++;
            },
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kullanım Rehberi'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.text('Sana ait, senin kontrolünde.'), findsOneWidget);
      expect(await tester.runAsync(() => store.hasLocalAcceptance()), false);
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'modern app guide and real settings route leave coffee data and consent untouched',
    (tester) async {
      final store = _ReadOnlyDraftStore();
      final guide = _MemoryGuide();
      await tester.pumpWidget(
        OfflineContributionApp(store: store, guideStore: guide),
      );
      await tester.pumpAndSettle();
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
      expect(store.writes, 0);
      await _last(tester);
      await _next(tester);
      await tester.pumpAndSettle();
      expect(find.text('Fincanını Tara'), findsOneWidget);
      expect(store.writes, 0);
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      final count = guide.writes.length;
      await tester.tap(find.text('Kullanım Rehberi'));
      await tester.pumpAndSettle();
      expect(find.text('Atlas’a hoş geldin'), findsOneWidget);
      await tester.tap(find.byTooltip('Rehberi kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Sana ait, senin kontrolünde.'), findsOneWidget);
      expect(guide.writes.length, count);
      expect(store.writes, 0);
      expect(await store.hasLocalAcceptance(), false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('render actual guide cards for visual inspection', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('ATLAS_GUIDE_CAPTURE')) return;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        CoffeeGuidePage(allowSuppression: true, onComplete: (_) async {}),
        capture: key,
      ),
    );
    for (var card = 0; card < 8; card++) {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/guide/example-cup.png'),
          key.currentContext!,
        );
        await precacheImage(
          const AssetImage('assets/brand/atlas-logo.png'),
          key.currentContext!,
        );
      });
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/guide-previews');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/card-${card + 1}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      if (card < 7) await _next(tester);
    }
    expect(tester.takeException(), isNull);
  });
}
