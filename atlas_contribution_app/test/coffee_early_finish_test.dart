import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;
import 'fixtures.dart';
import 'suitability_fixture.dart';

class _Store extends MemoryStore {
  _Store(super.directory, super.draft);
  @override
  Future<void> collectOrphans() async {}
  @override
  Future<void> releaseCapture(CameraCaptureResult capture) async {}
}

void main() {
  test(
    'early completion is optional and never accepts an empty camera set',
    () {
      final old = setDraft(gallery: false).toJson();
      expect(ContributionDraft.fromJson(old).captureSequenceFinished, false);
      expect(
        setDraft(
          gallery: false,
        ).copy(captureSequenceFinished: true).cupsComplete,
        false,
      );
      for (final count in [1, 2]) {
        var draft = setDraft(gallery: false);
        for (final role in freeCaptureRoles.take(count)) {
          draft = draft.withPhoto(
            testPhoto(
              role,
              decision: PhotoDecision.skipped,
            ).asSetPhoto(angle: role),
          );
        }
        expect(draft.complete, false);
        final done = draft.copy(
          captureSequenceFinished: true,
          cupSelectionDone: true,
          saucerDecided: true,
        );
        final restored = ContributionDraft.fromJson(done.toJson());
        expect(restored.reviewed, true);
        expect(restored.isGallery, false);
        expect(restored.photos.every((p) => p.origin == 'camera'), true);
      }
    },
  );
  for (final count in [1, 2]) {
    testWidgets(
      'finish after $count, reopen, add remaining angles and save once',
      (tester) async {
        tester.view.physicalSize = const Size(412, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory root;
        late _Store store;
        late List<CameraCaptureResult> captures;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('atlas-v63-early-');
          store = _Store(root, setDraft(gallery: false));
          captures = [];
          for (var i = 0; i < 3; i++) {
            final bytes = setImage(i);
            final file = File('${root.path}/capture-$i.png');
            await file.writeAsBytes(bytes);
            captures.add(
              CameraCaptureResult(
                filePath: file.path,
                croppedCupPath: file.path,
                cropRect: const Rect.fromLTWH(0, 0, 160, 200),
                widthPixels: 160,
                heightPixels: 200,
                fileSizeBytes: bytes.length,
                croppedWidthPixels: 160,
                croppedHeightPixels: 200,
                croppedFileSizeBytes: bytes.length,
                capturedAt: DateTime.now().toUtc(),
                qualityScore: 80,
                coffeePresenceScore: .8,
                coffeeDetected: true,
                mode: CameraCaptureMode.manual,
              ),
            );
          }
        });
        final service = PausedService(store);
        var finish = true;
        var calls = 0;
        Future<void> mount() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: atlasTheme(),
              home: ContributionHome(
                modern: true,
                store: store,
                service: service,
                photoSuitability: SupportedSuitability(),
                cameraLauncher:
                    (
                      _, {
                      required config,
                      required captureTitle,
                      required captureInstruction,
                      onFinishSequence,
                    }) async {
                      calls++;
                      if (store.draft!.cups.length == count && finish) {
                        expect(onFinishSequence, isNotNull);
                        await onFinishSequence!();
                        return null;
                      }
                      if (store.draft!.cups.isEmpty) {
                        expect(onFinishSequence, isNull);
                      }
                      return captures[store.draft!.cups.length];
                    },
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> drain() async {
          for (var i = 0; i < 200; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
          }
          await tester.pumpAndSettle();
        }

        await mount();
        await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
        await drain();
        expect(store.draft!.cups, hasLength(count));
        expect(store.draft!.captureSequenceFinished, true);
        expect(store.draft!.isGallery, false);
        final saved = store.draft!.photos.map((p) => p.toJson()).toList();
        await tester.tap(find.text('Bu fotoğraflarla devam et'));
        await tester.pumpAndSettle();
        expect(find.text('Sen ne görüyorsun?'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await mount();
        final before = calls;
        await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
        await tester.pumpAndSettle();
        expect(calls, before);
        finish = false;
        await tester.tap(find.text('Fotoğraf ekle'));
        await drain();
        expect(store.draft!.cups, hasLength(3));
        expect(store.draft!.captureSequenceFinished, false);
        expect(
          store.draft!.photos.take(count).map((p) => p.toJson()).toList(),
          saved,
        );
        await tester.tap(find.text('Bu fotoğraflarla devam et'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yalnız Kaydet'));
        await tester.pumpAndSettle();
        expect(service.submissions, 1);
        expect(store.rows, hasLength(1));
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
}
