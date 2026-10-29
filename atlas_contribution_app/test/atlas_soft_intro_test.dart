import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_intro.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'atlas_intro_test.dart' show Media, Prefs, Audio;
import 'contribution_save_status_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'startup stays dark on entry and preserves the parchment exit fade',
    (t) async {
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: Media(),
        audio: Audio(false),
      );
      await t.pumpWidget(
        OfflineStartupApp(
          store: MemoryStore(Directory('unused-soft-start'), null),
          aiEnabled: false,
          introController: flow,
          createTarot: (_, _) async =>
              throw StateError('Fixture has no Tarot runtime'),
        ),
      );
      await t.pump();
      expect(
        t.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        atlasIntroBackground,
      );
      flow.finish();
      await t.pump();
      expect(
        t.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        atlasCream,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  test('Android light/night startup themes share the video edge color', () {
    final colors = File(
      'android/app/src/main/res/values/launch_colors.xml',
    ).readAsStringSync();
    expect(colors, contains('>#201611</color>'));
    for (final folder in [
      'values',
      'values-night',
      'values-v31',
      'values-night-v31',
    ]) {
      final styles = File(
        'android/app/src/main/res/$folder/styles.xml',
      ).readAsStringSync();
      expect(styles, contains('@color/atlas_launch_background'));
      expect(
        styles,
        contains(
          '<item name="android:statusBarColor">@color/atlas_launch_background</item>',
        ),
      );
      expect(
        styles,
        contains(
          '<item name="android:navigationBarColor">@color/atlas_launch_background</item>',
        ),
      );
      expect(
        styles,
        contains('<item name="android:windowLightStatusBar">false</item>'),
      );
      expect(
        styles,
        contains('<item name="android:windowLightNavigationBar">false</item>'),
      );
      if (folder.endsWith('v31')) {
        expect(
          styles,
          contains(
            '<item name="android:windowSplashScreenBackground">@color/atlas_launch_background</item>',
          ),
        );
        expect(styles, contains('@drawable/launch_empty_icon'));
      }
    }
  });

  testWidgets(
    'asset decoding and first raster gate the reveal, not video duration',
    (t) async {
      final bundle = _DelayedBundle();
      final poster = AssetImage(
        'assets/intro/atlas-welcome-first.jpg',
        bundle: bundle,
      );
      final raster = Completer<void>();
      final media = Media();
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: media,
        audio: Audio(),
      );
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AtlasIntroView(
              key: key,
              controller: flow,
              poster: poster,
              waitForFirstFrame: () => raster.future,
            ),
          ),
        ),
      );
      double opacity() => t
          .widget<Opacity>(find.byKey(const ValueKey('atlas-intro-reveal')))
          .opacity;
      await t.pump(const Duration(milliseconds: 800));
      expect(opacity(), 0);
      expect(media.plays, 0);
      bundle.ready.complete();
      await t.runAsync(() => precacheImage(poster, key.currentContext!));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(opacity(), 0);
      expect(media.plays, 0);
      raster.complete();
      for (var i = 0; i < 5; i++) {
        await t.pump();
      }
      expect(media.plays, 1); // No extra one-second wait before playback.
      await t.pump(const Duration(milliseconds: 500));
      expect(opacity(), closeTo(.5, .02));
      await t.pump(const Duration(milliseconds: 500));
      expect(opacity(), 1);
      flow.finish(immediate: true);
      await t.pumpWidget(const SizedBox());
      flow.dispose();
    },
  );

  for (final size in [
    const Size(360, 700),
    const Size(412, 700),
    const Size(412, 892),
    const Size(700, 360),
  ]) {
    testWidgets('real intro composition and 1000ms reveal $size', (t) async {
      const output = String.fromEnvironment('ATLAS_SOFT_INTRO_OUT');
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final media = Media()..wait = Completer<void>();
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: media,
        audio: Audio(false),
      );
      final boundary = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: atlasIntroBackground,
            body: RepaintBoundary(
              key: boundary,
              child: AtlasIntroView(
                controller: flow,
                waitForFirstFrame: () async {},
              ),
            ),
          ),
        ),
      );
      await t.runAsync(
        () => precacheImage(
          const AssetImage('assets/intro/atlas-welcome-first.jpg'),
          boundary.currentContext!,
        ),
      );
      for (var i = 0; i < 5; i++) {
        await t.pump();
      }
      var elapsed = 0;
      for (final stamp in [0, 100, 250, 500, 1000]) {
        await t.pump(Duration(milliseconds: stamp - elapsed));
        elapsed = stamp;
        final opacity = t
            .widget<Opacity>(find.byKey(const ValueKey('atlas-intro-reveal')))
            .opacity;
        if (stamp == 0) expect(opacity, 0);
        if (stamp == 500) expect(opacity, closeTo(.5, .02));
        if (stamp == 1000) expect(opacity, 1);
        await t.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          if (stamp == 0) {
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            expect(data!.buffer.asUint8List(0, 4), [32, 22, 17, 255]);
          }
          if (output.isNotEmpty) {
            final file = File(
              '$output/intro-${size.width.toInt()}x${size.height.toInt()}-${stamp}ms.png',
            );
            await file.parent.create(recursive: true);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await file.writeAsBytes(png!.buffer.asUint8List());
          }
          image.dispose();
        });
      }
      expect(media.plays, 0);
      expect(t.takeException(), isNull);
      flow.finish(immediate: true);
      await t.pumpWidget(const SizedBox());
      flow.dispose();
      media.wait!.complete();
      await t.pump();
    });
  }
}

class _DelayedBundle extends CachingAssetBundle {
  final ready = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('atlas-welcome-first.jpg')) await ready.future;
    return rootBundle.load(key);
  }
}
