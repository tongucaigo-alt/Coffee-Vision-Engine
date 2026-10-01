import 'suitability_fixture.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'fixtures.dart';

class MemoryStore extends DraftStore {
  bool accepted = false;
  @override
  Future<bool> hasLocalAcceptance() async => accepted;
  @override
  Future<void> acceptLocalUse() async {
    accepted = true;
  }

  MemoryStore(super.directory, this.draft);
  ContributionDraft? draft;
  final rows = <Map<String, dynamic>>[];
  @override
  Future<ContributionDraft?> load() async => draft;
  @override
  Future<void> save(ContributionDraft d) async {
    draft = d;
  }

  @override
  Future<void> clear() async {
    draft = null;
  }

  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async => rows;
  @override
  Future<void> saveReceipt(Map<String, dynamic> row) async {
    rows.removeWhere((r) => r['id'] == row['id']);
    rows.add(row);
  }
}

class PausedService extends OfflineContributionService {
  PausedService(super.store);
  Completer<void>? pause;
  bool fail = false;
  int submissions = 0;
  @override
  Future<Map<String, dynamic>> submit(
    ContributionDraft d,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int) progress,
  ) async {
    submissions++;
    await pause?.future;
    if (fail) throw StateError('synthetic save failure');
    return {
      'id': d.id,
      'root_id': d.rootId,
      'local_only': true,
      'document': d.toJson(),
    };
  }
}

void main() {
  for (final scenario in ['ready', 'analysisFailure', 'saveFailure']) {
    final analysisFails = scenario == 'analysisFailure';
    final saveFailsFirst = scenario == 'saveFailure';
    testWidgets(
      'save then analysis reports distinct stages; scenario=$scenario',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory dir;
        late MemoryStore store;
        await tester.runAsync(() async {
          dir = await Directory.systemTemp.createTemp('atlas-save-state-');
          final b = testDraft();
          final d = ContributionDraft(
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
          store = MemoryStore(dir, d);
          for (final p in d.photos) {
            await store.file(p.localName).writeAsBytes(testImage());
          }
        });
        final service = PausedService(store)
          ..pause = Completer<void>()
          ..fail = saveFailsFirst;
        final analysis = Completer<RecordPreparationStatus>();
        await tester.pumpWidget(
          MaterialApp(
            home: ContributionHome(
              photoSuitability: SupportedSuitability(),
              modern: true,
              store: store,
              service: service,
              onRecorded: (_) async {},
              onConfirmedRecorded: (_, _) => analysis.future,
              onReadFortune: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kaldığın Yerden Devam Et'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 1; i++) {
          await tester.ensureVisible(find.byType(CheckboxListTile).at(i));
          await tester.tap(find.byType(CheckboxListTile).at(i));
          await tester.pump();
        }
        await tester.tap(find.text('İşaretleri Gözden Geçir'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Gözlemleri Kaydet'));
        await tester.tap(find.text('Gözlemleri Kaydet'));
        await tester.pump();
        expect(find.text('Kaydediliyor…'), findsWidgets);
        expect(find.text('Kaydı Yeniden Dene'), findsNothing);
        service.pause!.complete();
        await tester.pump();
        await tester.pump();
        if (saveFailsFirst) {
          await tester.pumpAndSettle();
          expect(store.rows, isEmpty);
          expect(find.text('Kaydı Yeniden Dene'), findsOneWidget);
          service.fail = false;
          await tester.tap(find.text('Kaydı Yeniden Dene'));
          await tester.pump();
          await tester.pump();
        }
        expect(store.rows, hasLength(1));
        expect(find.text('Telve inceleniyor…'), findsWidgets);
        expect(service.submissions, saveFailsFirst ? 2 : 1);
        if (analysisFails) {
          analysis.completeError(StateError('synthetic analysis failure'));
        } else {
          analysis.complete(RecordPreparationStatus.ready);
        }
        await tester.pumpAndSettle();
        expect(find.text('Kayıt tamamlandı'), findsNothing);
        expect(
          find.textContaining(
            analysisFails
                ? 'analiz tamamlanamadı'
                : 'telve incelemesi tamamlandı',
          ),
          findsWidgets,
        );
        expect(find.text('Kaydı Yeniden Dene'), findsNothing);
        expect(store.rows, hasLength(1));
        expect(service.submissions, saveFailsFirst ? 2 : 1);
        expect(store.draft, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => dir.delete(recursive: true));
      },
    );
  }
}
