import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/atlas_intro.dart';
import 'package:atlas_contribution_app/src/coffee_guide_store.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'contribution_save_status_test.dart' show MemoryStore;
import 'atlas_intro_test.dart' show Prefs, Media, Audio;

class Guide extends CoffeeGuideStore {
  Guide() : super(Directory('unused'));
  int reads = 0;
  @override
  Future<CoffeeGuideState> read() async {
    reads++;
    return const CoffeeGuideState(shownCount: 2, dontShowAgain: true);
  }
}

void main() {
  for (final skip in [false, true]) {
    testWidgets(
      'bootstrap completes behind intro, guide starts after exit once: back=$skip',
      (t) async {
        t.view.physicalSize = const Size(412, 850);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('atlas-intro-bootstrap-'),
        );
        final store = MemoryStore(dir!, null),
            guide = Guide(),
            media = Media(),
            prefs = Prefs();
        final flow = AtlasIntroController(
          preferences: prefs,
          media: media,
          audio: Audio(),
        );
        var starts = 0;
        await t.pumpWidget(
          OfflineStartupApp(
            store: store,
            introController: flow,
            guideStore: guide,
            aiEnabled: false,
            createTarot: (_, _) async {
              starts++;
              throw StateError('fixture');
            },
          ),
        );
        for (var i = 0; i < 8; i++) {
          await t.pump();
        }
        expect(starts, 1);
        expect(guide.reads, 0);
        expect(find.byType(ContributionHome), findsNothing);
        expect(media.plays, 1);
        if (skip) {
          await t.binding.handlePopRoute();
          await t.binding.handlePopRoute();
        } else {
          media.advance(8000);
        }
        await t.pump(const Duration(milliseconds: 300));
        for (var i = 0; i < 8; i++) {
          await t.pump();
        }
        expect(find.byType(ContributionHome), findsOneWidget);
        expect(guide.reads, 1);
        expect(prefs.writes, 1);
        expect(starts, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() => dir.delete(recursive: true));
      },
    );
  }
  test(
    'intro preferences persist independently without replacing contribution files',
    () async {
      final root = await Directory.systemTemp.createTemp('atlas-intro-pref-');
      try {
        final original = File('${root.path}/receipts.json');
        await original.writeAsString('existing');
        final prefs = AtlasIntroPreferences(
          Directory('${root.path}/startup-intro'),
        );
        expect(await prefs.readSeen(), isFalse);
        await prefs.markSeen();
        expect(await AtlasIntroPreferences(prefs.directory).readSeen(), isTrue);
        expect(await original.readAsString(), 'existing');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
