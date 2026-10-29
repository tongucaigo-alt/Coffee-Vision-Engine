import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_home_hints.dart';
import 'package:atlas_contribution_app/src/atlas_landing_layout.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'home_action_finder.dart';

class _Preferences extends AtlasHomeHintPreferences {
  Completer<void>? wait;
  @override
  Future<void> load() async {
    await wait?.future;
    await super.load();
  }
}

class _FailingPreferences extends AtlasHomeHintPreferences {
  @override
  Future<bool> setAutomaticEnabled(bool enabled) async {
    await super.setAutomaticEnabled(enabled);
    return false;
  }
}

void main() {
  testWidgets('six visible seconds consume only this session', (t) async {
    final preferences = _Preferences();
    final controller = AtlasHomeHintController(preferences, 'coffee');
    await controller.initialize();
    controller.setActive(true);
    expect(controller.visible(false), isTrue);
    await t.pump(const Duration(milliseconds: 5999));
    expect(preferences.completed('coffee'), isFalse);
    await t.pump(const Duration(milliseconds: 1));
    expect(preferences.completed('coffee'), isTrue);
    expect(controller.visible(true), isFalse);
    controller.setActive(false);
    controller.setActive(true);
    expect(controller.visible(true), isFalse);
    controller.dispose();
    final revisit = AtlasHomeHintController(preferences, 'coffee');
    await revisit.initialize();
    revisit.setActive(true);
    expect(revisit.visible(true), isFalse);
    revisit.dispose();
    final newSession = AtlasHomeHintController(_Preferences(), 'coffee');
    await newSession.initialize();
    newSession.setActive(true);
    expect(newSession.visible(true), isTrue);
    newSession.dispose();
  });

  testWidgets('coffee and Tarot complete independently', (t) async {
    final prefs = _Preferences();
    final coffee = AtlasHomeHintController(prefs, 'coffee');
    final tarot = AtlasHomeHintController(prefs, 'tarot');
    await coffee.initialize();
    await tarot.initialize();
    coffee.setActive(true);
    await t.pump(const Duration(seconds: 6));
    expect(prefs.completed('coffee'), isTrue);
    expect(prefs.completed('tarot'), isFalse);
    tarot.setActive(true);
    expect(tarot.visible(false), isTrue);
    await t.pump(const Duration(seconds: 6));
    expect(prefs.completed('tarot'), isTrue);
    coffee.dispose();
    tarot.dispose();
  });

  testWidgets('incomplete automatic or manual visit is retried in full', (
    t,
  ) async {
    final prefs = _Preferences();
    final c = AtlasHomeHintController(prefs, 'coffee');
    await c.initialize();
    c.setActive(true);
    await t.pump(const Duration(seconds: 2));
    c.setActive(false);
    await t.pump(const Duration(seconds: 20));
    expect(prefs.completed('coffee'), isFalse);
    c.setActive(true);
    await t.pump(const Duration(seconds: 5));
    expect(prefs.completed('coffee'), isFalse);
    c.show(true);
    expect(c.visible(false), isFalse);
    await t.pump(const Duration(seconds: 6));
    expect(prefs.completed('coffee'), isFalse);
    c.setActive(false);
    c.setActive(true);
    expect(c.visible(false), isTrue);
    await t.pump(const Duration(seconds: 6));
    expect(prefs.completed('coffee'), isTrue);
    c.dispose();
  });

  testWidgets('late preference load never consumes a hidden page', (t) async {
    final prefs = _Preferences()..wait = Completer<void>();
    final c = AtlasHomeHintController(prefs, 'coffee');
    c.setActive(true);
    final load = c.initialize();
    c.setActive(false);
    prefs.wait!.complete();
    await load;
    await t.pump(const Duration(seconds: 8));
    expect(prefs.completed('coffee'), isFalse);
    c.setActive(true);
    expect(c.visible(true), isTrue);
    c.dispose();
  });

  testWidgets(
    'switch disables automatic hints; manual works; enabling resets both pages',
    (t) async {
      final prefs = _Preferences();
      final c = AtlasHomeHintController(prefs, 'coffee');
      await c.initialize();
      c.setActive(true);
      await prefs.setAutomaticEnabled(false);
      expect(c.visible(true), isFalse);
      c.show(false);
      expect(c.visible(false), isTrue);
      expect(c.visible(true), isFalse);
      await t.pump(const Duration(seconds: 5));
      expect(c.visible(false), isTrue);
      await t.pump(const Duration(seconds: 1));
      expect(c.visible(false), isFalse);
      prefs.complete('coffee');
      prefs.complete('tarot');
      c.setActive(false);
      await prefs.setAutomaticEnabled(true);
      expect(prefs.completed('coffee'), isFalse);
      expect(prefs.completed('tarot'), isFalse);
      c.setActive(true);
      expect(c.visible(true), isTrue);
      c.dispose();
    },
  );

  test(
    'switch persists; old seen flags and business files remain untouched',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'atlas-hints-session-',
      );
      try {
        final business = File('${root.path}/records.json')
          ..writeAsStringSync('retained');
        final dir = Directory('${root.path}/home-action-hints')..createSync();
        for (final page in ['coffee', 'tarot']) {
          File(
            '${dir.path}/$page.json',
          ).writeAsStringSync('{"version":1,"seen":true}');
        }
        final prefs = AtlasHomeHintPreferences(dir);
        await prefs.load();
        expect(prefs.automaticEnabled, isTrue);
        expect(prefs.completed('coffee'), isFalse);
        prefs.complete('coffee');
        expect(await prefs.setAutomaticEnabled(false), isTrue);
        final restarted = AtlasHomeHintPreferences(dir);
        await restarted.load();
        expect(restarted.automaticEnabled, isFalse);
        expect(restarted.completed('coffee'), isFalse);
        expect(await restarted.setAutomaticEnabled(true), isTrue);
        final enabled = AtlasHomeHintPreferences(dir);
        await enabled.load();
        expect(enabled.automaticEnabled, isTrue);
        expect(business.readAsStringSync(), 'retained');
        expect(
          File('${dir.path}/coffee.json').readAsStringSync(),
          '{"version":1,"seen":true}',
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'malformed or missing preference defaults on without deleting anything',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'atlas-hints-malformed-',
      );
      try {
        final file = File('${dir.path}/options.json')
          ..writeAsStringSync('{invalid');
        final prefs = AtlasHomeHintPreferences(dir);
        await prefs.load();
        expect(prefs.automaticEnabled, isTrue);
        expect(file.readAsStringSync(), '{invalid');
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'failed save keeps session choice and latest rapid toggle wins on disk',
    () async {
      final dir = await Directory.systemTemp.createTemp('atlas-hints-save-');
      try {
        final blocker = File('${dir.path}/blocked')
          ..writeAsStringSync('retained');
        final broken = AtlasHomeHintPreferences(Directory(blocker.path));
        await broken.load();
        expect(await broken.setAutomaticEnabled(false), isFalse);
        expect(broken.automaticEnabled, isFalse);
        expect(blocker.readAsStringSync(), 'retained');
        final prefs = AtlasHomeHintPreferences(Directory('${dir.path}/ok'));
        await prefs.load();
        await Future.wait([
          prefs.setAutomaticEnabled(false),
          prefs.setAutomaticEnabled(true),
        ]);
        final restarted = AtlasHomeHintPreferences(prefs.directory);
        await restarted.load();
        expect(restarted.automaticEnabled, isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets('settings switch reports failure without blocking interaction', (
    t,
  ) async {
    final prefs = _FailingPreferences();
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            AtlasHomeHintScope(preferences: prefs, child: child!),
        home: const Scaffold(body: AtlasHomeHintSettings()),
      ),
    );
    await t.pump();
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    expect(prefs.automaticEnabled, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    expect(prefs.automaticEnabled, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  Widget landing({
    required VoidCallback onTap,
    bool ready = true,
    bool reduced = false,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: AtlasLandingLayout(
        hintsEnabled: ready,
        frame: const SizedBox(),
        content: const AtlasLandingContent(
          kicker: Text('3 AÇILI ÇEKİM'),
          title: 'Fincanını Keşfet',
          description: 'Hikâyene bir fincanla başla',
        ),
        secondary: AtlasLandingImageButton(
          asset: 'atlas_gallery_button.webp',
          label: 'Galeriden Seç',
          onPressed: onTap,
        ),
        primary: AtlasLandingImageButton(
          asset: 'atlas_camera_button.webp',
          label: 'Fincanını Tara',
          primary: true,
          onPressed: onTap,
        ),
      ),
    ),
  );

  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
  }

  double opacity(WidgetTester t, String key) =>
      t.widget<AnimatedOpacity>(find.byKey(ValueKey(key))).opacity;

  testWidgets(
    'long press shows only its name; tap still acts and semantics stay named',
    (t) async {
      final semantics = t.ensureSemantics();
      final preferences = _Preferences()..complete('coffee');
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          builder: (_, child) =>
              AtlasHomeHintScope(preferences: preferences, child: child!),
          home: landing(onTap: () => taps++),
        ),
      );
      await flush(t);
      final primary = t.getRect(
        find.byKey(const ValueKey('atlas-primary-image')),
      );
      final secondary = t.getRect(
        find.byKey(const ValueKey('atlas-secondary-image')),
      );
      expect(opacity(t, 'atlas-primary-hint'), 0);
      expect(find.bySemanticsLabel('Galeriden Seç'), findsOneWidget);
      await t.longPress(homeAction('Galeriden Seç'));
      await flush(t);
      expect(taps, 0);
      expect(opacity(t, 'atlas-secondary-hint'), 1);
      expect(opacity(t, 'atlas-primary-hint'), 0);
      expect(find.bySemanticsLabel('Galeriden Seç'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      await t.pump(const Duration(milliseconds: 400));
      expect(opacity(t, 'atlas-secondary-hint'), 0);
      expect(
        t.getRect(find.byKey(const ValueKey('atlas-primary-image'))),
        primary,
      );
      expect(
        t.getRect(find.byKey(const ValueKey('atlas-secondary-image'))),
        secondary,
      );
      await t.tap(homeAction('Galeriden Seç'));
      expect(taps, 1);
      await t.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  for (final condition in ['route', 'background', 'ticker', 'not-ready']) {
    testWidgets(
      'hidden or unavailable page does not consume hints: $condition',
      (t) async {
        final preferences = _Preferences();
        final available = ValueNotifier(true);
        final nav = GlobalKey<NavigatorState>();
        await t.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            theme: atlasTheme(),
            builder: (_, child) =>
                AtlasHomeHintScope(preferences: preferences, child: child!),
            home: ValueListenableBuilder(
              valueListenable: available,
              builder: (_, value, _) => TickerMode(
                enabled: condition == 'ticker' ? value : true,
                child: landing(
                  onTap: () {},
                  ready: condition == 'not-ready' ? value : true,
                ),
              ),
            ),
          ),
        );
        await flush(t);
        await t.pump(const Duration(seconds: 2));
        if (condition == 'route') {
          nav.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covered')),
            ),
          );
        } else if (condition == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        } else {
          available.value = false;
        }
        await flush(t);
        await t.pump(const Duration(seconds: 8));
        expect(preferences.completed('coffee'), isFalse);
        if (condition == 'route') {
          nav.currentState!.pop();
          await t.pumpAndSettle();
        } else if (condition == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        } else {
          available.value = true;
        }
        await flush(t);
        expect(opacity(t, 'atlas-primary-hint'), 1);
        await t.pump(const Duration(seconds: 6));
        expect(preferences.completed('coffee'), isTrue);
        await t.pumpWidget(const SizedBox());
        available.dispose();
      },
    );
  }

  testWidgets('reduced motion hides names without an opacity animation', (
    t,
  ) async {
    final preferences = _Preferences();
    await t.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        builder: (_, child) =>
            AtlasHomeHintScope(preferences: preferences, child: child!),
        home: landing(onTap: () {}, reduced: true),
      ),
    );
    await flush(t);
    await t.pump(const Duration(seconds: 6));
    final hint = t.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('atlas-primary-hint')),
    );
    expect(hint.opacity, 0);
    expect(hint.duration, Duration.zero);
    await t.pumpWidget(const SizedBox());
  });
}
