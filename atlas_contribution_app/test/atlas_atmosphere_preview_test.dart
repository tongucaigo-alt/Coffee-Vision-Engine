import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_atmosphere.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'fixtures.dart';
import 'suitability_fixture.dart';
import 'tarot_test.dart' show catalog;

void main() {
  const output = String.fromEnvironment('ATLAS_ATMOSPHERE_OUT');
  const input = String.fromEnvironment('ATLAS_ATMOSPHERE_PHOTO');
  const video = bool.fromEnvironment('ATLAS_ATMOSPHERE_VIDEO');
  setUpAll(() async {
    for (final item in {
      'Literata': 'assets/brand/Literata.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(item.key)..addFont(rootBundle.load(item.value))).load();
    }
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Map<String, List<double>> metrics(WidgetTester t) {
    final result = <String, List<double>>{};
    void add(String name, Finder finder) {
      if (finder.evaluate().isEmpty) return;
      final r = t.getRect(finder.first);
      result[name] = [r.left, r.top, r.width, r.height];
    }

    add('header', find.byType(AppBar));
    add('photo', find.byKey(const ValueKey('coffee-photo-frame')));
    add('home-title', find.byKey(const ValueKey('atlas-landing-title')));
    add('home-hero', find.byKey(const ValueKey('atlas-landing-hero-slot')));
    add('navigation', find.byType(NavigationBar));
    add('loading-cup', find.byKey(const ValueKey('fortune-coffee-loading')));
    add('tarot-deck', find.byKey(const ValueKey('tarot-selection-deck')));
    for (final label in [
      'Fincanını Tara',
      'Üç Kart · Karıştır',
      'Bu fotoğraflarla devam et',
      'Falımı Oluştur',
      'Durdur',
    ]) {
      add(label, find.text(label));
    }
    final images = t.renderObjectList<RenderImage>(find.byType(RawImage));
    var n = 0;
    for (final image in images) {
      if (!image.hasSize || image.size.isEmpty) continue;
      final r = MatrixUtils.transformRect(
        image.getTransformTo(null),
        Offset.zero & image.size,
      );
      result['image-${n++}'] = [r.left, r.top, r.width, r.height];
    }
    return result;
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String file) async {
    if (output.isEmpty) return;
    await t.runAsync(() async {
      final target = File('$output/$file.png');
      await target.parent.create(recursive: true);
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await target.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(360, 700),
    const Size(412, 700),
    const Size(412, 892),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final scene in [
        'coffee-home',
        'tarot-home',
        'review',
        'annotation',
        'preparation',
        'tarot-selection',
      ]) {
        testWidgets(
          'atmosphere geometry $scene ${size.width}x${size.height}/$scale',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = size;
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.view.resetPhysicalSize);
            final dir = (await t.runAsync(
              () =>
                  Directory.systemTemp.createTemp('atlas-atmosphere-preview-'),
            ))!;
            final bytes = (await t.runAsync<Uint8List>(
              () async =>
                  input.isEmpty ? testImage() : File(input).readAsBytes(),
            ))!;
            final photo = testPhoto(
              CaptureRole.free,
              decision: PhotoDecision.marked,
              regions: [
                RegionAnnotation(
                  id: 'qa-shape',
                  box: RegionBox(.45, .35, .18, .20),
                  label: 'fish',
                ),
              ],
            ).asSetPhoto(photoId: 'qa-photo');
            final draft = ContributionDraft(
              id: 'qa-draft',
              rootId: 'qa-draft',
              groupId: 'qa-group',
              createdAt: '2026-10-26T00:00:00Z',
              consentedAt: '2026-10-26T00:00:00Z',
              kind: ContributionKind.photoSet,
              galleryStart: true,
              photos: [photo],
            );
            final source = MemoryStore(
              Directory('${dir.path}/coffee'),
              scene == 'review' ? draft : null,
            );
            await t.runAsync(() async {
              await source.directory.create(recursive: true);
              await source.file(photo.localName).writeAsBytes(bytes);
            });
            final tarot = TarotStore(Directory('${dir.path}/tarot'));
            await t.runAsync(() => tarot.initialize());
            final runtime = TarotRuntime(
              store: tarot,
              catalog: catalog(),
              promptVersion: 'test',
              promptHash: 'test',
              generateReading: (_, _) async =>
                  throw StateError('Visual test must never generate a reading'),
            );
            final progress = ValueNotifier(
              const FortuneProgress(FortunePhase.analyzing),
            );
            final flow = FortunePreparationController(progress);
            Widget page;
            if (scene == 'annotation') {
              page = AnnotationPage(
                photo: photo,
                image: MemoryImage(bytes),
                modern: true,
                onSave: (_) async {},
                onFinish: () {},
                onSaveOnly: () {},
                onSkip: () {},
              );
            } else if (scene == 'preparation') {
              flow.begin(
                photos: [photo],
                imageFor: (_) => MemoryImage(bytes),
                onCancel: () {},
              );
              page = FortunePreparationHost(
                controller: flow,
                child: const Scaffold(),
              );
            } else if (scene == 'tarot-selection') {
              final draw = (await t.runAsync(
                () => tarot.start(TarotSpread.three, runtime.catalog),
              ))!;
              page = TarotDrawPage(runtime: runtime, draw: draw);
            } else {
              page = ContributionHome(
                modern: true,
                store: source,
                service: PausedService(source),
                photoSuitability: SupportedSuitability(),
                tarotPage: TarotHomePage(runtime: runtime),
                tarotHistoryPage: TarotHistoryPage(runtime: runtime),
                onReadFortune: (_) async {},
                onGenerateFortune: (_) async {},
              );
            }
            final key = GlobalKey();
            await t.pumpWidget(
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
                  home: page,
                ),
              ),
            );
            await settle(t);
            await t.runAsync(() async {
              await precacheImage(MemoryImage(bytes), key.currentContext!);
              await precacheImage(
                const AssetImage('assets/brand/atlas-logo.png'),
                key.currentContext!,
              );
              await precacheImage(
                const AssetImage('assets/tarot/KART_ARKASI.webp'),
                key.currentContext!,
              );
            });
            if (scene == 'tarot-home') {
              await t.tap(
                find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('Tarot'),
                ),
              );
              await settle(t);
            } else if (scene == 'review') {
              await t.ensureVisible(find.byTooltip('Kaldığın Yerden Devam Et'));
              await t.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
              await settle(t);
            }
            if (scene == 'review') {
              await t.runAsync(
                () => precacheImage(
                  FileImage(source.file(photo.localName)),
                  key.currentContext!,
                ),
              );
            }
            await settle(t);
            await t.pump(const Duration(seconds: 3));
            await t.pump();
            expect(t.takeException(), isNull);
            if (scene == 'tarot-home') {
              expect(
                t
                    .widget<FilledButton>(
                      find.byKey(const ValueKey('tarot-start-three')),
                    )
                    .onPressed,
                isNotNull,
              );
            }
            if (scene == 'review') {
              final image = t.renderObject<RenderImage>(
                find
                    .descendant(
                      of: find.byKey(const ValueKey('coffee-photo-frame')),
                      matching: find.byType(RawImage),
                    )
                    .first,
              );
              expect(image.image, isNotNull);
            }
            final name =
                '$scene-${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x';
            final initial = metrics(t);
            if (output.isNotEmpty) {
              await capture(t, key, name);
              await t.runAsync(
                () => File(
                  '$output/$name.json',
                ).writeAsString(jsonEncode(initial)),
              );
            }
            if (output.isNotEmpty) {
              if (scene == 'coffee-home' || scene == 'tarot-home') {
                final g = t
                    .widget<AtlasHomeAtmosphere>(
                      find.byType(AtlasHomeAtmosphere).first,
                    )
                    .geometry;
                final halo = atlasHomeHaloBounds(g)!;
                final art = g.artwork!;
                final y =
                    (g.hero!.center.dy - halo.center.dy) / (halo.height / 2);
                final creamHalfWidth = halo.width / 2 * math.sqrt(.25 - y * y);
                List<double> rect(Rect r) => [r.left, r.top, r.width, r.height];
                await t.runAsync(() async {
                  final file = File('$output/halo-metrics/$name.json');
                  await file.parent.create(recursive: true);
                  await file.writeAsString(
                    jsonEncode({
                      'hero': rect(g.hero!),
                      'artwork': rect(art),
                      'artworkHalfWidthAtMiddle': g.artworkHalfWidth,
                      'halo': rect(halo),
                      'creamGapAtMiddle': creamHalfWidth - g.artworkHalfWidth!,
                      'topFadeBeyondArtwork': art.top - halo.top,
                      'bottomFadeBeyondArtwork': halo.bottom - art.bottom,
                    }),
                  );
                });
              }
            }
            await t.pump(const Duration(seconds: 4));
            await t.pump();
            expect(
              metrics(t),
              initial,
              reason: 'Decoration motion must not change foreground bounds',
            );
            if (video &&
                size == const Size(360, 700) &&
                scale == 1 &&
                [
                  'coffee-home',
                  'tarot-home',
                  'tarot-selection',
                ].contains(scene)) {
              for (var i = 0; i < 120; i++) {
                await t.pump(const Duration(milliseconds: 100));
                await capture(
                  t,
                  key,
                  'frames/$scene/${i.toString().padLeft(3, '0')}',
                );
              }
            }
            if (scene == 'review') {
              await t.ensureVisible(find.text('Bu fotoğraflarla devam et'));
              await t.tap(find.text('Bu fotoğraflarla devam et'));
              await settle(t);
              expect(find.byType(AnnotationPage), findsOneWidget);
            }
            if (scene == 'preparation') flow.finish();
            await t.pumpWidget(const SizedBox());
            flow.dispose();
            progress.dispose();
            runtime.dispose();
            await t.runAsync(() => dir.delete(recursive: true));
          },
        );
      }
    }
  }
}
