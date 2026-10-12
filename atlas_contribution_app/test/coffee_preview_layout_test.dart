import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/cropped_photo.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;
import 'suitability_fixture.dart';

void main({
  Future<void> Function(String)? capture,
  Future<Uint8List> Function()? photoBytes,
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
  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('reviewed preview actions are separated: $width, $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory root;
        late MemoryStore store;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp(
            'atlas-reviewed-spacing-',
          );
          store = MemoryStore(root, setDraft());
          final imported = await store.importGallery(setImage(0));
          final photo = imported.asSetPhoto().annotated(
            [],
            PhotoDecision.skipped,
          );
          store.draft = store.draft!
              .withPhoto(photo)
              .copy(cupSelectionDone: true, saucerDecided: true);
        });
        final before = store.draft!.toJson();
        await tester.pumpWidget(
          MaterialApp(
            theme: atlasTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ContributionHome(
              modern: true,
              store: store,
              service: PausedService(store),
              photoSuitability: SupportedSuitability(),
              onGenerateFortune: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
        await tester.pumpAndSettle();
        final review = find.widgetWithText(
          FilledButton,
          'İşaretleri Gözden Geçir',
        );
        final generate = find.widgetWithText(FilledButton, 'Falımı Oluştur');
        expect(review.hitTestable(), findsOneWidget);
        expect(generate.hitTestable(), findsOneWidget);
        if (scale == 1) {
          for (final action in [review, generate]) {
            expect(tester.getSize(action).width, 280);
            expect(tester.getRect(action).center.dx, closeTo(width / 2, .1));
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          }
        }
        expect(
          tester.getRect(generate).top - tester.getRect(review).bottom,
          closeTo(8, .1),
        );
        expect(find.text('Yalnız Kaydet').hitTestable(), findsOneWidget);
        expect(find.byType(Scrollable), findsNothing);
        expect(
          tester.getSize(find.byType(CroppedPhoto)).height,
          greaterThan(0),
        );
        expect(store.draft!.toJson(), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => root.delete(recursive: true));
      });
    }
  }
  for (final width in capture == null ? [360.0, 412.0] : [360.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final gallery in capture == null ? [false, true] : [true]) {
        for (final count in [1, 3]) {
          testWidgets(
            'preview stages: $count ${gallery ? "gallery" : "camera"}, $width, $scale',
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
                root = await Directory.systemTemp.createTemp(
                  'atlas-preview-stages-',
                );
                store = MemoryStore(root, setDraft(gallery: gallery));
                var draft = store.draft!;
                for (var i = 0; i < count; i++) {
                  final imported = await store.importGallery(
                    photoBytes == null ? setImage(i) : await photoBytes(),
                  );
                  final photo = gallery
                      ? imported.asSetPhoto(photoId: 'photo-$i')
                      : ContributionPhoto(
                          role: freeCaptureRoles[i],
                          id: 'photo-$i',
                          localName: imported.localName,
                          checksum: imported.checksum,
                          originalChecksum: imported.originalChecksum,
                          width: imported.width,
                          height: imported.height,
                          byteLength: imported.byteLength,
                          capturedAt: '2026-10-12T00:00:00Z',
                        );
                  draft = draft.withPhoto(photo);
                }
                store.draft = draft;
              });
              await tester.pumpWidget(
                MaterialApp(
                  theme: atlasTheme(),
                  builder: (context, child) => RepaintBoundary(
                    key: const ValueKey('coffee-test-surface'),
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                  ),
                  home: ContributionHome(
                    modern: true,
                    store: store,
                    service: PausedService(store),
                    photoSuitability: SupportedSuitability(),
                    cameraLauncher:
                        (
                          _, {
                          required config,
                          required captureTitle,
                          required captureInstruction,
                        }) async => null,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
              await tester.pumpAndSettle();
              expect(find.byType(Scrollable), findsNothing);
              expect(tester.takeException(), isNull);
              if (gallery) {
                expect(
                  find.text('Bu fotoğraflarla devam et').hitTestable(),
                  findsOneWidget,
                );
                await tester.tap(find.text('Bu fotoğraflarla devam et'));
                await tester.pumpAndSettle();
              } else if (count == 1) {
                expect(
                  find.text('Çekime Devam Et').hitTestable(),
                  findsOneWidget,
                );
                expect(
                  tester
                      .widget<FilledButton>(
                        find.widgetWithText(
                          FilledButton,
                          'Bu fotoğraflarla devam et',
                        ),
                      )
                      .onPressed,
                  isNull,
                );
              }
              if (gallery || count == 3) {
                expect(find.text('Tabak çek').hitTestable(), findsOneWidget);
                expect(
                  find.text('Galeriden seç').hitTestable(),
                  findsOneWidget,
                );
                expect(
                  find.text('Tabaksız devam et').hitTestable(),
                  findsOneWidget,
                );
                if (capture != null) {
                  await capture('saucer-step-$count-${scale.toInt()}');
                }
                final shown = tester.getSize(find.byType(CroppedPhoto));
                final saucerRect = tester.getRect(find.byType(CroppedPhoto));
                expect(
                  find.text('Tabak fotoğrafı da eklemek ister misin?'),
                  findsNothing,
                );
                if (scale == 1) {
                  final change = tester.getRect(find.text('Değiştir'));
                  for (final title in [
                    'Kaldır',
                    'Tabak çek',
                    'Galeriden seç',
                  ]) {
                    expect(
                      tester.getRect(find.text(title)).center.dy,
                      closeTo(change.center.dy, 1),
                    );
                  }
                }
                final savedPhoto = store.draft!.photos.first;
                expect(
                  shown.width / shown.height,
                  closeTo(
                    savedPhoto.visibleCrop.aspectRatio(
                      savedPhoto.width,
                      savedPhoto.height,
                    ),
                    .001,
                  ),
                );
                await tester.tap(find.text('Tabaksız devam et'));
                await tester.pumpAndSettle();
                expect(store.draft!.saucerDecided, true);
                if (count == 1 && gallery) {
                  expect(tester.getRect(find.byType(CroppedPhoto)), saucerRect);
                }
                if (capture != null) {
                  await capture('confirm-step-$count-${scale.toInt()}');
                }
                final photoIds = store.draft!.photos.map((p) => p.id).toList();
                await tester.tap(find.byTooltip('Tabak fotoğrafı ekle'));
                await tester.pumpAndSettle();
                expect(store.draft!.photos.map((p) => p.id).toList(), photoIds);
                expect(find.text('Tabak çek').hitTestable(), findsOneWidget);
                await tester.tap(find.text('Tabaksız devam et'));
                await tester.pumpAndSettle();
                if (count > 1) {
                  await tester.tap(find.byType(CheckboxListTile));
                  await tester.pumpAndSettle();
                }
                expect(
                  find.text('Şekilleri Seç').hitTestable(),
                  findsOneWidget,
                );
              }
              expect(find.byType(Scrollable), findsNothing);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
              await tester.runAsync(() => root.delete(recursive: true));
            },
          );
        }
      }
    }
  }
}
