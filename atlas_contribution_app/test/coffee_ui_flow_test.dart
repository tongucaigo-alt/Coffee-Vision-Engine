import 'home_action_finder.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;
import 'suitability_fixture.dart';
import 'ai_test.dart' show contextData;
import 'fixtures.dart' show testPhoto, testImage;

void main({
  Future<Uint8List> Function()? photoBytes,
  Future<void> Function(String)? capture,
  bool device = false,
}) {
  setUpAll(() async {
    for (final (name, asset) in [
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
  });
  test(
    'new and original symbols roundtrip and pass the unchanged AI contract',
    () {
      for (final item in contributionLabels.entries) {
        final region = RegionAnnotation(
          id: item.key,
          box: RegionBox(.425, .425, .15, .15),
          label: item.key,
        );
        expect(RegionAnnotation.fromJson(region.toJson()).title, item.value);
        final data = contextData();
        (data['photos'] as List).first['userObservations'] = [
          {
            'origin': 'userObservation',
            'symbolName': item.value,
            'box': region.box.toJson(),
          },
        ];
        expect(validateAiContext(data), equals(data));
      }
    },
  );

  for (final width in capture == null ? [360.0, 412.0] : [360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('ten symbols remain editable at $width and scale $scale', (
        tester,
      ) async {
        if (!device) {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
        var photo = testPhoto(
          CaptureRole.free,
          decision: PhotoDecision.marked,
          regions: [
            for (var i = 0; i < 10; i++)
              RegionAnnotation(
                id: 'region-$i',
                box: i == 0
                    ? RegionBox(.25, .25, .5, .5)
                    : RegionBox(.05 + i * .04, .05, .1, .1),
                label: contributionLabels.keys.elementAt(i),
              ),
          ],
        );
        final original = photo.regions.first.box;
        await tester.pumpWidget(
          MaterialApp(
            theme: coffeeFlowTheme(atlasTheme()),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('coffee-test-surface'),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            home: AnnotationPage(
              modern: true,
              photo: photo,
              image: MemoryImage(testImage()),
              onSave: (next) async {
                photo = next;
              },
              onFinish: () {},
              onSaveOnly: () {},
              onSkip: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chip = find.widgetWithText(ChoiceChip, photo.regions.first.title);
        final beforeSelect = tester.getRect(
          find.byKey(const ValueKey('annotation-canvas')),
        );
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const ValueKey('annotation-canvas'))),
          beforeSelect,
        );
        expect(
          find.byKey(const ValueKey('coffee-selected-name')),
          findsOneWidget,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('coffee-selected-name')),
            matching: find.byType(RichText),
          ),
        );
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: photo.regions.first.title.length,
            ),
          ),
          hasLength(1),
        );
        final name = tester.getRect(
          find.byKey(const ValueKey('coffee-selected-name')),
        );
        final frame = tester.getRect(
          find.byKey(const ValueKey('coffee-photo-frame')),
        );
        expect(
          frame.contains(name.topLeft) && frame.contains(name.bottomRight),
          true,
        );
        expect(
          name.overlaps(
            tester.getRect(find.byKey(const ValueKey('coffee-mode-control'))),
          ),
          false,
        );
        expect(
          name.overlaps(
            tester.getRect(find.byKey(const ValueKey('coffee-zoom-control'))),
          ),
          false,
        );
        expect(find.text('Değiştir').hitTestable(), findsOneWidget);
        expect(find.text('Kaldır').hitTestable(), findsOneWidget);
        expect(find.text('Falımı Oluştur').hitTestable(), findsOneWidget);
        expect(find.text('İşaret').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('coffee-selected-symbols')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Scrollable>(
                find.descendant(
                  of: find.byKey(const ValueKey('coffee-selected-symbols')),
                  matching: find.byType(Scrollable),
                ),
              )
              .axisDirection,
          AxisDirection.right,
        );
        if (capture != null) await capture('many-symbols-${scale.toInt()}');
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('selected-region'))),
          const Offset(32, 0),
        );
        await tester.pumpAndSettle();
        expect(photo.regions.first.box.x, greaterThan(original.x));
        expect(photo.regions.first.box.width, closeTo(original.width, .001));
        await tester.tap(chip);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Değiştir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'aslan');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Aslan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aslan'));
        await tester.pumpAndSettle();
        expect(photo.regions, hasLength(10));
        expect(photo.regions.last.label, 'lion');
        final changedChip = find.widgetWithText(ChoiceChip, 'Aslan');
        await tester.scrollUntilVisible(
          changedChip,
          200,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('coffee-selected-symbols')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(changedChip);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kaldır'));
        await tester.pumpAndSettle();
        expect(photo.regions, hasLength(9));
        expect(photo.regions.any((r) => r.id == 'region-0'), false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final width in photoBytes == null ? [360.0, 412.0] : [360.0]) {
    for (final count in [1, 2, 3, 4]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$count photos, width $width, scale $scale: navigation, optional shapes and one generation',
          (tester) async {
            if (!device) {
              tester.view.physicalSize = Size(width, 700);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
            }
            late Directory root;
            late MemoryStore store;
            await tester.runAsync(() async {
              root = await Directory.systemTemp.createTemp('atlas-coffee-ui-');
              store = MemoryStore(root, setDraft());
              var draft = store.draft!;
              for (var i = 0; i < count; i++) {
                final p = await store.importGallery(
                  photoBytes == null ? setImage(i) : await photoBytes(),
                );
                draft = draft.withPhoto(
                  p.asSetPhoto(
                    photoId: 'photo-$i',
                    type: i == 3 ? PhotoSurface.saucer : PhotoSurface.cup,
                  ),
                );
              }
              store.draft = draft.copy(
                cupSelectionDone: true,
                saucerDecided: true,
              );
            });
            final service = PausedService(store);
            var generations = 0, exposures = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: atlasTheme(),
                builder: (context, child) => RepaintBoundary(
                  key: const ValueKey('coffee-test-surface'),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                ),
                home: ContributionHome(
                  tarotPage: const SizedBox(),
                  modern: true,
                  store: store,
                  service: service,
                  photoSuitability: SupportedSuitability(),
                  aiDescription: () async => 'Test',
                  onGenerateFortune: (_) async {
                    generations++;
                  },
                  loadAnnotationTraces: capture == null
                      ? null
                      : (draft) =>
                            TraceService(
                              Directory('${root.path}/traces'),
                            ).loadSet(
                              owner: draft.id,
                              photos: draft.photos,
                              fileFor: (p) => store.file(p.localName),
                            ),
                  onAnnotationTraceShown: (_, _) async {
                    exposures++;
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(homeAction('Fincanını Tara'));
            expect(homeAction('Fincanını Tara').hitTestable(), findsOneWidget);
            await tester.ensureVisible(
              find.byTooltip('Kaldığın Yerden Devam Et'),
            );
            expect(
              find.byTooltip('Kaldığın Yerden Devam Et').hitTestable(),
              findsOneWidget,
            );
            if (capture != null && count == 1) {
              await capture('home-${scale.toInt()}');
            }
            await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));

            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Fotoğraf 1/$count'), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(
              find.text('Bu fotoğraflarla devam et').hitTestable(),
              findsOneWidget,
            );
            if (capture != null) {
              await tester.runAsync(
                () => precacheImage(
                  FileImage(store.file(store.draft!.photos.first.localName)),
                  tester.element(find.byType(ContributionHome)),
                ),
              );
              await tester.pumpAndSettle();
            }
            if (capture != null) {
              await capture('preview-$count-${scale.toInt()}');
            }
            if (count > 1) {
              await tester.tap(find.byKey(const ValueKey('coffee-next-photo')));
              await tester.pumpAndSettle();
              expect(find.text('Fotoğraf 2/$count'), findsOneWidget);
              await tester.tap(
                find.byKey(const ValueKey('coffee-previous-photo')),
              );
              await tester.pumpAndSettle();
              expect(find.byType(CheckboxListTile), findsNothing);
            }
            await tester.tap(find.text('Bu fotoğraflarla devam et'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Taşı').hitTestable(), findsOneWidget);
            expect(find.text('İşaret').hitTestable(), findsOneWidget);
            final page = find.byType(AnnotationPage);
            expect(page, findsOneWidget);
            expect(find.text('Falımı Oluştur').hitTestable(), findsOneWidget);
            final canvas = find.byKey(const ValueKey('annotation-canvas'));
            await tester.pumpAndSettle();
            if (capture != null) {
              await capture('annotation-$count-${scale.toInt()}');
            }
            // A drag in empty photo space must not move the page or create a region.
            final beforeDrag = tester.getRect(canvas);
            await tester.dragFrom(
              tester.getCenter(canvas),
              const Offset(0, -100),
            );
            await tester.pumpAndSettle();
            expect(find.byType(LabelPicker), findsNothing);
            expect(tester.getRect(canvas), beforeDrag);
            await tester.pumpAndSettle();
            await tester.tapAt(tester.getCenter(canvas));
            await tester.pumpAndSettle();
            expect(find.byType(LabelPicker), findsOneWidget);
            if (capture != null) {
              await capture('picker-$count-${scale.toInt()}');
            }
            await tester.enterText(find.byType(TextField), 'yildiz');
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Yıldız'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Yıldız'));
            await tester.pumpAndSettle();
            expect(store.draft!.photos.first.regions.single.label, 'star');
            final box = store.draft!.photos.first.regions.single.box.toJson();
            expect(box['width'], .15);
            expect(box['height'], .15);
            if (count > 1) {
              await tester.tap(find.byKey(const ValueKey('coffee-next-photo')));
              await tester.pumpAndSettle();
              await tester.ensureVisible(
                find.byKey(const ValueKey('coffee-previous-photo')),
              );
              await tester.tap(
                find.byKey(const ValueKey('coffee-previous-photo')),
              );
              await tester.pumpAndSettle();
              expect(
                store.draft!.photos.first.regions.single.box.toJson(),
                box,
              );
            }
            final action = tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Falımı Oluştur'),
                )
                .onPressed!;
            action();
            action();
            await tester.pumpAndSettle();
            expect(store.rows, hasLength(1));
            expect(generations, 1);
            expect(service.submissions, 1);
            final saved = ContributionDraft.fromJson(
              Map<String, dynamic>.from(store.rows.single['document'] as Map),
            );
            expect(saved.photos.first.regions.single.label, 'star');
            expect(
              saved.photos
                  .skip(1)
                  .every((p) => p.decision == PhotoDecision.skipped),
              true,
            );
            if (capture != null && count == 1) {
              expect(exposures, greaterThan(0));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.runAsync(() => root.delete(recursive: true));
          },
        );
      }
    }
  }
}
