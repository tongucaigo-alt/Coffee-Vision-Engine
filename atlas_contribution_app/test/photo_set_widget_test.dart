import 'suitability_fixture.dart';
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
              photoSuitability: SupportedSuitability(),
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
        await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
        await tester.pumpAndSettle();
        expect(find.text('Tabaksız devam et'), findsNothing);
        expect(find.byType(CheckboxListTile), findsNothing);
        await tester.ensureVisible(find.text('Bu fotoğraflarla devam et'));
        await tester.tap(find.text('Bu fotoğraflarla devam et'));
        await tester.pumpAndSettle();
        final action = find.text(auto ? 'Falımı Oluştur' : 'Yalnız Kaydet');
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
