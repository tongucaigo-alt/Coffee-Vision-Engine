import 'dart:io';
import 'dart:ui' as ui;

import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/atlas_button_artwork.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'package:atlas_contribution_app/src/coffee_controls.dart';
import 'package:atlas_contribution_app/src/coffee_photo_layout.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'tarot_test.dart' show catalog, fixture;
import 'umay_app_guides_test.dart' show TarotMemory;

Future<void> ready(WidgetTester t) async {
  await t.pump();
  final context = find.byType(Scaffold).evaluate().first;
  await t.runAsync(
    () => Future.wait([
      for (final asset in [
        'yalniz_kaydet',
        'devam_et_aktif',
        'devam_et_pasif',
        'falimi_olustur',
        'kategori_ask',
        'kategori_is',
        'kategori_para',
        'tasi_secili',
        'isaret_secili',
        'geri',
        'kalanlari_gec',
      ])
        precacheImage(AssetImage('assets/tuslar/$asset.png'), context),
      for (final asset in [
        'tasi_secili',
        'isaret_secili',
        'kategori_ask',
        'kategori_is',
        'kategori_para',
        'kategori_ask_secili',
      ])
        precacheImage(AssetImage('assets/tuslar/3.0x/$asset.png'), context),
      precacheImage(const AssetImage('assets/guide/example-cup.png'), context),
    ]),
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  final out = Platform.environment['ATLAS_BUTTON_CAPTURE_DIR'];
  if (out == null) return;
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final font in {
      'Literata': 'assets/brand/Literata.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/lucide_icons_flutter/Lucide':
          'packages/lucide_icons_flutter/assets/lucide.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('art preserves taps, long press and disabled semantics', (
    t,
  ) async {
    var taps = 0, holds = 0;
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => taps++,
                onLongPress: () => holds++,
                child: const Text('Yalnız Kaydet'),
              ),
              const FilledButton(
                onPressed: null,
                child: Text('Bu fotoğraflarla devam et'),
              ),
            ],
          ),
        ),
      ),
    );
    await ready(t);
    expect(
      find.byKey(const ValueKey('atlas-art:assets/tuslar/yalniz_kaydet.png')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('atlas-art:assets/tuslar/devam_et_pasif.png')),
      findsOneWidget,
    );
    await t.tap(find.text('Yalnız Kaydet'));
    await t.longPress(find.text('Yalnız Kaydet'));
    expect(taps, 1);
    expect(holds, 1);
    final disabled = t.getSemantics(find.byType(FilledButton));
    expect(
      disabled.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isFalse,
    );
    expect(disabled.label, contains('Bu fotoğraflarla devam et'));
    expect(t.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('busy mapped artwork keeps its live progress indicator', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        home: const Scaffold(
          body: AtlasPrimaryButton.icon(
            onPressed: null,
            icon: CircularProgressIndicator(),
            label: Text('Falımı Oluştur'),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('home exemption restores native themes and avoids new artwork', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        home: Scaffold(
          body: AtlasOriginalButtons(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Ana ekran'),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value.toString().startsWith('atlas-art:'),
      ),
      findsNothing,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('bold photo controls have one surface and keep their actions', (
    t,
  ) async {
    var photos = 0, saucers = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(boldText: true, textScaler: const TextScaler.linear(.9)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              CoffeeOverlayButton(
                key: const ValueKey('photo-overlay'),
                tooltip: 'Fotoğraf ekle',
                onPressed: () => photos++,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined),
                    Text('Fotoğraf ekle'),
                  ],
                ),
              ),
              CoffeeActionStrip([
                CoffeeAction(
                  'Tabak ekle',
                  () => saucers++,
                  emphasized: true,
                  key: const ValueKey('saucer-action'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    await ready(t);
    final overlay = find.byKey(const ValueKey('photo-overlay'));
    final materials = t
        .widgetList<Material>(
          find.descendant(of: overlay, matching: find.byType(Material)),
        )
        .toList();
    expect(materials.every((m) => m.color == null || m.color!.a == 0), isTrue);
    final button = t.widget<TextButton>(
      find.byKey(const ValueKey('saucer-action')),
    );
    for (final states in <Set<WidgetState>>[
      {},
      {WidgetState.pressed},
    ]) {
      expect(
        button.style!.backgroundColor!.resolve(states),
        Colors.transparent,
      );
      expect(button.style!.side!.resolve(states), BorderSide.none);
    }
    await t.tap(overlay);
    await t.tap(find.byKey(const ValueKey('saucer-action')));
    expect(photos, 1);
    expect(saucers, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'actual Tarot mood keeps compact size without a selected or pressed frame',
    (t) async {
      t.view.physicalSize = const Size(384, 832);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final seed = fixture().copy(mood: TarotMood.unsure);
      final store = TarotMemory(seed);
      var requests = 0;
      final runtime = TarotRuntime(
        store: store,
        catalog: catalog(),
        promptVersion: 'test',
        promptHash: 'test',
        generateReading: (_, _) async {
          requests++;
          throw StateError('No AI in a visual test');
        },
      );
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              boldText: true,
              textScaler: const TextScaler.linear(.9),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: TarotDrawPage(runtime: runtime, draw: seed),
        ),
      );
      await t.pump();
      final context = find.byType(Scaffold).evaluate().first;
      await t.runAsync(
        () => Future.wait([
          for (final i in seed.selected)
            precacheImage(
              AssetImage('assets/tarot/${seed.deck[i].card.image}'),
              context,
            ),
          precacheImage(
            const AssetImage('assets/tuslar/3.0x/devam_et_aktif.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/tuslar/3.0x/yalniz_kaydet.png'),
            context,
          ),
        ]),
      );
      await t.pump(const Duration(seconds: 2));
      final selected = find.byKey(const ValueKey('tarot-mood-unsure'));
      final style = t.widget<OutlinedButton>(selected).style!;
      for (final states in <Set<WidgetState>>[
        {},
        {WidgetState.selected},
        {WidgetState.pressed},
      ]) {
        expect(style.side!.resolve(states), BorderSide.none);
        expect(style.backgroundColor!.resolve(states), Colors.transparent);
        expect(style.foregroundColor!.resolve(states), atlasCard);
      }
      expect(t.getSize(selected).height, closeTo(48, .01));
      await capture(t, key, 'tarot-mood-bold-selected');
      final gesture = await t.startGesture(t.getCenter(selected));
      await t.pump(const Duration(milliseconds: 50));
      await capture(t, key, 'tarot-mood-bold-pressed');
      await gesture.moveBy(const Offset(-1000, -1000));
      await gesture.up();
      await t.pump();
      expect(store.writes, 0);
      expect(requests, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      runtime.dispose();
    },
  );

  for (final (size, scale, bold) in [
    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(412, 700),
    ])
      for (final scale in [1.0, 2.0])
        for (final bold in [false, true]) (size, scale, bold),
    (const Size(384, 832), .9, true),
  ]) {
    testWidgets(
      'actual annotation ${size.width}/${size.height} text $scale bold $bold',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        if (size.width == 384) {
          t.view.padding = const FakeViewPadding(top: 34);
        }
        addTearDown(t.view.reset);
        final key = GlobalKey();
        var generated = 0, saved = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: atlasTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: AnnotationPage(
              modern: true,
              photo: testPhoto(CaptureRole.top),
              image: const AssetImage('assets/guide/example-cup.png'),
              onSave: (_) async => saved++,
              onFinish: () async => generated++,
            ),
          ),
        );
        await ready(t);
        final create = find.byKey(const ValueKey('coffee-create-fortune'));
        expect(create.hitTestable(), findsOneWidget);
        expect(t.getSize(create).height, greaterThanOrEqualTo(48));
        expect(
          find.byKey(
            const ValueKey('atlas-art:assets/tuslar/falimi_olustur.png'),
          ),
          findsOneWidget,
        );
        final headerButtons = [
          for (final mode in ['false', 'true'])
            find.byKey(ValueKey('coffee-mode-button-$mode')),
          for (final topic in ['Aşk', 'İş', 'Para'])
            find.byKey(ValueKey('coffee-focus-$topic')),
        ];
        final frame = t.getRect(
          find.byKey(const ValueKey('coffee-photo-frame')),
        );
        for (final button in headerButtons) {
          expect(button.hitTestable(), findsOneWidget);
          final box = t.getRect(button);
          expect(
            box.top,
            greaterThanOrEqualTo(
              t.getRect(find.text('Sen ne görüyorsun?')).bottom + 7.9,
            ),
          );
          expect(box.overlaps(t.getRect(find.byType(BackButton))), isFalse);
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(size.width));
          expect(box.bottom, lessThanOrEqualTo(frame.top - 24 + .01));
          expect(box.width, greaterThanOrEqualTo(48));
          expect(box.height, greaterThanOrEqualTo(48));
          final label = find.descendant(
            of: button,
            matching: find.byType(Text),
          );
          final paragraph = t.renderObject<RenderParagraph>(label);
          final letters = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: paragraph.text.toPlainText().length,
            ),
          );
          for (final lettersBox in letters) {
            final bounds = lettersBox.toRect().shift(
              paragraph.localToGlobal(Offset.zero),
            );
            expect(bounds.left, greaterThanOrEqualTo(box.left + 3));
            expect(bounds.right, lessThanOrEqualTo(box.right - 3));
          }
        }
        for (var i = 0; i < headerButtons.length; i++) {
          for (var j = i + 1; j < headerButtons.length; j++) {
            expect(
              t.getRect(headerButtons[i]).overlaps(t.getRect(headerButtons[j])),
              isFalse,
            );
          }
        }
        expect(
          t.getRect(headerButtons[3]).left - t.getRect(headerButtons[2]).right,
          closeTo(4, .01),
        );
        expect(
          t.getRect(headerButtons[4]).left - t.getRect(headerButtons[3]).right,
          closeTo(4, .01),
        );
        expect(
          t.getRect(headerButtons[4]).right,
          closeTo(size.width - 16, .01),
        );
        await capture(
          t,
          key,
          'annotation-${size.width.toInt()}-${size.height.toInt()}-${scale}x${bold ? '-bold' : ''}',
        );
        final modeArtwork = find.byKey(
          const ValueKey('atlas-art:assets/tuslar/isaret_secili.png'),
        );
        expect(modeArtwork, findsOneWidget);
        final modeImage = t.widget<Image>(modeArtwork);
        expect(
          (modeImage.image as AssetImage).assetName,
          'assets/tuslar/3.0x/isaret_secili.png',
        );
        expect(modeImage.fit, BoxFit.contain);
        final modeBounds = t.getRect(modeArtwork);
        expect(modeBounds.size.aspectRatio, closeTo(113 / 59, .001));
        expect(modeBounds.bottom, lessThanOrEqualTo(frame.top - 24 + .01));
        final modeGroup = t.getRect(
          find.byKey(const ValueKey('coffee-mode-control')),
        );
        expect(modeGroup.contains(modeBounds.topLeft), isTrue);
        expect(
          modeGroup.contains(modeBounds.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        await t.tap(find.byKey(const ValueKey('coffee-mode-button-false')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('atlas-art:assets/tuslar/tasi_secili.png')),
          findsOneWidget,
        );
        await capture(
          t,
          key,
          'annotation-move-${size.width.toInt()}-${size.height.toInt()}-${scale}x${bold ? '-bold' : ''}',
        );
        await t.tap(find.byKey(const ValueKey('coffee-mode-button-true')));
        await t.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey('atlas-art:assets/tuslar/isaret_secili.png'),
          ),
          findsOneWidget,
        );
        await t.tap(create);
        expect(generated, 1);
        expect(saved, 0);
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final (size, scale) in [
    (const Size(384, 832), .9),
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets(
      'pending area action stays outside photo and picker uses cream $size/$scale',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        if (size.width == 384) t.view.padding = const FakeViewPadding(top: 34);
        addTearDown(t.view.reset);
        final key = GlobalKey();
        var saves = 0, generated = 0;
        ContributionPhoto? saved;
        await t.pumpWidget(
          MaterialApp(
            theme: atlasTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(boldText: true, textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: AnnotationPage(
              modern: true,
              photo: testPhoto(CaptureRole.top),
              image: const AssetImage('assets/guide/example-cup.png'),
              onSave: (photo) async {
                saved = photo;
                saves++;
              },
              onFinish: () async => generated++,
            ),
          ),
        );
        await ready(t);
        final frame = find.byKey(const ValueKey('coffee-photo-frame'));
        final before = t.getRect(frame);
        await t.tap(find.byKey(const ValueKey('annotation-canvas')));
        await t.pumpAndSettle();
        expect(find.byType(LabelPicker), findsOneWidget);
        expect(
          t.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
          atlasCream,
        );
        expect(
          t
              .widget<ColoredBox>(
                find.byKey(const ValueKey('coffee-label-picker-background')),
              )
              .color,
          atlasCream,
        );
        await capture(t, key, 'label-picker-${size.width.toInt()}-${scale}x');
        await t.scrollUntilVisible(
          find.text('Vazge\u00e7'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(LabelPicker),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.tap(find.text('Vazge\u00e7'));
        await t.pumpAndSettle();
        final choose = find.byKey(const ValueKey('coffee-choose-area'));
        expect(choose.hitTestable(), findsOneWidget);
        final action = t.getRect(choose);
        expect(action.top, greaterThanOrEqualTo(before.bottom));
        expect(action.overlaps(before), isFalse);
        expect(action.width, lessThanOrEqualTo(220));
        expect(action.height, greaterThanOrEqualTo(48));
        expect(action.bottom, lessThanOrEqualTo(size.height));
        expect(t.getRect(frame), before);
        expect(
          find.byKey(const ValueKey('coffee-create-fortune')),
          findsNothing,
        );
        expect(saves, 0);
        await capture(t, key, 'pending-area-${size.width.toInt()}-${scale}x');
        await t.tap(choose);
        await t.pumpAndSettle();
        final bird = find.byKey(const ValueKey('coffee-label-bird'));
        await t.ensureVisible(bird);
        await t.tap(bird);
        await t.pumpAndSettle();
        expect(saves, 1);
        expect(saved!.regions.single.label, 'bird');
        expect(find.byKey(const ValueKey('coffee-choose-area')), findsNothing);
        expect(
          find.byKey(const ValueKey('coffee-create-fortune')),
          findsOneWidget,
        );
        expect(t.getRect(frame), before);
        expect(generated, 0);
        expect(t.takeException(), isNull);
      },
    );
  }
}
