import 'dart:io';

import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_page.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  testWidgets(
    'local review creation and old media, observations, fortune and star survive without ZIP controls',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late DraftStore captures;
      late ReviewStore reviews;
      late AiStore ai;
      late ReviewSession legacy;
      late List<int> originalPhoto;
      late Map<String, List<int>> originalRevisions;
      late List<int> originalAi;
      late File oldZip;
      const stamp = '2026-09-14T00:00:00Z';
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('atlas-zip-removal-');
        captures = DraftStore(
          Directory('${root.path}/offline-contributions'),
          manualRetention: true,
        );
        reviews = ReviewStore(
          Directory('${root.path}/mvp-reviews'),
          contributionStore: captures,
        );
        ai = AiStore(Directory('${root.path}/ai-local'));
        await captures.initialize();
        await reviews.initialize();
        final imported = await reviews.importPhoto(
          testImage(),
          surface: ReviewSurface.cup,
        );
        final photo = imported.update(
          confirmedAt: stamp,
          photo: imported.photo.annotated([
            RegionAnnotation(
              id: 'old-bird',
              label: 'bird',
              box: RegionBox(.1, .2, .3, .4),
            ),
          ], PhotoDecision.marked),
        );
        legacy = ReviewSession(
          id: 'old-review',
          groupId: 'old-group',
          createdAtUtc: stamp,
          localConsentAtUtc: stamp,
          researchConsentAtUtc: stamp,
          sameSampleDeclared: true,
          photos: [photo],
        );
        await reviews.save(legacy);
        legacy = captureInitialObservations(legacy, capturedAtUtc: stamp);
        await reviews.save(legacy);
        originalPhoto = await reviews.readPhoto(photo);
        originalRevisions = {
          for (final file in await reviews.directory.list().toList())
            if (file is File && file.path.endsWith('.json'))
              file.path: await file.readAsBytes(),
        };
        await ai.saveResult({
          'id': 'old-fortune',
          'sessionId': legacy.id,
          'groupId': legacy.groupId,
          'state': 'completed',
          'answers': [
            {'text': 'Önceden kaydedilmiş fal metni.'},
          ],
        });
        await ai.setStarred('old-fortune', true);
        originalAi = await File(
          '${ai.directory.path}/state.json',
        ).readAsBytes();
        oldZip = File('${root.path}/Downloads/atlas-katki-existing.zip');
        await oldZip.parent.create();
        await oldZip.writeAsBytes([80, 75, 3, 4, 42]);
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

      Future<void> settleIo() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewHub(store: reviews, captureStore: captures),
        ),
      );
      await settleIo();
      expect(find.text('İnceleme · 2026-09-14'), findsOneWidget);
      expect(find.text('İzinli incelemeleri dışa aktar'), findsNothing);
      await tester.runAsync(() => tester.tap(find.text('Yeni inceleme')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      final start = find.widgetWithText(FilledButton, 'Başla');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(start);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settleIo();
      expect(
        find.byType(ReviewPage),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(
        find.textContaining('araştırma amaçlı dışa aktarmaya'),
        findsNothing,
      );
      expect(find.text('İncelemeyi tamamla'), findsOneWidget);
      await tester.pageBack();
      await settleIo();
      await tester.runAsync(() async {
        await tester.tap(find.text('İnceleme · 2026-09-14'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settleIo();
      expect(find.text('Gördüğüm şekilleri ekle'), findsOneWidget);
      expect(find.textContaining('Kullanıcı gözlemi:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        final all = await ReviewStore(reviews.directory).sessions();
        expect(all, hasLength(2));
        final old = all.singleWhere((s) => s.id == legacy.id);
        expect(old.toJson(), legacy.toJson());
        expect(
          all.singleWhere((s) => s.id != legacy.id).researchConsentAtUtc,
          isNull,
        );
        expect(await reviews.readPhoto(old.photos.single), originalPhoto);
        for (final entry in originalRevisions.entries) {
          expect(await File(entry.key).readAsBytes(), entry.value);
        }
        expect(
          await File('${ai.directory.path}/state.json').readAsBytes(),
          originalAi,
        );
        expect(await AiStore(ai.directory).starredIds(), {'old-fortune'});
        expect(
          (await ai.results(legacy.id)).single['answers'][0]['text'],
          'Önceden kaydedilmiş fal metni.',
        );
        expect(await oldZip.readAsBytes(), [80, 75, 3, 4, 42]);
      });
    },
  );
}
