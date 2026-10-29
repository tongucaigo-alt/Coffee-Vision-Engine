import 'home_action_finder.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'package:atlas_contribution_app/src/privacy_support.dart';
import 'tarot_test.dart' show catalog, fixture;

void main() {
  late Directory temp;
  late MemoryStore source;
  late TarotStore tarot;
  late TarotRuntime runtime;
  var calls = 0;
  setUpAll(() async {
    for (final entry in {
      'Literata': 'assets/brand/Literata.ttf',
      'EB Garamond': 'assets/brand/EBGaramond.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('atlas-home-v87-');
    source = MemoryStore(Directory('${temp.path}/coffee'), null);
    tarot = TarotStore(Directory('${temp.path}/tarot'));
    await tarot.initialize();
    calls = 0;
    runtime = TarotRuntime(
      store: tarot,
      catalog: catalog(),
      promptVersion: 'test',
      promptHash: 'test',
      generateReading: (_, _) async {
        calls++;
        throw StateError('No AI calls allowed');
      },
    );
  });
  tearDown(() async {
    runtime.dispose();
    await temp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> mainTab(WidgetTester tester, String label) async {
    await tester.runAsync(
      () => tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      ),
    );
    await settle(tester);
  }

  Future<GlobalKey> mount(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: atlasTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ContributionHome(
            modern: true,
            store: source,
            service: PausedService(source),
            onReadFortune: (_) async {},
            tarotPage: TarotHomePage(runtime: runtime),
            tarotHistoryPage: TarotHistoryPage(
              runtime: runtime,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return key;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    const directory = String.fromEnvironment('ATLAS_V87_CAPTURE_DIR');
    if (directory.isEmpty) return;
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand/atlas-logo.png'),
        key.currentContext!,
      );
      await precacheImage(
        const AssetImage('assets/tarot/KART_ARKASI.webp'),
        key.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('same home geometry and usable actions $width/$scale', (
        tester,
      ) async {
        final key = await mount(tester, Size(width, 700), scale);
        final navigation = tester.getRect(find.byType(NavigationBar));
        final header = tester.getRect(find.byType(AppBar));
        final coffeeFrame = tester.getRect(
          find.byKey(const ValueKey('atlas-home-frame')),
        );
        final coffeeArtwork = tester.getSize(
          find.byKey(const ValueKey('atlas-primary-image')),
        );
        final coffeeTitle = tester.getRect(
          find.byKey(const ValueKey('atlas-landing-title')),
        );
        final coffeeTitleStyle = tester
            .widget<Text>(find.byKey(const ValueKey('atlas-landing-title')))
            .style;
        expect(find.text('Gizlilik Politikası'), findsNothing);
        if (scale == 1) {
          expect(coffeeArtwork.width, closeTo((width - 32) * 288 / 873, .01));
          expect(homeAction('Fincanını Tara').hitTestable(), findsOneWidget);
          for (final scrollable in tester.stateList<ScrollableState>(
            find.byType(Scrollable),
          )) {
            expect(scrollable.position.maxScrollExtent, 0);
          }
        } else {
          await tester.ensureVisible(homeAction('Fincanını Tara'));
        }
        await capture(tester, key, 'coffee-${width.toInt()}-${scale.toInt()}x');
        await mainTab(tester, 'Tarot');
        expect(tester.getRect(find.byType(NavigationBar)), navigation);
        expect(tester.getRect(find.byType(AppBar)), header);
        expect(find.byTooltip('Bilgilerim'), findsOneWidget);
        expect(find.text('Tarot Geçmişi'), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('atlas-landing-title')))
              .style,
          coffeeTitleStyle,
        );
        if (scale == 1) {
          expect(
            tester.getSize(find.byKey(const ValueKey('atlas-primary-image'))),
            coffeeArtwork,
          );
          expect(
            tester
                .getRect(find.byKey(const ValueKey('atlas-landing-title')))
                .top,
            closeTo(coffeeTitle.top, .01),
          );
          expect(
            tester.getRect(find.byKey(const ValueKey('tarot-home-frame'))),
            coffeeFrame,
          );
          expect(
            homeAction('Üç Kart · Karıştır').hitTestable(),
            findsOneWidget,
          );
          for (final scrollable in tester.stateList<ScrollableState>(
            find.byType(Scrollable),
          )) {
            expect(scrollable.position.maxScrollExtent, 0);
          }
        } else {
          await tester.ensureVisible(homeAction('Üç Kart · Karıştır'));
        }
        await capture(tester, key, 'tarot-${width.toInt()}-${scale.toInt()}x');
        expect(tester.takeException(), isNull);
        expect(calls, 0);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('record tabs keep selection and open existing Tarot detail', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await File('${tarot.directory.path}/state.json').writeAsString(
        jsonEncode({
          'version': 1,
          'draws': [fixture().toJson()],
          'deletedDailyDays': [],
        }),
      );
    });
    final key = await mount(tester, const Size(412, 800), 1);
    await mainTab(tester, 'Kayıtlarım');
    final tabs = find.byType(SegmentedButton<int>);
    expect(tester.widget<SegmentedButton<int>>(tabs).selected, {0});
    await tester.tap(find.descendant(of: tabs, matching: find.text('Tarot')));
    await settle(tester);
    expect(tester.widget<SegmentedButton<int>>(tabs).selected, {1});
    expect(find.byType(Scaffold), findsOneWidget);
    await capture(tester, key, 'records-tarot');
    await tester.tap(find.text('Devam Et'));
    await settle(tester);
    expect(find.byType(TarotDrawPage), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(tester.widget<SegmentedButton<int>>(tabs).selected, {1});
    await mainTab(tester, 'Kahve');
    await mainTab(tester, 'Kayıtlarım');
    expect(tester.widget<SegmentedButton<int>>(tabs).selected, {1});
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'empty Tarot records have one shell and privacy moves to settings',
    (tester) async {
      final key = await mount(tester, const Size(360, 700), 1);
      await mainTab(tester, 'Kayıtlarım');
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Tarot'),
        ),
      );
      await settle(tester);
      expect(find.text('Burada henüz tarot kaydı yok.'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      await mainTab(tester, 'Ayarlar');
      await tester.ensureVisible(find.text('Gizlilik ve Destek'));
      await capture(tester, key, 'settings');
      for (final label in ['Gizlilik Politikası', 'İçerik Bildir', 'Destek']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        if (label == 'İçerik Bildir') {
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Kapat'));
        } else {
          expect(find.byType(PrivacySupportPage), findsOneWidget);
          expect(find.textContaining('henüz hazırlanıyor'), findsNothing);
          await tester.pageBack();
        }
        await tester.pumpAndSettle();
      }
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('embedded Tarot history preserves unreadable data and retries', (
    tester,
  ) async {
    const invalid = '{"version":2,"draws":[],"deletedDailyDays":[]}';
    final state = File('${tarot.directory.path}/state.json');
    await tester.runAsync(() => state.writeAsString(invalid));
    await mount(tester, const Size(360, 700), 1);
    await mainTab(tester, 'Kayıtlarım');
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text('Tarot'),
      ),
    );
    await settle(tester);
    expect(find.text('Yeniden Oku'), findsOneWidget);
    expect(await tester.runAsync(state.readAsString), invalid);
    await tester.runAsync(
      () =>
          state.writeAsString('{"version":1,"draws":[],"deletedDailyDays":[]}'),
    );
    await tester.runAsync(() => tester.tap(find.text('Yeniden Oku')));
    await settle(tester);
    expect(find.text('Burada henüz tarot kaydı yok.'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
