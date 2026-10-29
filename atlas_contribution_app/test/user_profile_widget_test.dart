import 'home_action_finder.dart';
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
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Deniz');
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
      tester
          .widget<TextField>(find.byKey(const ValueKey('profile-name')))
          .controller!
          .text,
      'Deniz',
    );
    expect(find.text('Terazi'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Ece');
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
      tester
          .widget<TextField>(find.byKey(const ValueKey('profile-name')))
          .controller!
          .text,
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
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Korunan',
    );
    store.failSave = true;
    await _tap(tester, 'Kaydet');
    expect(find.text('Kaydedilemedi. Tekrar deneyebilirsin.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('profile-name')))
          .controller!
          .text,
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
    'age is explicit, optional, validated and cleared on save or delete',
    (tester) async {
      final store = _ProfileStore()..profile = const UserProfile(age: 60);
      await tester.pumpWidget(_app(UserProfilePage(store: store)));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('profile-age'));
      expect(tester.widget<TextField>(field).controller!.text, '60');
      expect(
        find.textContaining('yorum hizmetine gönderilir. Boş bırakabilirsin.'),
        findsOneWidget,
      );
      for (final value in ['17', '121']) {
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await _tap(tester, 'Kaydet');
        expect(find.text('18 ile 120 arasında bir yaş yaz.'), findsOneWidget);
        expect(store.saves, 0);
        expect(store.profile.age, 60);
      }
      await tester.ensureVisible(field);
      await tester.enterText(field, '65');
      await _tap(tester, 'Kaydet');
      expect(store.profile.age, 65);
      await tester.ensureVisible(field);
      await tester.enterText(field, '');
      await _tap(tester, 'Kaydet');
      expect(store.profile.age, isNull);
      await tester.ensureVisible(field);
      await tester.enterText(field, '70');
      await _tap(tester, 'Kaydet');
      await _tap(tester, 'Bilgilerimi sil');
      await _tap(tester, 'Sil');
      expect(store.profile.age, isNull);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

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
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Yeni ad',
      );
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
      expect(homeAction('Fincanını Tara'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Bilgilerim'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('profile-name')))
            .controller!
            .text,
        'Deniz',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(homeAction('Fincanını Tara'), findsOneWidget);
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
    await tester.showKeyboard(find.byKey(const ValueKey('profile-name')));
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
    for (final scale in [1.0, 2.0]) {
      final key = GlobalKey();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(
          UserProfilePage(store: _ProfileStore()),
          capture: key,
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      for (final position in ['top', 'bottom']) {
        if (position == 'bottom') {
          await tester.ensureVisible(find.text('Bilgilerimi sil'));
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          const output = String.fromEnvironment(
            'ATLAS_PROFILE_SCREENSHOT_DIR',
            defaultValue: 'build/profile-previews',
          );
          final directory = await Directory(output).create(recursive: true);
          await File(
            '${directory.path}/profile-${scale.toInt()}-$position.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    }
  });
}
