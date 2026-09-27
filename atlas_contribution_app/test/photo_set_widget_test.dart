import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;

void main() {
  for (final count in [1, 4]) {
    for (final auto in [false, true]) {
      testWidgets('gallery $count-image set saves; automatic fortune=$auto', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory root;
        late MemoryStore store;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('atlas-set-ui-');
          store = MemoryStore(root, setDraft());
          var draft = store.draft!;
          for (var i = 0; i < count; i++) {
            final p = await store.importGallery(setImage(i));
            draft = draft.withPhoto(
              p.asSetPhoto(
                type: i == 3 ? PhotoSurface.saucer : PhotoSurface.cup,
              ),
            );
          }
          store.draft = draft.copy(
            cupSelectionDone: count == 4,
            saucerDecided: count == 4,
          );
        });
        final service = PausedService(store);
        var opens = 0;
        Set<String>? confirmed;
        await tester.pumpWidget(
          MaterialApp(
            home: ContributionHome(
              modern: true,
              store: store,
              service: service,
              onRecorded: (_) async {},
              onConfirmedRecorded: (_, ids) async {
                confirmed = ids;
                return RecordPreparationStatus.ready;
              },
              aiDescription: () async => 'Test bağlantısı',
              onGenerateFortune: (_) async {
                opens++;
              },
              onReadFortune: (_) async {
                opens++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kaldığın Yerden Devam Et'));
        await tester.pumpAndSettle();
        if (count == 1) {
          await tester.ensureVisible(find.text('Bu fotoğraflarla devam et'));
          await tester.tap(find.text('Bu fotoğraflarla devam et'));
          await tester.pumpAndSettle();
          expect(
            find.text('Tabak fotoğrafı da eklemek ister misin?'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Tabaksız devam et'));
          await tester.tap(find.text('Tabaksız devam et'));
          await tester.pumpAndSettle();
          expect(find.byType(CheckboxListTile), findsOneWidget);
        } else {
          expect(find.text('3 fincan · 1 tabak'), findsOneWidget);
          expect(find.byType(CheckboxListTile), findsNWidgets(5));
        }
        for (var i = 0; i < (count == 1 ? 1 : 5); i++) {
          final check = find.byType(CheckboxListTile).at(i);
          await tester.ensureVisible(check);
          await tester.tap(check);
          await tester.pump();
        }
        await tester.ensureVisible(
          find.text('Fotoğrafları Onayla · Şekilleri İncele'),
        );
        await tester.tap(find.text('Fotoğrafları Onayla · Şekilleri İncele'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Atla'));
        await tester.pumpAndSettle();
        expect(
          store.draft!.photos.every((p) => p.decision == PhotoDecision.skipped),
          true,
        );
        final action = find.text(
          auto ? 'Kaydet ve Falını Oluştur' : 'Yalnız Kaydet',
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.tap(
          action,
        ); // A rapid repeat must not duplicate a receipt/request.
        await tester.pumpAndSettle();
        expect(store.rows, hasLength(1));
        expect(confirmed, hasLength(count));
        expect(opens, auto ? 1 : 0);
        expect(store.draft, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(() => root.delete(recursive: true));
      });
    }
  }
}
