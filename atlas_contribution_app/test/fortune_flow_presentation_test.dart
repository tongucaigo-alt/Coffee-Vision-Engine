import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'fixtures.dart';
import 'suitability_fixture.dart';

void main() {
  for (final mode in [
    'complete',
    'cancelAnalysis',
    'saveFailure',
    'onlySave',
  ]) {
    testWidgets('actual save flow shares presentation: $mode', (tester) async {
      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory dir;
      late MemoryStore store;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('atlas-presentation-');
        final b = testDraft();
        final draft = ContributionDraft(
          id: b.id,
          rootId: b.rootId,
          groupId: b.groupId,
          createdAt: b.createdAt,
          consentedAt: b.consentedAt,
          kind: ContributionKind.freeThreeAngle,
          photos: [
            for (final r in freeCaptureRoles)
              testPhoto(r, decision: PhotoDecision.skipped),
          ],
        );
        store = MemoryStore(dir, draft);
        for (final p in draft.photos) {
          await store.file(p.localName).writeAsBytes(testImage());
        }
      });
      final service = PausedService(store)
        ..pause = Completer<void>()
        ..fail = mode == 'saveFailure';
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.saving),
      );
      final flow = FortunePreparationController(progress);
      final analysis = Completer<RecordPreparationStatus>();
      final ai = Completer<void>();
      final navigator = GlobalKey<NavigatorState>();
      var generations = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) =>
              FortunePreparationHost(controller: flow, child: child!),
          home: ContributionHome(
            modern: true,
            store: store,
            service: service,
            photoSuitability: SupportedSuitability(),
            preparation: flow,
            fortuneProgress: progress,
            aiDescription: () async => 'test',
            onRecorded: (_) async {},
            onConfirmedRecorded: (_, _) {
              progress.value = const FortuneProgress(
                FortunePhase.analyzing,
                photoId: 'free.jpg',
              );
              return analysis.future;
            },
            onGenerateFortune: (row) async {
              generations++;
              expectSync(store.rows, hasLength(1));
              final draft = ContributionDraft.fromJson(
                Map<String, dynamic>.from(row['document'] as Map),
              );
              flow.begin(
                photos: draft.photos,
                imageFor: (p) => FileImage(store.file(p.localName)),
                onCancel: () {},
              );
              progress.value = const FortuneProgress(FortunePhase.generating);
              unawaited(
                navigator.currentState!.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('saved result')),
                  ),
                ),
              );
              await ai.future;
              flow.finish();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaldığın Yerden Devam Et'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      final button = find.text(
        mode == 'onlySave' ? 'Yalnız Kaydet' : 'Kaydet ve Falını Oluştur',
      );
      await tester.ensureVisible(button);
      // Two invocations before the rebuild must still submit only once.
      final callback = mode == 'onlySave'
          ? tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Yalnız Kaydet'),
                )
                .onPressed!
          : tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Kaydet ve Falını Oluştur'),
                )
                .onPressed!;
      callback();
      callback();
      await tester.pump();
      await tester.pump();
      final scanState = mode == 'onlySave'
          ? null
          : tester.state(find.byKey(const ValueKey('continuous-fortune-scan')));
      if (scanState != null) {
        expect(find.byType(FortuneScan), findsOneWidget);
        expect(
          tester
              .widget<FortuneScan>(find.byType(FortuneScan))
              .showDecorativeSymbols,
          isTrue,
        );
      }
      service.pause!.complete();
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      if (mode == 'saveFailure') {
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Kayıt tamamlanamadı'), findsOneWidget);
        expect(store.draft, isNotNull);
        expect(store.rows, isEmpty);
        expect(generations, 0);
        await tester.tap(find.text('Tamam'));
      } else {
        expect(store.rows, hasLength(1));
        expect(generations, 0);
        if (mode == 'cancelAnalysis') flow.cancel();
        analysis.complete(RecordPreparationStatus.ready);
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }
        if (mode == 'complete') {
          await tester.pump(const Duration(milliseconds: 500));
          expect(generations, 1);
          expect(tester.state(find.byType(FortuneScan)), same(scanState));
          expect(
            tester.widget<FortuneScan>(find.byType(FortuneScan)).photos,
            hasLength(3),
          );
          expect(store.draft, isNull);
          ai.complete();
          await tester.pumpAndSettle();
          expect(find.text('saved result'), findsOneWidget);
        } else {
          await tester.pumpAndSettle();
          expect(generations, 0);
          expect(store.rows, hasLength(1));
        }
      }
      expect(service.submissions, 1);
      expect(flow.active, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
      flow.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });
  }
}
