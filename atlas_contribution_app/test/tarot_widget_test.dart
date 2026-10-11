import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'tarot_test.dart' show fixture, catalog;

const sampleReading =
    'Geçmiş\nDeli kartının düz temaları, başlangıçlara merakla bakmayı çağrıştırıyor. Daha önce atılmış adımların ne anlama geldiğini düşünmek için bir alan açabilir.\n\nŞimdi\nBüyücü kartının ters yönü, kaynaklarını kullanırken odağı yeniden kurmayı düşündürebilir. Bu, sana ait bir olayın bilgisi değil; kartın temalarından doğan bir çağrışımdır.\n\nOlası Yön\nBaşrahibe kartının düz yönü, iç sesini dinlemeye yönelik bir düşünme daveti sunuyor. Kesin bir gelecek anlatmıyor.\n\nKartların ortak hikâyesi, meraktan odağa ve ardından sakin bir dinlemeye doğru ilerliyor. Bugün hangi küçük adım sana düşünmek için alan açabilir?';

class _CoffeeUiStore extends DraftStore {
  _CoffeeUiStore(super.directory) : super(manualRetention: true);
  @override
  Future<ContributionDraft?> load() async => null;
  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late TarotStore store;
  late TarotRuntime runtime;
  var calls = 0;
  setUpAll(() async {
    final icons = FontLoader("MaterialIcons")
      ..addFont(rootBundle.load("fonts/MaterialIcons-Regular.otf"));
    await icons.load();
    for (final font in {
      'Literata': 'Literata',
      'Plus Jakarta Sans': 'PlusJakartaSans',
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(rootBundle.load('assets/brand/${font.value}.ttf'));
      await loader.load();
    }
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('atlas-tarot-widget-');
    store = TarotStore(Directory('${temp.path}/tarot'));
    await store.initialize();
    calls = 0;
    runtime = TarotRuntime(
      store: store,
      catalog: catalog(),
      promptVersion: 'atlas-tarot-prompt-v1',
      promptHash: 'test-hash',
      generateReading: (draw, token) async {
        calls++;
        return sampleReading;
      },
    );
  });
  tearDown(() async {
    runtime.dispose();
    await temp.delete(recursive: true);
  });

  Future<void> saveDraw(WidgetTester tester, TarotDraw draw) async {
    await tester.runAsync(() async {
      await File('${store.directory.path}/state.json').writeAsString(
        jsonEncode({
          'version': 1,
          'draws': [draw.toJson()],
          'deletedDailyDays': [],
        }),
      );
    });
  }

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<GlobalKey> mount(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool reduced = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: atlasTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
              padding: const EdgeInsets.only(top: 28, bottom: 20),
            ),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    await settleIo(tester);
    return capture;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('ATLAS_UI_CAPTURE')) return;
    await settleIo(tester);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('build/tarot-previews');
      await out.create(recursive: true);
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Atlas exposes four destinations and keeps coffee landing intact',
    (tester) async {
      final source = _CoffeeUiStore(Directory('${temp.path}/coffee'));
      await tester.runAsync(source.initialize);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: OfflineContributionApp(store: source, tarot: runtime),
        ),
      );
      await settleIo(tester);
      expect(find.text('Fincanını Tara'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      await capture(tester, key, '01-coffee-home');
      await tester.runAsync(() => tester.tap(find.text('Tarot')));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('tarot-start-three')), findsOneWidget);
      expect(find.text('Günün Kartı'), findsOneWidget);
      await capture(tester, key, '02-tarot-home');
      await tester.runAsync(() => tester.tap(find.text('Kayıtlarım')));
      await settleIo(tester);
      expect(find.text('Tarot Geçmişi'), findsNothing);
      await tester.runAsync(() => tester.tap(find.text('Ana Sayfa')));
      await settleIo(tester);
      expect(find.text('Fincanını Tara'), findsOneWidget);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'select three exact cards then open in order; generation is explicit',
    (tester) async {
      final full = fixture();
      final initial = TarotDraw(
        id: full.id,
        spread: full.spread,
        createdAt: full.createdAt,
        deck: full.deck,
      );
      await saveDraw(tester, initial);
      final key = await mount(
        tester,
        TarotDrawPage(runtime: runtime, draw: initial),
      );
      await capture(tester, key, '03-card-selection');
      for (final index in [0, 1, 2]) {
        await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('tarot-deck-$index'))),
        );
        await settleIo(tester);
      }
      expect(find.byKey(const ValueKey('tarot-deck')), findsNothing);
      expect(find.byKey(const ValueKey('tarot-generate')), findsNothing);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('tarot-slot-1'))),
      );
      await settleIo(tester);
      expect(find.text('Ters'), findsNothing);
      await capture(tester, key, '04-chosen-cards');
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('tarot-slot-$i'))),
        );
        await settleIo(tester);
      }
      expect(find.byKey(const ValueKey('tarot-generate')), findsOneWidget);
      expect(find.text('Ters'), findsOneWidget);
      expect(calls, 0);
      await capture(tester, key, '05-revealed-cards');
      await tester.ensureVisible(find.byKey(const ValueKey('tarot-generate')));
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('tarot-generate'))),
      );
      await settleIo(tester);
      expect(calls, 1);
      expect(find.byKey(const ValueKey('tarot-reading')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('saved result opens offline without another generation', (
    tester,
  ) async {
    final saved = fixture().copy(
      result: const TarotResult(
        state: TarotResultState.completed,
        text: sampleReading,
        promptVersion: 'atlas-tarot-prompt-v1',
      ),
    );
    await saveDraw(tester, saved);
    final key = await mount(
      tester,
      TarotDrawPage(runtime: runtime, draw: saved),
    );
    if (find.text('Yorumunu Oku').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Yorumunu Oku'));
      await tester.runAsync(() => tester.tap(find.text('Yorumunu Oku')));
      await settleIo(tester);
    }
    expect(find.byKey(const ValueKey('tarot-reading')), findsOneWidget);
    expect(calls, 0);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -440),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, '06-reading-sample');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history shows separate stars and reads without producing', (
    tester,
  ) async {
    await saveDraw(
      tester,
      fixture().copy(
        starred: true,
        result: const TarotResult(
          state: TarotResultState.completed,
          text: sampleReading,
        ),
      ),
    );
    final key = await mount(tester, TarotHistoryPage(runtime: runtime));
    expect(find.text('Yıldızlılar · 1/20'), findsOneWidget);
    await capture(tester, key, '07-tarot-history');
    await tester.runAsync(() => tester.tap(find.text('Yorumunu Oku')));
    await settleIo(tester);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final spread in TarotSpread.values) {
    testWidgets(
      '${spread.name}: small notched screen, double text, reduced motion and semantics',
      (tester) async {
        final full = fixture(spread: spread);
        final draw = TarotDraw(
          id: full.id,
          spread: spread,
          createdAt: full.createdAt,
          deck: full.deck,
          selected: full.selected,
          day: full.day,
        );
        await saveDraw(tester, draw);
        final semantics = tester.ensureSemantics();

        final key = await mount(
          tester,
          TarotDrawPage(runtime: runtime, draw: draw),
          size: const Size(320, 568),
          scale: 2,
          reduced: true,
        );
        for (var i = 0; i < draw.requiredCards; i++) {
          final slot = find.byKey(ValueKey('tarot-slot-$i'));
          await tester.ensureVisible(slot);
          await tester.runAsync(() => tester.tap(slot));
          await settleIo(tester);
        }
        expect(find.byKey(const ValueKey('tarot-generate')), findsOneWidget);
        expect(calls, 0);
        expect(
          find.bySemanticsLabel(
            RegExp(spread == TarotSpread.three ? 'Geçmiş:' : 'Günlük Odak:'),
          ),
          findsOneWidget,
        );
        semantics.dispose();
        await capture(tester, key, '08-${spread.name}-large-text');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('daily history date follows selection day across midnight', (
    tester,
  ) async {
    final daily = fixture(spread: TarotSpread.daily).copy(day: '2026-10-12');
    await saveDraw(tester, daily);
    await mount(tester, TarotHistoryPage(runtime: runtime));
    expect(find.text('Günün Kartı · 12.10.2026'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.text('Devam Et')));
    await settleIo(tester);
    expect(find.text('Günlük odağın · 2026-10-12'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'four navigation destinations fit a small screen at double text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: OfflineContributionApp(
            store: _CoffeeUiStore(Directory('${temp.path}/coffee')),
            tarot: runtime,
          ),
        ),
      );
      await settleIo(tester);
      final nav = tester.getRect(find.byType(NavigationBar));
      final label = tester.getRect(find.text('Kayıtlarım'));
      expect(label.bottom <= nav.bottom, true);
      expect(label.top >= nav.top, true);
      await tester.runAsync(() => tester.tap(find.text('Tarot')));
      await settleIo(tester);
      await capture(tester, key, '10-small-navigation-large-text');
      expect(tester.takeException(), isNull);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('small home and history scroll without overflow at double text', (
    tester,
  ) async {
    var key = await mount(
      tester,
      Scaffold(body: TarotHomePage(runtime: runtime)),
      size: const Size(320, 568),
      scale: 2,
      reduced: true,
    );
    await capture(tester, key, '09-small-home-large-text');
    await tester.drag(
      find.byKey(const ValueKey('tarot-home-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    key = await mount(
      tester,
      TarotHistoryPage(runtime: runtime),
      size: const Size(320, 568),
      scale: 2,
      reduced: true,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
