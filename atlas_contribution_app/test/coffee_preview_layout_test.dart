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
  final frames = <String, Rect>{};
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
        final review = find.byTooltip('İşaretleri Gözden Geçir');
        final generate = find.widgetWithText(FilledButton, 'Falımı Oluştur');
        await tester.ensureVisible(review);
        await tester.pumpAndSettle();
        expect(review.hitTestable(), findsOneWidget);
        expect(generate.hitTestable(), findsOneWidget);
        if (scale == 1) {
          expect(tester.getSize(generate).width, 280);
          expect(tester.getRect(generate).center.dx, closeTo(width / 2, .1));
        }
        expect(find.text('Yalnız Kaydet').hitTestable(), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                axisDirectionToAxis(w.axisDirection) == Axis.vertical,
          ),
          findsNothing,
        );
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
                          onFinishSequence,
                        }) async => null,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
              await tester.pumpAndSettle();
              expect(
                find.byWidgetPredicate(
                  (w) =>
                      w is Scrollable &&
                      axisDirectionToAxis(w.axisDirection) == Axis.vertical,
                ),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
              final next = find.widgetWithText(
                FilledButton,
                'Bu fotoğraflarla devam et',
              );
              expect(next.hitTestable(), findsOneWidget);
              expect(find.text('Tabaksız devam et'), findsNothing);
              expect(find.text('Tabak ekle').hitTestable(), findsOneWidget);
              final frameKey = '$gallery-$count-$width';
              final measuredFrame = tester.getRect(
                find.byKey(const ValueKey('coffee-photo-frame')),
              );
              // V63 geometry stays fixed; the new header does not consume body space.
              expect(measuredFrame, Rect.fromLTWH(16, 88, width - 32, 428));
              expect(
                tester.getRect(find.text('Fotoğraflarına Bak')).center.dy,
                40,
              );
              if (count < 3) {
                final target = tester.getSize(find.byTooltip('Fotoğraf ekle'));
                expect(target.width, greaterThanOrEqualTo(48));
                expect(target.height, greaterThanOrEqualTo(48));
                expect(
                  tester
                      .widget<Text>(find.text('Fotoğraf ekle'))
                      .style!
                      .fontSize,
                  9,
                );
              }
              if (scale == 1) {
                frames[frameKey] = measuredFrame;
              } else {
                expect(measuredFrame, frames[frameKey]);
              }
              final before = store.draft!.toJson();
              if (scale == 1) {
                final change = tester.getRect(find.text('Değiştir'));
                final saucer = tester.getRect(find.text('Tabak ekle'));
                final remove = tester.getRect(find.text('Kaldır'));
                expect(saucer.center.dy, closeTo(change.center.dy, 1));
                expect(remove.center.dy, closeTo(change.center.dy, 1));
                expect(change.center.dx, lessThan(saucer.center.dx));
                expect(saucer.center.dx, lessThan(remove.center.dx));
              }
              if (gallery) {
                final angle = find.byKey(
                  const ValueKey('coffee-angle-control'),
                );
                expect(tester.getSize(angle).height, greaterThanOrEqualTo(48));
                final angleText = tester.getRect(find.text('Açı seç'));
                final title = tester.getRect(find.text('Fotoğraflarına Bak'));
                expect(angleText.top, greaterThanOrEqualTo(title.bottom));
                expect(angleText.bottom, lessThanOrEqualTo(measuredFrame.top));
                expect(tester.getRect(angle).left, greaterThanOrEqualTo(56));
                await tester.tap(angle);
                await tester.pumpAndSettle();
                final menu = find
                    .ancestor(
                      of: find.text('Açı seç — isteğe bağlı').last,
                      matching: find.byType(Material),
                    )
                    .first;
                expect(tester.getSize(menu).width, tester.getSize(next).width);
                expect(tester.getRect(menu).center.dx, closeTo(width / 2, .1));
                await tester.tapAt(const Offset(2, 2));
                await tester.pumpAndSettle();
                expect(store.draft!.toJson(), before);
              }
              await tester.tap(find.byTooltip('Tabak fotoğrafı ekle'));
              await tester.pumpAndSettle();
              expect(find.text('Kamera').hitTestable(), findsOneWidget);
              expect(find.text('Galeri').hitTestable(), findsOneWidget);
              await tester.tap(find.text('Vazgeç'));
              await tester.pumpAndSettle();
              expect(store.draft!.toJson(), before);
              if (capture != null) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 200)),
                );
                await tester.pumpAndSettle();
                await capture('photo-step-$count-${scale.toInt()}');
              }
              if (gallery || count == 3) {
                expect(find.byType(CheckboxListTile), findsNothing);
                final previewFrame = tester.getRect(
                  find.byKey(const ValueKey('coffee-photo-frame')),
                );
                final previewImage = tester.getRect(find.byType(CroppedPhoto));
                await tester.tap(next);
                await tester.pumpAndSettle();
                expect(store.draft!.cupSelectionDone, true);
                expect(store.draft!.saucerDecided, true);
                expect(find.text('Sen ne görüyorsun?'), findsOneWidget);
                expect(find.text('Taşı').hitTestable(), findsOneWidget);
                expect(
                  tester.widget<Text>(find.text('Taşı')).style!.fontSize,
                  12,
                );
                final mode = tester.getRect(
                  find.byKey(const ValueKey('coffee-mode-control')),
                );
                expect(mode.bottom, lessThanOrEqualTo(previewFrame.top));
                expect(mode.left, 56);
                expect(mode.overlaps(tester.getRect(find.byType(BackButton))), false);
                expect(
                  tester.getRect(find.text('Taşı')).top,
                  greaterThanOrEqualTo(
                    tester.getRect(find.text('Sen ne görüyorsun?')).bottom,
                  ),
                );
                expect(
                  tester.getRect(find.text('Sen ne görüyorsun?')).center.dy,
                  40,
                );
                final fit = tester.getSize(find.byTooltip('Fotoğrafı sığdır'));
                expect(fit.width, greaterThanOrEqualTo(48));
                expect(fit.height, greaterThanOrEqualTo(48));
                expect(
                  tester.getRect(
                    find.byKey(const ValueKey('coffee-photo-frame')),
                  ),
                  previewFrame,
                );
                expect(tester.getRect(find.byType(CroppedPhoto)), previewImage);
                expect(find.text('Tabaksız devam et'), findsNothing);
                await tester.pageBack();
                await tester.pumpAndSettle();
                expect(find.text('Fotoğraflarına Bak'), findsOneWidget);
                expect(
                  find.text('Bu fotoğraflarla devam et').hitTestable(),
                  findsOneWidget,
                );
              } else {
                expect(tester.widget<FilledButton>(next).onPressed, isNull);
                expect(
                  find.text('Fotoğraf ekle').hitTestable(),
                  findsOneWidget,
                );
              }
              expect(
                find.byWidgetPredicate(
                  (w) =>
                      w is Scrollable &&
                      axisDirectionToAxis(w.axisDirection) == Axis.vertical,
                ),
                findsNothing,
              );
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
