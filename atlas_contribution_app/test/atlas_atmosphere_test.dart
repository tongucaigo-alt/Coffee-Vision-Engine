import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_atmosphere.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';

void main() {
  for (final scene in [
    AtlasAtmosphereScene.coffeeHome,
    AtlasAtmosphereScene.tarotHome,
  ]) {
    testWidgets('resume control does not crop or shift home accents: $scene', (
      t,
    ) async {
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 128, 128),
        Paint()..color = Colors.brown,
      );
      final picture = recorder.endRecording();
      final image = (await t.runAsync(() => picture.toImage(128, 128)))!;
      picture.dispose();
      addTearDown(image.dispose);
      final boundary = GlobalKey();
      Widget page(bool resume, {bool markArtwork = true}) => MaterialApp(
        theme: atlasTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 700),
            disableAnimations: true,
          ),
          child: RepaintBoundary(
            key: boundary,
            child: AtlasAtmosphereSurface(
              scene: scene,
              child: Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      top: 96,
                      left: 20,
                      width: 320,
                      height: 152,
                      child: AtlasAtmosphereRegion(
                        kind: markArtwork
                            ? AtlasAtmosphereRegionKind.hero
                            : AtlasAtmosphereRegionKind.protected,
                        child: Center(
                          child: RawImage(
                            image: image,
                            width: 128,
                            height: 128,
                          ),
                        ),
                      ),
                    ),
                    if (resume)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          key: const ValueKey('resume'),
                          onPressed: () {},
                          icon: const Icon(Icons.play_arrow),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>> backgroundPixels() async {
        final shot =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
        final result = <int>[];
        // Background and accents, excluding the control and opaque artwork.
        for (var y = 64; y < 260; y++) {
          for (var x = 40; x < 320; x++) {
            if (y >= 108 && y < 236 && x >= 116 && x < 244) continue;
            result.addAll(
              bytes!.buffer.asUint8List((y * shot.width + x) * 4, 4),
            );
          }
        }
        shot.dispose();
        return result;
      }

      Future<List<int>> paperPixel() async {
        final shot =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixel = bytes!.buffer
            .asUint8List((170 * shot.width + 90) * 4, 4)
            .toList();
        shot.dispose();
        return pixel;
      }

      await t.pumpWidget(page(false));
      await t.pump();
      await t.pump();
      final before = (await t.runAsync(backgroundPixels))!;
      final beforeArt = t.getRect(find.byType(RawImage));
      await t.pumpWidget(page(true));
      await t.pump();
      await t.pump();
      expect(t.getRect(find.byType(RawImage)), beforeArt);
      expect(
        t.getSize(find.byKey(const ValueKey('resume'))),
        const Size(48, 48),
      );
      expect(
        (await t.runAsync(backgroundPixels))!,
        before,
        reason: 'A draft/resume button must not change background accents',
      );
      final geometry = t
          .widget<AtlasHomeAtmosphere>(find.byType(AtlasHomeAtmosphere))
          .geometry;
      expect(geometry.artwork, beforeArt);
      expect(geometry.artworkHalfWidth, 64);
      final withArtworkAnchor = (await t.runAsync(paperPixel))!;
      await t.pumpWidget(page(false, markArtwork: false));
      await t.pump();
      await t.pump();
      expect(
        (await t.runAsync(paperPixel))!,
        withArtworkAnchor,
        reason: 'Home artwork must not brighten the paper with a halo',
      );
      await t.pumpWidget(const SizedBox());
    });
  }
  for (final scene in AtlasAtmosphereScene.values) {
    testWidgets(
      'decoration preserves layout, protects content and passes taps: $scene',
      (t) async {
        t.view.physicalSize = const Size(360, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var taps = 0, builds = 0;
        Widget page(AtlasAtmosphereScene? value) => MaterialApp(
          theme: atlasTheme(),
          home: AtlasAtmosphereSurface(
            scene: value,
            child: Builder(
              builder: (context) {
                builds++;
                return Scaffold(
                  appBar: AppBar(title: const Text('Başlık')),
                  body: Column(
                    children: [
                      const SizedBox(height: 32),
                      const AtlasAtmosphereRegion(
                        kind: AtlasAtmosphereRegionKind.protected,
                        child: SizedBox(
                          key: ValueKey('photo'),
                          width: 160,
                          height: 180,
                          child: ColoredBox(color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Okunabilir metin', key: ValueKey('caption')),
                      FilledButton(
                        key: const ValueKey('action'),
                        onPressed: () => taps++,
                        child: const Text('Devam'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        Map<String, Rect> rects() => {
          for (final key in ['photo', 'caption', 'action'])
            key: t.getRect(find.byKey(ValueKey(key))),
        };
        await t.pumpWidget(page(null));
        final before = rects();
        await t.pumpWidget(page(scene));
        await t.pump();
        await t.pump();
        expect(rects(), before);
        final geometry = t
            .widget<AtlasHomeAtmosphere>(find.byType(AtlasHomeAtmosphere))
            .geometry;
        expect(geometry.ready, isTrue);
        expect(geometry.protected, contains(before['photo']!.inflate(8)));
        expect(
          geometry.text.any((r) => r.contains(before['caption']!.center)),
          isTrue,
        );
        final count = builds;
        await t.pump(const Duration(seconds: 4));
        await t.pump();
        expect(rects(), before);
        expect(
          builds,
          count,
          reason: 'Decoration ticks must not rebuild foreground widgets',
        );
        await t.tap(find.byKey(const ValueKey('action')));
        expect(taps, 1);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final condition in [
    'inactive',
    'ticker',
    'reduced',
    'background',
    'route',
  ]) {
    testWidgets('paint clock pauses and resumes: $condition', (t) async {
      final nav = GlobalKey<NavigatorState>();
      Widget page({
        bool active = true,
        bool ticker = true,
        bool reduced = false,
      }) => MaterialApp(
        navigatorKey: nav,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: AtlasAtmosphereSurface(
              scene: AtlasAtmosphereScene.tarotHome,
              active: active,
              child: const Scaffold(body: Center(child: Text('Metin'))),
            ),
          ),
        ),
      );
      await t.pumpWidget(page());
      await t.pump();
      await t.pump();
      final state = t.state(find.byType(AtlasHomeAtmosphere));
      final painter = t
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(AtlasHomeAtmosphere),
              matching: find.byType(CustomPaint),
            ),
          )
          .last
          .painter!;
      var repaints = 0;
      void changed() => repaints++;
      painter.addListener(changed);
      await t.pump(const Duration(seconds: 1));
      expect(repaints, greaterThan(0));
      switch (condition) {
        case 'inactive':
          await t.pumpWidget(page(active: false));
        case 'ticker':
          await t.pumpWidget(page(ticker: false));
        case 'reduced':
          await t.pumpWidget(page(reduced: true));
        case 'background':
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        case 'route':
          nav.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Üst sayfa')),
            ),
          );
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
      }
      final stopped = repaints;
      await t.pump(const Duration(seconds: 2));
      expect(repaints, stopped);
      expect(
        t.state(find.byType(AtlasHomeAtmosphere, skipOffstage: false)),
        same(state),
      );
      if (condition == 'background') {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      if (condition == 'route') {
        nav.currentState!.pop();
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      } else {
        await t.pumpWidget(page());
      }
      final resumed = repaints;
      await t.pump(const Duration(seconds: 1));
      expect(repaints, greaterThan(resumed));
      painter.removeListener(changed);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('scrolling refreshes protected viewport positions', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: AtlasAtmosphereSurface(
          scene: AtlasAtmosphereScene.coffeePhoto,
          child: Scaffold(
            body: ListView(
              children: const [
                SizedBox(height: 90),
                AtlasAtmosphereRegion(
                  kind: AtlasAtmosphereRegionKind.protected,
                  child: SizedBox(key: ValueKey('moving-photo'), height: 150),
                ),
                SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    final before = t.getRect(find.byKey(const ValueKey('moving-photo')));
    await t.drag(find.byType(ListView), const Offset(0, -120));
    await t.pump();
    await t.pump();
    final after = t.getRect(find.byKey(const ValueKey('moving-photo')));
    expect(after.top, lessThan(before.top));
    final geometry = t
        .widget<AtlasHomeAtmosphere>(find.byType(AtlasHomeAtmosphere))
        .geometry;
    expect(geometry.protected, contains(after.inflate(8)));
    await t.pumpWidget(const SizedBox());
  });
}
