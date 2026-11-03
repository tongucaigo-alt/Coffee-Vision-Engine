import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_home_hints.dart';
import 'package:atlas_contribution_app/src/atlas_intro.dart';
import 'package:atlas_contribution_app/src/atlas_intro_transition.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'atlas_intro_test.dart' show Audio, Media, Prefs;
import 'atlas_intro_startup_test.dart' show Guide;
import 'contribution_save_status_test.dart' show MemoryStore;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  Future<void> get waitUntilFirstFrameRasterized => Future<void>.value();
}

Future<void> _flush(WidgetTester t) async {
  final intro = find.byType(AtlasIntroView).evaluate();
  if (intro.isNotEmpty) {
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/intro/atlas-welcome-first.jpg'),
        intro.first,
      ),
    );
  }
  for (var i = 0; i < 8; i++) {
    await t.pump();
  }
}

Future<void> _capture(GlobalKey boundary, String name) async {
  const output = String.fromEnvironment('ATLAS_FAIRY_OUT');
  if (output.isEmpty) return;
  final frame =
      await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
  final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$output/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  frame.dispose();
}

void main() {
  _Binding();
  setUpAll(() async {
    for (final font in {
      'EB Garamond': 'assets/brand/EBGaramond.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'Literata': 'assets/brand/Literata.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('wash finishes on the coffee cup after the face disappears', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    Future<Color> pixel(double progress, int x, int y) async {
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AtlasParchmentDissolve(
            progress: progress,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      );
      return (await t.runAsync(() async {
        final frame =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await frame.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final at = (y * 360 + x) * 4;
        final rgba = bytes!.buffer.asUint8List(at, 4);
        final color = Color.fromARGB(rgba[3], rgba[0], rgba[1], rgba[2]);
        frame.dispose();
        return color;
      }))!;
    }

    expect((await pixel(0, 4, 4)).toARGB32(), Colors.blue.toARGB32());
    expect((await pixel(.55, 4, 4)).toARGB32(), atlasCream.toARGB32());
    expect((await pixel(.55, 284, 368)).toARGB32(), Colors.blue.toARGB32());
    // Portrait source: the cup is near (786, 1146), the face near (873, 999).
    expect((await pixel(.88, 291, 333)).toARGB32(), atlasCream.toARGB32());
    expect(
      (await pixel(.88, 262, 382)).toARGB32(),
      isNot(atlasCream.toARGB32()),
    );
    expect((await pixel(1, 284, 368)).toARGB32(), atlasCream.toARGB32());
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('natural ending uses the last 800ms and has no extra exit wait', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    final media = Media()..duration = const Duration(seconds: 6);
    final prefs = Prefs();
    final flow = AtlasIntroController(
      preferences: prefs,
      media: media,
      audio: Audio(),
    );
    flow.start(reducedMotion: false);
    for (var i = 0; i < 6; i++) {
      await t.pump();
    }
    expect(media.plays, 1);
    media.advance(5199);
    expect(flow.departing, isFalse);
    media.advance(5200);
    expect(flow.departing, isTrue);
    expect(flow.visible, isTrue);
    media.advance(5600);
    await t.pump(const Duration(milliseconds: 25));
    expect(media.gain, closeTo(.1, .001));
    media.advance(5900);
    await t.pump(const Duration(milliseconds: 25));
    expect(media.gain, closeTo(.025, .001));
    media.advance(6000);
    expect(flow.visible, isFalse);
    expect(flow.completedNaturally, isTrue);
    expect(media.gain, 0);
    expect(prefs.writes, 1);
    flow.dispose();
    await t.pumpWidget(const SizedBox());
  });

  for (final exit in ['skip', 'background', 'error']) {
    testWidgets('$exit during the wash keeps the immediate exit behavior', (
      t,
    ) async {
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      final media = Media()..duration = const Duration(seconds: 6);
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: media,
        audio: Audio(),
      );
      flow.start(reducedMotion: false);
      for (var i = 0; i < 6; i++) {
        await t.pump();
      }
      media.advance(5400);
      expect(flow.departing, isTrue);
      switch (exit) {
        case 'skip':
          flow.finish(immediate: true);
        case 'background':
          flow.didChangeAppLifecycleState(AppLifecycleState.paused);
        case 'error':
          media.failed = true;
          media.advance(5500);
          await t.pump(const Duration(milliseconds: 250));
      }
      expect(flow.visible, isFalse);
      expect(flow.completedNaturally, isFalse);
      expect(media.gain, 0);
      flow.dispose();
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('arrival keeps actions and hint time until the page is clear', (
    t,
  ) async {
    final prefs = AtlasHomeHintPreferences();
    final hints = AtlasHomeHintController(prefs, 'coffee');
    await hints.initialize();
    var taps = 0;
    await t.pumpWidget(
      const MediaQuery(data: MediaQueryData(), child: SizedBox()),
    );
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: AtlasIntroArrival(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final active = AtlasIntroArrival.isRevealedOf(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  hints.setActive(active);
                });
                return TextButton(
                  onPressed: () => taps++,
                  child: const Text('Continue'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(hints.visible(true), isFalse);
    await t.tap(find.text('Continue'), warnIfMissed: false);
    expect(taps, 0);
    await t.pump(const Duration(milliseconds: 200));
    await _flush(t);
    expect(
      t
          .widget<Opacity>(find.byKey(const ValueKey('atlas-home-arrival')))
          .opacity,
      1,
    );
    // Status completion is delivered on the next vsync after the 200ms value.
    await t.pump(const Duration(milliseconds: 16));
    await _flush(t);
    expect(hints.visible(true), isTrue);
    await t.tap(find.text('Continue'));
    expect(taps, 1);
    await t.pump(const Duration(milliseconds: 5999));
    expect(prefs.completed('coffee'), isFalse);
    await t.pump(const Duration(milliseconds: 1));
    expect(prefs.completed('coffee'), isTrue);
    await t.pumpWidget(const SizedBox());
    hints.dispose();
    prefs.dispose();
  });

  testWidgets('reduced-motion arrival is already visible', (t) async {
    await t.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: AtlasIntroArrival(child: SizedBox.expand()),
      ),
    );
    expect(
      t
          .widget<Opacity>(find.byKey(const ValueKey('atlas-home-arrival')))
          .opacity,
      1,
    );
    await t.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(360, 700),
    const Size(412, 700),
    const Size(412, 892),
    const Size(700, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('real startup wash and home $size, text $scale', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final media = Media()..duration = const Duration(seconds: 6);
        final flow = AtlasIntroController(
          preferences: Prefs(),
          media: media,
          audio: Audio(false),
        );
        final guide = Guide();
        final key = GlobalKey();
        final name =
            '${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x';
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: OfflineStartupApp(
                store: MemoryStore(Directory('unused-wash-$name'), null),
                introController: flow,
                guideStore: guide,
                aiEnabled: false,
                createTarot: (_, _) async => throw StateError('Fixture'),
              ),
            ),
          ),
        );
        await _flush(t);
        await t.pump(const Duration(seconds: 1));
        expect(guide.reads, 0);
        media.advance(5200);
        await t.pump();
        media.advance(5600);
        await t.pump(const Duration(milliseconds: 400));
        await t.runAsync(() => _capture(key, '$name-wash-half'));
        expect(guide.reads, 0);
        media.advance(5920);
        await t.pump(const Duration(milliseconds: 320));
        await t.runAsync(() => _capture(key, '$name-wash-late'));
        media.advance(6000);
        await _flush(t);
        await t.pump(const Duration(milliseconds: 216));
        await _flush(t);
        expect(find.byType(ContributionHome), findsOneWidget);
        expect(guide.reads, 1);
        final hints = t
            .widget<AtlasHomeHintBinding>(
              find.byType(AtlasHomeHintBinding).first,
            )
            .notifier!;
        expect(hints.visible(true), isTrue);
        expect(
          t
              .widget<Opacity>(find.byKey(const ValueKey('atlas-home-arrival')))
              .opacity,
          1,
        );
        await t.runAsync(() => _capture(key, '$name-home'));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'export actual Flutter transition using original moving frames',
    (t) async {
      final framesPath = Platform.environment['ATLAS_FAIRY_FRAMES'];
      if (framesPath == null) return;
      t.view.physicalSize = const Size(412, 892);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final frames = await t.runAsync(() async {
        final files =
            Directory(framesPath).listSync().whereType<File>().toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        return [for (final file in files) await file.readAsBytes()];
      });
      final media = _MovieFrames(frames!)
        ..duration = const Duration(seconds: 6);
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: media,
        audio: Audio(false),
      );
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: OfflineStartupApp(
            store: MemoryStore(Directory('unused-transition-movie'), null),
            introController: flow,
            guideStore: Guide(),
            aiEnabled: false,
            createTarot: (_, _) async => throw StateError('Fixture'),
          ),
        ),
      );
      await _flush(t);
      for (var i = 0; i < 156; i++) {
        final at = math.min(i, frames.length - 1);
        if (i < 144) {
          await t.runAsync(
            () => precacheImage(MemoryImage(frames[at]), key.currentContext!),
          );
        }
        if (i > 0) await t.pump(const Duration(microseconds: 41667));
        if (i <= 144) media.advance((i * 1000 / 24).round());
        await t.pump();
        if (i >= 144) {
          for (var j = 0; j < 4; j++) {
            await t.pump();
          }
        }
        await t.runAsync(
          () => _capture(key, 'movie/${i.toString().padLeft(3, '0')}'),
        );
      }
      expect(find.byType(ContributionHome), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    skip: Platform.environment['ATLAS_FAIRY_FRAMES'] == null,
  );
}

class _MovieFrames extends Media {
  _MovieFrames(this.images);
  final List<Uint8List> images;
  @override
  Widget get view => ListenableBuilder(
    listenable: this,
    builder: (context, _) => Image.memory(
      images[math.min(
        (position.inMilliseconds * 24 / 1000).round(),
        images.length - 1,
      )],
      fit: BoxFit.contain,
      gaplessPlayback: true,
    ),
  );
}
