import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_home_hints.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'home_action_finder.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'EB Garamond': 'assets/brand/EBGaramond.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'Literata': 'assets/brand/Literata.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('real settings controls the next home visit, scale $scale', (
      t,
    ) async {
      const output = String.fromEnvironment('ATLAS_HINTS_OUT');
      t.view.physicalSize = const Size(412, 892);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final prefs = AtlasHomeHintPreferences();
      final store = MemoryStore(Directory('unused-polish-settings'), null);
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: atlasTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => AtlasHomeHintScope(
              preferences: prefs,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
            ),
            home: ContributionHome(
              modern: true,
              store: store,
              service: PausedService(store),
            ),
          ),
        ),
      );
      Future<void> flush() async {
        for (var i = 0; i < 5; i++) {
          await t.pump();
        }
      }

      Future<void> nav(String name) async {
        await t.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(name),
          ),
        );
        await flush();
      }

      Future<void> capture(String state) async {
        if (output.isEmpty) return;
        await t.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$output/settings-${scale.toInt()}x-$state.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await flush();
      await t.pump(const Duration(seconds: 6));
      expect(prefs.completed('coffee'), isTrue);
      await nav('Ayarlar');
      expect(find.byType(SwitchListTile), findsOneWidget);
      await t.ensureVisible(find.byType(SwitchListTile));
        await capture('on');
      await t.tap(find.byType(SwitchListTile));
      await flush();
      expect(prefs.automaticEnabled, isFalse);
      await capture('off');
      await nav('Kahve');
      double opacity() => t
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('atlas-primary-hint')),
          )
          .opacity;
      expect(opacity(), 0);
      await t.ensureVisible(homeAction('Fincanını Tara'));
      await t.longPress(homeAction('Fincanını Tara'));
      await flush();
      expect(opacity(), 1);
      expect(find.text('Fincanını Keşfet'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      expect(opacity(), 0);
      await nav('Ayarlar');
      await t.ensureVisible(find.byType(SwitchListTile));
      await t.tap(find.byType(SwitchListTile));
      await flush();
      await nav('Kahve');
      expect(opacity(), 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }
}
