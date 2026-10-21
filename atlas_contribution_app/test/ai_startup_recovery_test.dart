import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/ai/ai_recovery_page.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'coffee_guide_fixture.dart';
import 'fixtures.dart';

void main() {
  for (final fault in ['json', 'write']) {
    testWidgets(
      'AI $fault failure opens read-only recovery and retry preserves data',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory root;
        late DraftStore source;
        late AiStore ai;
        late List<int> originalAi, originalReceipts, originalPhoto;
        late ContributionDraft draft;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp(
            'atlas-startup-failure-',
          );
          source = DraftStore(
            Directory('${root.path}/offline-contributions'),
            manualRetention: true,
          );
          await source.initialize();
          final photo = (await source.importGallery(testImage())).annotated([
            RegionAnnotation(
              id: 'kept-mark',
              label: 'bird',
              box: RegionBox(.1, .1, .3, .3),
            ),
          ], PhotoDecision.marked);
          draft = ContributionDraft(
            id: 'kept',
            rootId: 'kept',
            groupId: 'kept',
            createdAt: '2026-10-01T00:00:00Z',
            consentedAt: '2026-10-01T00:00:00Z',
            kind: ContributionKind.gallerySingle,
            photos: [photo],
          );
          await source.saveReceipt(
            await OfflineContributionService(source).submit(
              draft,
              (p) => source.file(p.localName).readAsBytes(),
              (_) {},
            ),
          );
          originalReceipts = await source.file('receipts.json').readAsBytes();
          originalPhoto = await source.file(photo.localName).readAsBytes();
          ai = AiStore(Directory('${root.path}/ai-local'));
          await ai.saveResult({
            'id': 'kept-fortune',
            'sessionId': 'kept-session',
            'state': 'completed',
            'answers': [
              {'text': 'Korunacak fal'},
            ],
          });
          await ai.setStarred('kept-fortune', true);
          originalAi = await File(
            '${ai.directory.path}/state.json',
          ).readAsBytes();
          if (fault == 'json') {
            await File(
              '${ai.directory.path}/state.json',
            ).writeAsString('{broken');
          } else {
            await Directory('${ai.directory.path}/state.pending').create();
          }
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            await root.delete(recursive: true);
          });
        });
        var tarotStarts = 0, aiStarts = 0;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            OfflineStartupApp(
              store: source,
              aiEnabled: true,
              guideStore: DismissedGuideStore(),
              createAi: (s) {
                aiStarts++;
                return AiRuntime.create(s, readKey: (_) async => '');
              },
              createTarot: (_, runtime) async {
                tarotStarts++;
                throw StateError('synthetic tarot setup');
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        Future<void> settleIo() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(() async {
              await tester.pump(const Duration(milliseconds: 20));
              await Future<void>.delayed(const Duration(milliseconds: 20));
            });
          }
          await tester.pumpAndSettle();
        }

        await settleIo();
        expect(find.byType(AiRecoveryPage), findsOneWidget);
        expect(find.text('Atlas · Kayıt kurtarma'), findsOneWidget);
        expect(find.text('Kayıt · 2026-10-01'), findsOneWidget);
        expect(find.text('Fal Oluştur'), findsNothing);
        expect(source.onDeleteRoot, isNull);
        expect(aiStarts, 1);
        expect(tarotStarts, 1);
        await tester.runAsync(() async {
          await expectLater(
            source.queueDelete('kept'),
            throwsA(isA<LocalStoreRecovery>()),
          );
          expect(
            await source.file('receipts.json').readAsBytes(),
            originalReceipts,
          );
          expect(
            await source.file(draft.photos.single.localName).readAsBytes(),
            originalPhoto,
          );
          if (fault == 'json') {
            expect(
              await File('${ai.directory.path}/state.json').readAsString(),
              '{broken',
            );
            await File(
              '${ai.directory.path}/state.json',
            ).writeAsBytes(originalAi);
          } else {
            expect(
              await File('${ai.directory.path}/state.json').readAsBytes(),
              originalAi,
            );
            await Directory('${ai.directory.path}/state.pending').delete();
          }
          await tester.tap(find.text('Yeniden Dene'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await settleIo();
        expect(find.byType(AiRecoveryPage), findsNothing);
        expect(find.byType(ContributionHome), findsOneWidget);
        expect(aiStarts, 2);
        expect(source.readOnlyReason, isNull);
        await tester.runAsync(() async {
          expect(await ai.starredIds(), {'kept-fortune'});
          expect(
            (await ai.results('kept-session')).single['answers'][0]['text'],
            'Korunacak fal',
          );
          expect(
            await source.file(draft.photos.single.localName).readAsBytes(),
            originalPhoto,
          );
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
