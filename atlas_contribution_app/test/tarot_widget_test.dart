import 'dart:async';
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
import 'coffee_guide_fixture.dart';

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

class _HeldMoodStore extends TarotStore {
  _HeldMoodStore(super.directory);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<TarotDraw> setMood(String id, TarotMood? mood) async {
    started.complete();
    await release.future;
    throw const FileSystemException('Test write failure');
  }
}

class _HeldRevealStore extends TarotStore {
  _HeldRevealStore(super.directory);
  final started = Completer<void>();
  final release = Completer<void>();
  var attempts = 0;
  @override
  Future<TarotDraw> reveal(String id, int position) async {
    attempts++;
    if (attempts == 1) {
      started.complete();
      await release.future;
      throw const FileSystemException('Test reveal write failure');
    }
    return super.reveal(id, position);
  }
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
    // The expected card deliberately keeps pulsing while it waits for a tap.
    // Drain IO and finite transitions without waiting for that loop to settle.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  Future<GlobalKey> mount(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool reduced = false,
    EdgeInsets padding = const EdgeInsets.only(top: 28, bottom: 20),
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
              padding: padding,
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
          child: OfflineContributionApp(
            store: source,
            tarot: runtime,
            guideStore: DismissedGuideStore(),
          ),
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
    await settleIo(tester);
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
            guideStore: DismissedGuideStore(),
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

  testWidgets(
    'formatted reading keeps original persisted text and sends no request',
    (tester) async {
      const raw =
          '# Geçmiş\n\n**Deli** bir başlangıç çağrışımıdır.\n\n**Şimdi: Büyücü**\nOdağını düşün.\n\n*Bugün hangi küçük adım?*';
      final saved = fixture().copy(
        result: const TarotResult(state: TarotResultState.completed, text: raw),
      );
      await saveDraw(tester, saved);
      await mount(tester, TarotDrawPage(runtime: runtime, draw: saved));
      final text = tester.widget<SelectableText>(
        find.byKey(const ValueKey('tarot-reading-text')),
      );
      expect(
        text.textSpan!.toPlainText(),
        'Geçmiş\n\nDeli bir başlangıç çağrışımıdır.\n\nŞimdi: Büyücü\nOdağını düşün.\n\nBugün hangi küçük adım?',
      );
      final restored = await tester.runAsync(() => store.get(saved.id));
      expect(restored!.result.text, raw);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'far swiped card keeps its exact index and history hides unopened fronts',
    (tester) async {
      final full = fixture();
      final initial = TarotDraw(
        id: full.id,
        spread: full.spread,
        createdAt: full.createdAt,
        deck: full.deck,
      );
      await saveDraw(tester, initial);
      final semantics = tester.ensureSemantics();
      await mount(tester, TarotDrawPage(runtime: runtime, draw: initial));
      expect(find.bySemanticsLabel(RegExp('Deli|Büyücü')), findsNothing);
      final deck = find.byKey(const ValueKey('tarot-deck'));
      final card = find.byKey(const ValueKey('tarot-deck-43'));
      await tester.scrollUntilVisible(
        card,
        500,
        scrollable: find.descendant(
          of: deck,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.runAsync(() => tester.tap(card));
      await settleIo(tester);
      final picked = (await tester.runAsync(() => store.get(initial.id)))!;
      expect(picked.selected, [43]);
      expect(picked.chosen.single.toJson(), full.deck[43].toJson());
      await tester.pumpWidget(const SizedBox());
      await mount(tester, TarotHistoryPage(runtime: runtime));
      final thumbnail = tester.widget<TarotCardView>(
        find.byKey(ValueKey('tarot-history-${picked.id}-0')),
      );
      expect(thumbnail.showFront, false);
      expect(find.text(full.deck[43].card.name), findsNothing);
      semantics.dispose();
      expect(calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'design matrix fits small phones, double text and reduced motion',
    (tester) async {
      final saved = fixture().copy(
        result: const TarotResult(
          state: TarotResultState.completed,
          text: sampleReading,
        ),
      );
      await saveDraw(tester, saved);
      final initial = TarotDraw(
        id: saved.id,
        spread: saved.spread,
        createdAt: saved.createdAt,
        deck: saved.deck,
      );
      final closed = initial.copy(selected: [0, 1, 2]);
      for (final size in const [
        Size(320, 568),
        Size(360, 700),
        Size(412, 700),
      ]) {
        for (final scale in [1.0, 2.0]) {
          final pages = <String, Widget>{
            'home': Scaffold(body: TarotHomePage(runtime: runtime)),
            'selection': TarotDrawPage(runtime: runtime, draw: initial),
            'chosen': TarotDrawPage(runtime: runtime, draw: closed),
            'daily': TarotDrawPage(
              runtime: runtime,
              draw: fixture(spread: TarotSpread.daily),
            ),
            'reading': TarotDrawPage(runtime: runtime, draw: saved),
            'history': TarotHistoryPage(runtime: runtime),
          };
          for (final entry in pages.entries) {
            final key = await mount(
              tester,
              entry.value,
              size: size,
              scale: scale,
              reduced: true,
            );
            if (entry.key == 'home') {
              final action = find.byKey(const ValueKey('tarot-start-three'));
              expect(
                tester.getSize(action).width,
                closeTo(
                  scale == 1
                      ? (size.width - 64).clamp(0, 280)
                      : size.width - 64,
                  1,
                ),
              );
              expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            }
            if (entry.key == 'reading') {
              await tester.ensureVisible(
                find.byKey(const ValueKey('tarot-reading')),
              );
              await settleIo(tester);
            }
            if (entry.key == 'chosen' || entry.key == 'daily') {
              for (final mood in TarotMood.values) {
                final target = find.byKey(ValueKey('tarot-mood-${mood.name}'));
                await tester.ensureVisible(target);
                final bounds = tester.getRect(target);
                expect(bounds.width, greaterThanOrEqualTo(48));
                expect(bounds.height, greaterThanOrEqualTo(48));
                expect(bounds.left, greaterThanOrEqualTo(0));
                expect(bounds.right, lessThanOrEqualTo(size.width));
              }
              await tester.ensureVisible(
                find.byKey(const ValueKey('tarot-mood-picker')),
              );
              await settleIo(tester);
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} $size scale $scale',
            );
            await capture(
              tester,
              key,
              'matrix-${entry.key}-${size.width.toInt()}-${scale.toInt()}x',
            );
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
      expect(calls, 0);
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
    await settleIo(tester);
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

  testWidgets('mood toggles, persists on reopen and never generates', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final closed = fixture().copy(revealed: 0);
    await saveDraw(tester, closed);
    final key = await mount(
      tester,
      TarotDrawPage(runtime: runtime, draw: closed),
    );
    Future<void> choose(TarotMood mood) async {
      final target = find.byKey(ValueKey('tarot-mood-${mood.name}'));
      await tester.ensureVisible(target);
      await tester.runAsync(() => tester.tap(target));
      await settleIo(tester);
    }

    await choose(TarotMood.happy);
    expect(
      (await tester.runAsync(() => store.get(closed.id)))!.mood,
      TarotMood.happy,
    );
    await choose(TarotMood.calm);
    expect(
      (await tester.runAsync(() => store.get(closed.id)))!.mood,
      TarotMood.calm,
    );
    await capture(tester, key, '10-mood-selected');
    await choose(TarotMood.calm);
    expect((await tester.runAsync(() => store.get(closed.id)))!.mood, isNull);
    await choose(TarotMood.tired);
    await tester.pumpWidget(const SizedBox());
    final reopened = (await tester.runAsync(() => store.get(closed.id)))!;
    await mount(tester, TarotDrawPage(runtime: runtime, draw: reopened));
    final selected = find
        .ancestor(
          of: find.byKey(const ValueKey('tarot-mood-tired')),
          matching: find.byType(Semantics),
        )
        .first;
    expect(tester.widget<Semantics>(selected).properties.selected, true);
    final moodNode = tester.getSemantics(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tarot-mood-tired')),
            matching: find.byType(MergeSemantics),
          )
          .first,
    );
    final accessibleMood = moodNode.getSemanticsData();
    expect(accessibleMood.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(accessibleMood.flagsCollection.isButton, true);
    expect(accessibleMood.label, 'Yorgun');
    semantics.dispose();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending or failed mood write does not lock card opening', (
    tester,
  ) async {
    final held = _HeldMoodStore(store.directory);
    final closed = fixture().copy(revealed: 0, mood: TarotMood.calm);
    await saveDraw(tester, closed);
    runtime.dispose();
    runtime = TarotRuntime(
      store: held,
      catalog: catalog(),
      promptVersion: 'v1',
      promptHash: 'hash',
      generateReading: (draw, token) async {
        calls++;
        return sampleReading;
      },
    );
    await mount(
      tester,
      TarotDrawPage(runtime: runtime, draw: closed),
      reduced: true,
    );
    final choice = find.byKey(const ValueKey('tarot-mood-happy'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.runAsync(() => held.started.future);
    final card = find.byKey(const ValueKey('tarot-slot-0'));
    await tester.ensureVisible(card);
    await tester.runAsync(() => tester.tap(card));
    await settleIo(tester);
    expect((await tester.runAsync(() => held.get(closed.id)))!.revealed, 1);
    held.release.complete();
    await settleIo(tester);
    expect(
      (await tester.runAsync(() => held.get(closed.id)))!.mood,
      TarotMood.calm,
    );
    expect(
      find.text('Seçimin kaydedilemedi. Kartlarını açmaya devam edebilirsin.'),
      findsOneWidget,
    );
    final second = find.byKey(const ValueKey('tarot-slot-1'));
    await tester.ensureVisible(second);
    await tester.runAsync(() => tester.tap(second));
    await settleIo(tester);
    expect((await tester.runAsync(() => held.get(closed.id)))!.revealed, 2);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home resumes exact latest draw and reading shows local mood', (
    tester,
  ) async {
    final partial = fixture().copy(revealed: 1, mood: TarotMood.unsure);
    await saveDraw(tester, partial);
    final key = await mount(
      tester,
      Scaffold(body: TarotHomePage(runtime: runtime)),
    );
    expect(find.byTooltip('Kaldığın yerden devam et'), findsOneWidget);
    await capture(tester, key, '11-home-resume');
    await tester.runAsync(
      () => tester.tap(find.byKey(const ValueKey('tarot-resume'))),
    );
    await settleIo(tester);
    final actual = (await tester.runAsync(() => store.get(partial.id)))!;
    expect(actual.toJson(), partial.toJson());
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    final complete = partial.copy(
      revealed: 3,
      result: const TarotResult(
        state: TarotResultState.completed,
        text: sampleReading,
      ),
    );
    await saveDraw(tester, complete);
    await mount(tester, TarotDrawPage(runtime: runtime, draw: complete));
    expect(find.text('Ruh hâlin: Kararsız'), findsOneWidget);
    expect(find.byKey(const ValueKey('tarot-mood-picker')), findsNothing);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  Finder guide(int position) =>
      find.byKey(ValueKey('tarot-guidance-active-$position'));

  testWidgets(
    'obvious tap hint targets one card and lets touch reach that card',
    (tester) async {
      final closed = fixture().copy(revealed: 0);
      await saveDraw(tester, closed);
      final key = await mount(
        tester,
        TarotDrawPage(runtime: runtime, draw: closed),
        size: const Size(384, 832),
        padding: const EdgeInsets.only(top: 40, bottom: 48),
      );
      final hint = find.byKey(const ValueKey('tarot-tap-hint-0'));
      expect(hint, findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
      expect(find.text('DOKUN'), findsOneWidget);
      final bounds = tester.getRect(find.byKey(const ValueKey('tarot-slot-0')));
      final hintBounds = tester.getRect(hint);
      expect(hintBounds.width, greaterThanOrEqualTo(56));
      expect(bounds.contains(hintBounds.center), true);
      await capture(tester, key, 'clear-tap-hint');
      // The entire overlay is decorative; tapping the large hand opens the card.
    await tester.runAsync(() => tester.tapAt(hintBounds.center));
      await settleIo(tester);
      expect((await tester.runAsync(() => store.get(closed.id)))!.revealed, 1);
      expect(find.byKey(const ValueKey('tarot-tap-hint-0')), findsNothing);
      expect(find.byKey(const ValueKey('tarot-tap-hint-1')), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  BoxDecoration guidanceDecoration(WidgetTester tester, int position) =>
      tester.widget<DecoratedBox>(guide(position)).decoration as BoxDecoration;

  testWidgets('guidance follows completed flips without writes or haptics', (
    tester,
  ) async {
    final closed = fixture().copy(revealed: 0);
    await saveDraw(tester, closed);
    var haptics = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final key = await mount(
      tester,
      TarotDrawPage(runtime: runtime, draw: closed),
      size: const Size(384, 832),
      padding: const EdgeInsets.only(top: 40, bottom: 48),
    );
    final cardBounds = tester.getRect(
      find.byKey(const ValueKey('tarot-slot-0')),
    );
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .maxScrollExtent;
    expect(guide(0), findsOneWidget);
    expect(guide(1), findsNothing);
    final bytes = await tester.runAsync(
      () => File('${store.directory.path}/state.json').readAsString(),
    );
    final firstColor =
        (guidanceDecoration(tester, 0).border! as Border).top.color;
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      (guidanceDecoration(tester, 0).border! as Border).top.color,
      isNot(firstColor),
    );
    // Out-of-order taps intensify the expected card, never reveal another one.
    await tester.tap(find.byKey(const ValueKey('tarot-slot-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    expect((guidanceDecoration(tester, 0).border! as Border).top.color.a, 1);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('tarot-slot-1')));
    }
    await tester.pump(const Duration(milliseconds: 226));
    expect(
      await tester.runAsync(
        () => File('${store.directory.path}/state.json').readAsString(),
      ),
      bytes,
    );
    await capture(tester, key, 'guidance-0-past');
    for (var i = 0; i < 3; i++) {
      final slot = find.byKey(ValueKey('tarot-slot-$i'));
      await tester.runAsync(() => tester.tap(slot));
      await tester.runAsync(() => store.get(closed.id));
      await tester.pump();
      expect(guide(i), findsNothing);
      if (i < 2) expect(guide(i + 1), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      if (i < 2) expect(guide(i + 1), findsNothing);
      await tester.runAsync(() => tester.tap(slot));
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump();
      if (i < 2) {
        expect(guide(i + 1), findsOneWidget);
        await capture(tester, key, 'guidance-${i + 1}-next');
      }
      expect(
        (await tester.runAsync(() => store.get(closed.id)))!.revealed,
        i + 1,
      );
    }
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'tarot-guidance-active-',
            ),
      ),
      findsNothing,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('tarot-slot-0'))),
      cardBounds,
    );
    // Labels revealed underneath cards may add height; the halo adds none.
    expect(scroll, 0);
    expect(calls, 0);
    expect(haptics, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'guidance waits for selected card arrival then resumes exact draw',
    (tester) async {
      final partial = fixture().copy(selected: [0, 1], revealed: 0);
      await saveDraw(tester, partial);
      await mount(tester, TarotDrawPage(runtime: runtime, draw: partial));
      expect(guide(0), findsNothing);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('tarot-deck-2'))),
      );
      await tester.runAsync(() => store.get(partial.id));
      await tester.pump();
      expect(guide(0), findsNothing);
      await tester.pump(const Duration(milliseconds: 239));
      expect(guide(0), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      expect(guide(0), findsOneWidget);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('tarot-slot-0'))),
      );
      await settleIo(tester);
      final reopened = (await tester.runAsync(() => store.get(partial.id)))!;
      await tester.pumpWidget(const SizedBox());
      await mount(tester, TarotDrawPage(runtime: runtime, draw: reopened));
      expect(guide(0), findsNothing);
      expect(guide(1), findsOneWidget);
      expect(reopened.selected, [0, 1, 2]);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed reveal keeps expected guidance and blocks duplicate writes',
    (tester) async {
      final held = _HeldRevealStore(store.directory);
      final closed = fixture().copy(revealed: 0);
      await saveDraw(tester, closed);
      runtime.dispose();
      runtime = TarotRuntime(
        store: held,
        catalog: catalog(),
        promptVersion: 'v1',
        promptHash: 'hash',
        generateReading: (draw, token) async {
          calls++;
          return sampleReading;
        },
      );
      await mount(tester, TarotDrawPage(runtime: runtime, draw: closed));
      await tester.tap(find.byKey(const ValueKey('tarot-slot-0')));
      await tester.runAsync(() => held.started.future);
      await tester.pump();
      expect(guide(0), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tarot-slot-0')));
      expect(held.attempts, 1);
      held.release.complete();
      await settleIo(tester);
      expect(guide(0), findsOneWidget);
      expect((await tester.runAsync(() => held.get(closed.id)))!.revealed, 0);
      expect(find.textContaining('İşlem tamamlanamadı'), findsOneWidget);
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('tarot-slot-0'))),
      );
      await settleIo(tester);
      expect(guide(1), findsOneWidget);
      expect(held.attempts, 2);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'daily static guidance hides identity and has one accessible action',
    (tester) async {
      final closed = fixture(spread: TarotSpread.daily).copy(revealed: 0);
      await saveDraw(tester, closed);
      final semantics = tester.ensureSemantics();
      final key = await mount(
        tester,
        TarotDrawPage(runtime: runtime, draw: closed),
        reduced: true,
        size: const Size(320, 568),
        scale: 2,
      );
      expect(guide(0), findsOneWidget);
      final decoration = guidanceDecoration(tester, 0);
      expect(decoration.boxShadow, isEmpty);
      expect((decoration.border! as Border).top.color, atlasCopper);
      final node = tester
          .getSemantics(find.byKey(const ValueKey('chosen-0')))
          .getSemanticsData();
      expect(node.label, contains('açmak için dokun'));
      expect(node.label, isNot(contains(closed.chosen.single.card.name)));
      expect(node.hasAction(ui.SemanticsAction.tap), true);
      expect(tester.binding.hasScheduledFrame, false);
      await capture(tester, key, 'guidance-daily-reduced-2x');
      await tester.ensureVisible(find.byKey(const ValueKey('tarot-slot-0')));
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('tarot-slot-0'))),
      );
      await settleIo(tester);
      expect(guide(0), findsNothing);
      expect(calls, 0);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('guidance stops when app is backgrounded or route is covered', (
    tester,
  ) async {
    final closed = fixture().copy(revealed: 0);
    await saveDraw(tester, closed);
    await mount(tester, TarotDrawPage(runtime: runtime, draw: closed));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, true);
    final navigator = Navigator.of(
      tester.element(find.byKey(const ValueKey('tarot-slot-0'))),
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, false);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(guide(0), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, true);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'active guidance preserves geometry across phone and text sizes',
    (tester) async {
      final closed = fixture().copy(revealed: 0);
      await saveDraw(tester, closed);
      for (final size in [
        const Size(320, 568),
        const Size(360, 700),
        const Size(412, 700),
        const Size(384, 832),
      ]) {
        for (final scale in [1.0, 2.0]) {
          final key = await mount(
            tester,
            TarotDrawPage(runtime: runtime, draw: closed),
            size: size,
            scale: scale,
            padding: const EdgeInsets.only(top: 40, bottom: 48),
          );
          final slot = find.byKey(const ValueKey('tarot-slot-0'));
          final bounds = tester.getRect(slot);
          final scroll = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .maxScrollExtent;
          final mood = tester.getRect(
            find.byKey(const ValueKey('tarot-mood-picker')),
          );
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.getRect(slot), bounds);
          expect(
            tester.getRect(find.byKey(const ValueKey('tarot-mood-picker'))),
            mood,
          );
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .maxScrollExtent,
            scroll,
          );
          expect(guide(0), findsOneWidget);
          expect(guide(1), findsNothing);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            'guidance-${size.width.toInt()}-${size.height.toInt()}-${scale}x',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
      expect(calls, 0);
    },
  );

  testWidgets('ready tarot fits A56 without scrolling and keeps mood layout', (
    tester,
  ) async {
    final base = fixture();
    final selected = [
      'Ay',
      'Kupa Dokuzlusu',
      'Değnek Dokuzlusu',
    ].map((name) => base.deck.indexWhere((c) => c.card.name == name)).toList();
    expect(selected.every((index) => index >= 0), true);
    for (final scale in [0.9, 1.0]) {
      final draw = base.copy(selected: selected, mood: TarotMood.tense);
      await saveDraw(tester, draw);
      final key = await mount(
        tester,
        TarotDrawPage(runtime: runtime, draw: draw),
        size: const Size(384, 832),
        scale: scale,
        reduced: true,
        padding: const EdgeInsets.only(top: 40, bottom: 48),
      );
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.maxScrollExtent, 0, reason: 'A56 scale $scale');
      final generate = tester.getRect(
        find.byKey(const ValueKey('tarot-generate')),
      );
      expect(generate.bottom, lessThanOrEqualTo(784));
      final buttons = [
        for (final mood in TarotMood.values)
          tester.getRect(find.byKey(ValueKey('tarot-mood-${mood.name}'))),
      ];
      for (final rect in buttons) {
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.bottom, lessThanOrEqualTo(784));
      }
      expect(buttons[0].top, buttons[1].top);
      expect(buttons[1].top, buttons[2].top);
      expect(buttons[3].top, buttons[4].top);
      expect(buttons[3].top, greaterThan(buttons[0].bottom));
      expect(
        (buttons[3].center.dx + buttons[4].center.dx) / 2,
        closeTo(192, .1),
      );
      final happy = find.byKey(const ValueKey('tarot-mood-happy'));
      final icon = find.descendant(
        of: happy,
        matching: find.byIcon(Icons.sentiment_satisfied_alt_outlined),
      );
      expect(
        tester.getRect(icon).bottom,
        lessThan(tester.getRect(find.text('Mutlu')).top),
      );
      debugPrint(
        'PHONE_METRICS ${jsonEncode({'scale': scale, 'scroll': scroll.maxScrollExtent, 'buttonBottom': tester.getRect(find.byKey(const ValueKey('tarot-generate'))).bottom})}',
      );
      await capture(tester, key, 'phone-ready-${scale}x');
      await tester.pumpWidget(const SizedBox());
    }
    expect(calls, 0);
  });
}
