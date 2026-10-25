import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_intro.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_home_atmosphere.dart';

class Prefs extends AtlasIntroPreferences {
  Prefs({this.seen = false}) : super(Directory('unused'));
  bool seen;
  int writes = 0;
  @override
  Future<bool> readSeen() async => seen;
  @override
  Future<void> markSeen() async {
    seen = true;
    writes++;
  }
}

class Audio extends AtlasIntroAudio {
  Audio([this.allowed = true]);
  final bool allowed;
  @override
  void open() {
    value = allowed;
  }
}

class Media extends AtlasIntroMedia {
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(seconds: 8);
  @override
  bool initialized = false;
  @override
  bool failed = false;
  Completer<void>? wait;
  bool throws = false;
  int plays = 0, pauses = 0;
  void Function()? onPlay;
  double gain = 0;
  String? frames;
  List<Uint8List>? frameBytes;
  @override
  Widget get view => ListenableBuilder(
    key: const ValueKey('fake-intro-video'),
    listenable: this,
    builder: (_, _) => frameBytes != null
        ? Image.memory(
            frameBytes![(position.inMilliseconds / 100).floor().clamp(0, 79)],
            fit: BoxFit.contain,
          )
        : frames == null
        ? Image.asset(
            'assets/intro/atlas-welcome-still.jpg',
            fit: BoxFit.contain,
          )
        : Image.file(
            File(
              '$frames/${(position.inMilliseconds / 100).floor().clamp(0, 79).toString().padLeft(3, '0')}.jpg',
            ),
            fit: BoxFit.contain,
          ),
  );
  @override
  Future<void> initialize() async {
    await wait?.future;
    if (throws) throw StateError('synthetic video failure');
    initialized = true;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    onPlay?.call();
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> volume(double value) async {
    gain = value;
  }

  void advance(int millis) {
    position = Duration(milliseconds: millis);
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    for (final (name, asset) in [
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
  });
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.pump();
    }
  }

  for (final seen in [false, true]) {
    testWidgets(
      'every cold launch plays full video; skip is idempotent: $seen',
      (t) async {
        final media = Media(), prefs = Prefs(seen: seen), audio = Audio();
        final flow = AtlasIntroController(
          preferences: prefs,
          media: media,
          audio: audio,
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AtlasIntroView(controller: flow)),
          ),
        );
        await flush(t);
        expect(media.plays, 1);
        expect(media.position, Duration.zero);
        media.advance(300);
        await t.pump(const Duration(milliseconds: 30));
        expect(media.gain, closeTo(.2, .001));
        audio.value = false;
        expect(media.gain, 0);
        audio.value = true;
        await t.pump(const Duration(milliseconds: 30));
        expect(media.gain, closeTo(.2, .001));
        media.advance(6600);
        await t.pump();
        expect(flow.showAtlas, isTrue);
        flow.start(reducedMotion: false);
        expect(media.plays, 1);
        flow.finish();
        flow.finish();
        await t.pump(const Duration(milliseconds: 300));
        expect(flow.visible, isFalse);
        expect(media.gain, 0);
        expect(prefs.writes, 1);
        await t.pumpWidget(const SizedBox());
        flow.dispose();
      },
    );
  }
  for (final mode in ['silent', 'error', 'timeout', 'reduced', 'background']) {
    testWidgets('safe intro behavior: $mode', (t) async {
      final media = Media(), prefs = Prefs(), audio = Audio(mode != 'silent');
      if (mode == 'timeout') media.wait = Completer<void>();
      if (mode == 'error') media.throws = true;
      final flow = AtlasIntroController(
        preferences: prefs,
        media: media,
        audio: audio,
      );
      if (mode == 'reduced') flow.start(reducedMotion: true);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AtlasIntroView(controller: flow)),
        ),
      );
      await flush(t);
      if (mode == 'silent') {
        media.advance(1000);
        await t.pump(const Duration(milliseconds: 50));
        expect(media.gain, 0);
      } else if (mode == 'background') {
        flow.didChangeAppLifecycleState(AppLifecycleState.paused);
        flow.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(flow.visible, isFalse);
        expect(media.gain, 0);
        expect(media.plays, 1);
      } else if (mode == 'timeout') {
        await t.pump(const Duration(seconds: 2));
        await t.pump(const Duration(milliseconds: 300));
        expect(flow.visible, isFalse);
        expect(prefs.writes, 0);
      } else if (mode == 'error') {
        await t.pump(const Duration(milliseconds: 300));
        expect(flow.visible, isFalse);
        expect(prefs.writes, 0);
      } else {
        expect(media.plays, 0);
        expect(media.gain, 0);
        expect(flow.visible, isFalse);
      }
      if (flow.visible) flow.finish(immediate: true);
      await t.pumpWidget(const SizedBox());
      flow.dispose();
    });
  }
  testWidgets(
    'first frame is mounted before playback and fades without a blank cut',
    (t) async {
      final media = Media()..wait = Completer<void>();
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: media,
        audio: Audio(),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AtlasIntroView(controller: flow)),
        ),
      );
      expect(
        t
            .widget<Opacity>(find.byKey(const ValueKey('atlas-intro-reveal')))
            .opacity,
        0,
      );
      await t.pump(const Duration(milliseconds: 150));
      final reveal = t
          .widget<Opacity>(find.byKey(const ValueKey('atlas-intro-reveal')))
          .opacity;
      expect(reveal, greaterThan(0));
      expect(reveal, lessThan(1));
      expect(media.plays, 0);
      expect(
        t
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('atlas-intro-poster')),
            )
            .opacity,
        1,
      );
      media.onPlay = () {
        expect(
          find.byKey(const ValueKey('fake-intro-video')),
          findsNWidgets(2),
        );
        expect(
          find.byKey(const ValueKey('atlas-intro-poster')),
          findsOneWidget,
        );
      };
      media.wait!.complete();
      await t.pump();
      await flush(t);
      expect(media.plays, 1);
      expect(media.position, Duration.zero);
      expect(flow.playbackFrame, isFalse);
      expect(
        t
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('atlas-intro-poster')),
            )
            .opacity,
        1,
      );
      media.advance(100);
      await t.pump();
      expect(flow.playbackFrame, isTrue);
      expect(
        t
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('atlas-intro-poster')),
            )
            .opacity,
        0,
      );
      await t.pump(const Duration(milliseconds: 450));
      expect(
        t
            .widget<Opacity>(find.byKey(const ValueKey('atlas-intro-reveal')))
            .opacity,
        1,
      );
      flow.finish(immediate: true);
      await t.pumpWidget(const SizedBox());
      flow.dispose();
    },
  );

  for (final size in [
    const Size(360, 700),
    const Size(412, 700),
    const Size(412, 892),
    const Size(320, 480),
    const Size(700, 320),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'intro keeps full image inside screen without visible controls $size/$scale',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final media = Media(),
              flow = AtlasIntroController(
                preferences: Prefs(),
                media: Media(),
                audio: Audio(),
              );
          // Keep this view on the decoded poster; sizing is identical to the player.
          final key = GlobalKey();
          await t.pumpWidget(
            MaterialApp(
              theme: atlasTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: RepaintBoundary(
                    key: key,
                    child: AtlasIntroView(controller: flow),
                  ),
                ),
              ),
            ),
          );
          await flush(t);
          flow.media.seek(const Duration(seconds: 7));
          await t.pump(const Duration(milliseconds: 300));
          final viewport = find.byKey(const ValueKey('atlas-intro-viewport'));
          expect(t.getRect(viewport), Offset.zero & size);
          expect(find.byType(TextButton), findsNothing);
          expect(find.byType(Text), findsNothing);
          final fit = t.widget<FittedBox>(
            find.byKey(const ValueKey('atlas-intro-content')),
          );
          expect(fit.fit, BoxFit.contain);
          final content = t.getRect(
            find.byKey(const ValueKey('atlas-intro-content')),
          );
          final source = t.getRect(
            find
                .descendant(
                  of: find.byKey(const ValueKey('atlas-intro-content')),
                  matching: find.byType(SizedBox),
                )
                .first,
          );
          expect(source.left, greaterThanOrEqualTo(-.01));
          expect(source.top, greaterThanOrEqualTo(-.01));
          expect(source.right, lessThanOrEqualTo(size.width + .01));
          expect(source.bottom, lessThanOrEqualTo(size.height + .01));
          expect(source.width / source.height, closeTo(720 / 1280, .001));
          expect(content, Offset.zero & size);
          expect(t.takeException(), isNull);
          final out = Platform.environment['ATLAS_V97_CAPTURE'];
          if (out != null) {
            await t.runAsync(() async {
              await precacheImage(
                const AssetImage('assets/intro/atlas-welcome-still.jpg'),
                key.currentContext!,
              );
            });
            await t.pump();
            await t.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$out/intro-${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await t.tapAt(size.center(Offset.zero));
          expect(flow.visible, isFalse);
          expect((flow.media as Media).gain, 0);
          await t.pump();
          expect(flow.visible, isFalse);
          await t.pumpWidget(const SizedBox());
          flow.dispose();
          media.dispose();
        },
      );
    }
  }
  testWidgets(
    'render the opening preview from source video frames',
    (t) async {
      final out = Platform.environment['ATLAS_V97_RECORD'];
      if (out == null) return;
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final media = Media();
      media.frameBytes = await t.runAsync(
        () async => [
          for (var i = 0; i < 80; i++)
            await File(
              '$out/video-frames/${i.toString().padLeft(3, '0')}.jpg',
            ).readAsBytes(),
        ],
      );
      final warmKey = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          home: Scaffold(body: SizedBox(key: warmKey)),
        ),
      );
      await t.runAsync(() async {
        for (final bytes in media.frameBytes!) {
          await precacheImage(MemoryImage(bytes), warmKey.currentContext!);
        }
      });
      final flow = AtlasIntroController(
        preferences: Prefs(),
        media: media,
        audio: Audio(),
      );
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: AtlasIntroView(controller: flow),
            ),
          ),
        ),
      );
      await flush(t);
      await t.runAsync(
        () => Directory('$out/rendered-video').create(recursive: true),
      );
      for (var i = 0; i < 84; i++) {
        if (i <= 80) media.advance(i * 100);
        await t.pump(const Duration(milliseconds: 100));
        await t.runAsync(() async {
          final frame =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = await frame.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$out/rendered-video/${i.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          frame.dispose();
        });
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      flow.dispose();
    },
    skip: Platform.environment['ATLAS_V97_RECORD'] == null,
  );

  testWidgets(
    'decorations settle between bursts, pause on hidden route and reduced motion',
    (t) async {
      final navigator = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: AtlasHomeAtmosphere()),
        ),
      );
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 4));
      await t.pump(const Duration(milliseconds: 500));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('another page')),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      navigator.currentState!.pop();
      await t.pumpAndSettle();
      await t.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: AtlasHomeAtmosphere()),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 16));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
