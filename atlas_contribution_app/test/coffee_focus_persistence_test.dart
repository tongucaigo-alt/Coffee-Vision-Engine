import 'dart:io';

import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/annotation_sequence.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'fixtures.dart';
import 'suitability_fixture.dart';

void main() {
  for (final failLoad in [false, true]) {
    testWidgets(
      'home restores focus before annotation and keeps it through generation; read failure=$failLoad',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 2800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        late MemoryStore store;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp(
            'atlas-focus-preference-',
          );
          final base = testDraft();
          final draft = ContributionDraft(
            id: base.id,
            rootId: base.rootId,
            groupId: base.groupId,
            createdAt: base.createdAt,
            consentedAt: base.consentedAt,
            kind: ContributionKind.freeThreeAngle,
            photos: [
              for (final role in freeCaptureRoles)
                testPhoto(role, decision: PhotoDecision.skipped),
            ],
          );
          store = MemoryStore(directory, draft)..accepted = true;
          for (final photo in draft.photos) {
            await store.file(photo.localName).writeAsBytes(testImage());
          }
        });
        addTearDown(() => directory.delete(recursive: true));
        var stored = 'work';
        var reads = 0, writes = 0, calls = 0;
        final rootId = store.draft!.rootId;
        final before = store.draft!.photos.map((p) => p.toJson()).toList();
        await tester.pumpWidget(
          MaterialApp(
            theme: atlasTheme(),
            home: ContributionHome(
              modern: true,
              store: store,
              service: PausedService(store),
              photoSuitability: SupportedSuitability(),
              loadReadingFocus: (id) async {
                expect(id, rootId);
                reads++;
                if (failLoad) {
                  throw StateError('synthetic preference read failure');
                }
                return stored;
              },
              onReadingFocusChanged: (id, focus) async {
                expect(id, rootId);
                writes++;
                stored = focus;
              },
              onGenerateFortune: (row) async {
                expect(row['root_id'], rootId);
                expect(stored, 'money');
                calls++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('İşaretleri Gözden Geçir'));
        await tester.pumpAndSettle();
        expect(reads, 1);
        if (failLoad) {
          expect(find.byType(AnnotationSequence), findsNothing);
          expect(
            find.text('Konu seçimin okunamadı. Yeniden deneyebilirsin.'),
            findsOneWidget,
          );
          expect(writes, 0);
          expect(calls, 0);
          expect(store.draft!.photos.map((p) => p.toJson()).toList(), before);
          return;
        }
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          'İş',
        );
        await tester.tap(find.byKey(const ValueKey('coffee-focus-Para')));
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(calls, 0);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('İşaretleri Gözden Geçir'));
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          'Para',
        );
        await tester.tap(find.text('Falımı Oluştur').last);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(store.rows, hasLength(1));
        expect((store.rows.single['document'] as Map)['photos'], before);
        expect(
          (store.rows.single['document'] as Map).containsKey('focus'),
          false,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
