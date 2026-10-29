import 'home_action_finder.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_landing_layout.dart';
import 'package:atlas_contribution_app/src/atlas_atmosphere.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'fixtures.dart';
import 'tarot_test.dart' show catalog;

void main() {
  const output = String.fromEnvironment('ATLAS_LANDING_OUT');
  final measurements = <String, Map<String, List<double>>>{};
  final v116 =
      jsonDecode(
            File('test/fixtures/landing-v116-metrics.json').readAsStringSync(),
          )
          as Map;
  setUpAll(() async {
    for (final font in {
      'EB Garamond': 'assets/brand/EBGaramond.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (output.isEmpty) return;
    await tester.pump();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in const [
    Size(360, 700),
    Size(412, 700),
    Size(412, 892),
    Size(700, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final resume in [false, true]) {
        testWidgets('reference landing $size text=$scale resume=$resume', (
          t,
        ) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final dir = (await t.runAsync(
            () => Directory.systemTemp.createTemp('atlas-landing-redesign-'),
          ))!;
          final source = MemoryStore(
            Directory('${dir.path}/coffee'),
            resume ? testDraft() : null,
          );
          final store = TarotStore(Directory('${dir.path}/tarot'));
          await t.runAsync(store.initialize);
          if (resume) {
            await t.runAsync(() => store.start(TarotSpread.three, catalog()));
          }
          var aiCalls = 0;
          final runtime = TarotRuntime(
            store: store,
            catalog: catalog(),
            promptVersion: 'test',
            promptHash: 'test',
            generateReading: (_, _) async {
              aiCalls++;
              throw StateError('A design test must never call AI');
            },
          );
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: atlasTheme(),
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 28, bottom: 20),
                    viewPadding: const EdgeInsets.only(top: 28, bottom: 20),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: ContributionHome(
                  modern: true,
                  store: source,
                  service: PausedService(source),
                  onReadFortune: (_) async {},
                  tarotPage: TarotHomePage(runtime: runtime),
                  tarotHistoryPage: TarotHistoryPage(runtime: runtime),
                ),
              ),
            ),
          );
          await settle(t);
          final header = t.getRect(find.byType(AppBar));
          final navigation = t.getRect(find.byType(NavigationBar));
          for (final scene in ['coffee', 'tarot']) {
            if (scene == 'tarot') {
              await t.tap(
                find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('Tarot'),
                ),
              );
              await settle(t);
            }
            final title = scene == 'coffee'
                ? 'Fincanını Keşfet'
                : 'Kartların Hikâyesi';
            final primaryLabel = scene == 'coffee'
                ? 'Fincanını Tara'
                : 'Üç Kart · Karıştır';
            final secondaryLabel = scene == 'coffee'
                ? 'Galeriden Seç'
                : 'Günün Kartı';
            expect(find.text(title), findsOneWidget);
            expect(
              find.text(
                scene == 'coffee'
                    ? 'Hikâyene bir fincanla başla'
                    : 'Hikâyeni üç kartla keşfet',
              ),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('$scene-resume')),
              resume ? findsOneWidget : findsNothing,
            );
            expect(t.getRect(find.byType(AppBar)), header);
            expect(t.getRect(find.byType(NavigationBar)), navigation);
            final frame = t.getRect(
              find.byKey(
                ValueKey(
                  scene == 'coffee' ? 'atlas-home-frame' : 'tarot-home-frame',
                ),
              ),
            );
            final primary = t.getRect(
              find.byKey(const ValueKey('atlas-primary-image')),
            );
            final secondary = t.getRect(
              find.byKey(const ValueKey('atlas-secondary-image')),
            );
            // Verify both 10% reductions independently of the layout helper.
            expect(primary.width, closeTo(frame.width * 320 / 873 * .9, .01));
            expect(secondary.width, closeTo(frame.width * 180 / 873 * .9, .01));
            expect(primary.center.dx, closeTo(frame.center.dx, .01));
            expect(secondary.center.dx, closeTo(frame.center.dx, .01));
            expect(secondary.bottom, lessThan(primary.top));
            final primaryHint = t.getRect(
              find.byKey(const ValueKey('atlas-primary-hint')),
            );
            final secondaryHint = t.getRect(
              find.byKey(const ValueKey('atlas-secondary-hint')),
            );
            expect(primaryHint.top, closeTo(primary.bottom + 8, .01));
            expect(secondaryHint.top, closeTo(secondary.bottom + 6, .01));
            expect(secondaryHint.bottom, lessThan(primary.top));
            expect(primaryHint.bottom, lessThan(frame.bottom - 15));
            if (scale == 1) {
              expect(frame.bottom - primary.bottom, closeTo(58, .01));
              expect(primary.top - secondary.bottom, closeTo(34, .01));
            }
            final style = t.widget<Text>(find.text(title)).style!;
            expect(style.fontFamily, 'EB Garamond');
            expect(style.fontWeight, FontWeight.w600);
            for (final label in [primaryLabel, secondaryLabel]) {
              final button = homeAction(label);
              expect(t.getSize(button).width, greaterThanOrEqualTo(48));
              expect(t.getSize(button).height, greaterThanOrEqualTo(48));
              expect(t.widget<TextButton>(button).onPressed, isNotNull);
            }
            final geometry = t
                .widget<AtlasHomeAtmosphere>(
                  find.byType(AtlasHomeAtmosphere).first,
                )
                .geometry;
            expect(geometry.heading, isNotNull);
            expect(geometry.heading!.overlaps(geometry.hero!), isFalse);
            final headingTitle = t
                .getRect(find.text(title))
                .shift(-frame.topLeft);
            expect(geometry.heading!.contains(headingTitle.center), isTrue);
            final expectedArtwork = primary.shift(-frame.topLeft);
            expect(geometry.artwork!.left, closeTo(expectedArtwork.left, .001));
            expect(geometry.artwork!.top, closeTo(expectedArtwork.top, .001));
            expect(
              geometry.artwork!.width,
              closeTo(expectedArtwork.width, .001),
            );
            expect(
              geometry.artwork!.height,
              closeTo(expectedArtwork.height, .001),
            );
            if (resume) {
              final corner = t.getRect(find.byKey(ValueKey('$scene-resume')));
              final kicker = t.getRect(
                find.text(
                  scene == 'coffee'
                      ? '3 AÇILI ÇEKİM'
                      : 'GEÇMİŞ · ŞİMDİ · OLASI YÖN',
                ),
              );
              expect(corner.overlaps(kicker), isFalse);
              expect(corner.overlaps(t.getRect(find.text(title))), isFalse);
            }
            final titleBefore = t.getRect(find.text(title));
            final positions = <String, Rect>{
              'header': header,
              'navigation': navigation,
              'frame': frame,
              'title': titleBefore,
              'primary': primary,
              'secondary': secondary,
            }.map((k, r) => MapEntry(k, [r.left, r.top, r.width, r.height]));
            final id =
                '$scene-${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x';
            if (resume) {
              expect(
                positions,
                measurements[id],
                reason: 'The resume control must not move any foreground slot',
              );
            } else {
              measurements[id] = positions;
            }
            final name = '$id-resume-${resume ? "on" : "off"}';
            final before = v116[name] as Map;
            for (final slot in ['header', 'navigation', 'title', 'frame']) {
              final expected = before[slot] as List;
              for (var i = 0; i < 4; i++) {
                expect(
                  positions[slot]![i],
                  closeTo(expected[i] as num, .001),
                  reason: 'V116 $slot must remain fixed in $name',
                );
              }
            }
            if (scale == 1) {
              expect(
                primary.top,
                closeTo((before['primary'][1] as num) + 6, .001),
              );
              expect(
                secondary.top,
                closeTo((before['secondary'][1] as num) + 12, .001),
              );
            }
            await capture(t, boundary, name);
            await capture(t, boundary, '$name-hints-on');
            if (output.isNotEmpty) {
              await t.runAsync(
                () => File(
                  '$output/$name.json',
                ).writeAsString(jsonEncode(positions)),
              );
            }
            if (scale == 1 && size.height >= 700) {
              for (final scroll in t.stateList<ScrollableState>(
                find.byType(Scrollable),
              )) {
                expect(scroll.position.maxScrollExtent, 0);
              }
            }
            await t.pump(const Duration(seconds: 6));
            await t.pump(const Duration(milliseconds: 400));
            expect(
              t
                  .widget<AnimatedOpacity>(
                    find.byKey(const ValueKey('atlas-primary-hint')),
                  )
                  .opacity,
              0,
            );
            expect(
              t
                  .widget<AnimatedOpacity>(
                    find.byKey(const ValueKey('atlas-secondary-hint')),
                  )
                  .opacity,
              0,
            );
            expect(
              t.getRect(find.byKey(const ValueKey('atlas-primary-image'))),
              primary,
            );
            expect(
              t.getRect(find.byKey(const ValueKey('atlas-secondary-image'))),
              secondary,
            );
            expect(t.getRect(find.text(title)), titleBefore);
            await capture(t, boundary, '$name-hints-off');
            await t.ensureVisible(homeAction(primaryLabel));
            await t.pump();
            expect(homeAction(primaryLabel).hitTestable(), findsOneWidget);
            expect(
              find.textContaining('Tarot eğlence ve öz değerlendirme içindir.'),
              findsNothing,
            );
            if (scale == 2) await capture(t, boundary, '$name-actions');
            expect(t.takeException(), isNull);
          }
          expect(aiCalls, 0);
          await t.pumpWidget(const SizedBox());
          runtime.dispose();
          await t.runAsync(() => dir.delete(recursive: true));
        });
      }
    }
  }

  testWidgets('artwork keeps its action; disabled artwork does not tap', (
    t,
  ) async {
    var taps = 0;
    Widget page(bool enabled) => MaterialApp(
      theme: atlasTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 296,
            child: AtlasLandingImageButton(
              asset: 'atlas_gallery_button.webp',
              label: 'Galeriden Seç',
              onPressed: enabled ? () => taps++ : null,
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(page(true));
    await t.tap(find.byKey(const ValueKey('atlas-secondary-image')));
    await t.tap(homeAction('Galeriden Seç'));
    expect(taps, 2);
    await t.pumpWidget(page(false));
    await t.tap(find.byKey(const ValueKey('atlas-secondary-image')));
    await t.tap(homeAction('Galeriden Seç'));
    expect(taps, 2);
    expect(t.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    await t.pumpWidget(const SizedBox());
  });
}
