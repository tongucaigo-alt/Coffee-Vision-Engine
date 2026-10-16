import 'dart:io';
import 'dart:ui' as ui;

import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/user_profile_page.dart';
import 'package:atlas_contribution_app/src/user_profile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contribution_save_status_test.dart' show MemoryStore, PausedService;

class _ProfileStore extends UserProfileStore {
  _ProfileStore() : super(Directory('unused-profile-widget'));
  UserProfile profile = const UserProfile();
  int saves = 0, deletes = 0;
  bool failRead = false, failSave = false, failDelete = false;
  @override
  Future<UserProfile> read() async {
    if (failRead) throw const FormatException('read');
    return profile;
  }

  @override
  Future<void> save(UserProfile value) async {
    if (failSave) throw const FileSystemException('write');
    saves++;
    profile = value;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw const FileSystemException('delete');
    deletes++;
    profile = const UserProfile();
  }
}

Widget _app(Widget home, {double scale = 1, GlobalKey? capture}) => MaterialApp(
  theme: atlasTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      padding: const EdgeInsets.only(top: 24, bottom: 24),
    ),
    child: child!,
  ),
  home: capture == null ? home : RepaintBoundary(key: capture, child: home),
);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets('save, reopen, edit, unspecified sign and delete require no AI', (
    tester,
  ) async {
    final store = _ProfileStore();
    Future<void> mount() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(UserProfilePage(store: store)));
      await tester.pumpAndSettle();
    }

    await mount();
    await _tap(tester, 'Kaydet');
    expect(store.saves, 1);
    expect(store.profile.addressName, isEmpty);
    await tester.enterText(find.byType(TextField), 'Deniz');
    await _tap(tester, 'Burç (isteğe bağlı)');
    await tester.scrollUntilVisible(
      find.text('Terazi'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await _tap(tester, 'Terazi');
    await _tap(tester, 'Kaydet');
    await mount();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Deniz',
    );
    expect(find.text('Terazi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ece');
    await _tap(tester, 'Burç (isteğe bağlı)');
    await _tap(tester, 'Bilmiyorum / Belirtmek istemiyorum');
    await _tap(tester, 'Kaydet');
    expect(store.profile.addressName, 'Ece');
    expect(store.profile.zodiac, isNull);
    expect(store.profile.useZodiacInReading, false);
    await _tap(tester, 'Bilgilerimi sil');
    await _tap(tester, 'Vazgeç');
    expect(store.deletes, 0);
    await _tap(tester, 'Bilgilerimi sil');
    await _tap(tester, 'Sil');
    await mount();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(store.deletes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read and write failures keep user control', (tester) async {
    final store = _ProfileStore()..failRead = true;
    await tester.pumpWidget(_app(UserProfilePage(store: store)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    store.failRead = false;
    await _tap(tester, 'Yeniden dene');
    await tester.enterText(find.byType(TextField), 'Korunan');
    store.failSave = true;
    await _tap(tester, 'Kaydet');
    expect(find.text('Kaydedilemedi. Tekrar deneyebilirsin.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Korunan',
    );
    store.failSave = false;
    await _tap(tester, 'Kaydet');
    store.failDelete = true;
    await _tap(tester, 'Bilgilerimi sil');
    await _tap(tester, 'Sil');
    expect(store.profile.addressName, 'Korunan');
    expect(find.text('Silinemedi. Tekrar deneyebilirsin.'), findsOneWidget);
  });

  testWidgets(
    'saving only name never enables legacy zodiac; explicit reselection does',
    (tester) async {
      final store = _ProfileStore()
        ..profile = const UserProfile(
          addressName: 'Eski ad',
          zodiac: ZodiacSign.libra,
        );
      await tester.pumpWidget(_app(UserProfilePage(store: store)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Yeni ad');
      await _tap(tester, 'Kaydet');
      expect(store.profile.zodiac, ZodiacSign.libra);
      expect(store.profile.useZodiacInReading, false);
      await _tap(tester, 'Burç (isteğe bağlı)');
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Terazi'),
        ),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _tap(tester, 'Terazi');
      await _tap(tester, 'Kaydet');
      expect(store.profile.useZodiacInReading, true);
      await _tap(tester, 'Burç (isteğe bağlı)');
      await _tap(tester, 'Bilmiyorum / Belirtmek istemiyorum');
      await _tap(tester, 'Kaydet');
      expect(store.profile.useZodiacInReading, false);
    },
  );

  testWidgets(
    'existing profile icon opens optional page and back preserves home',
    (tester) async {
      late Directory root;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('atlas-profile-route-');
        await UserProfileStore(
          Directory('${root.path}/user-profile'),
        ).save(const UserProfile(addressName: 'Deniz'));
      });
      addTearDown(() => root.delete(recursive: true));
      final drafts = MemoryStore(Directory('${root.path}/contributions'), null)
        ..accepted = true;
      var aiCalls = 0;
      await tester.pumpWidget(
        _app(
          ContributionHome(
            store: drafts,
            service: PausedService(drafts),
            modern: true,
            onGenerateFortune: (_) async {
              aiCalls++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fincanını Tara'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Bilgilerim'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Deniz',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Fincanını Tara'), findsOneWidget);
      expect(drafts.draft, isNull);
      expect(aiCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small screen, keyboard, large text and all zodiac choices fit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(UserProfilePage(store: _ProfileStore()), scale: 2),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await _tap(tester, 'Kaydet');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await _tap(tester, 'Burç (isteğe bağlı)');
    await tester.scrollUntilVisible(
      find.text('Balık'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await _tap(tester, 'Balık');
    await _tap(tester, 'Kaydet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('render actual profile for visual inspection', (tester) async {
    if (!const bool.fromEnvironment('ATLAS_PROFILE_CAPTURE')) return;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(UserProfilePage(store: _ProfileStore()), capture: key),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory(
        'build/profile-previews',
      ).create(recursive: true);
      await File(
        '${directory.path}/profile.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
