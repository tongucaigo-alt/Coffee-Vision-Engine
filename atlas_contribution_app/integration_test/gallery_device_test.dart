import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import '../test/fixtures.dart';
import '../test/gallery_import_test.dart' show FakeGallery, galleryDraft;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated test-only gallery annotation and durable completion', (
    tester,
  ) async {
    // Never open the real offline-contributions directory in a diagnostic test.
    final root = await Directory.systemTemp.createTemp(
      'atlas-gallery-device-test-',
    );
    final store = DraftStore(root);
    final picker = FakeGallery()..selection = testImage();
    final draft = (await GalleryImport(store, picker).select(galleryDraft()))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: ContributionHome(
          store: store,
          service: OfflineContributionService(store),
          galleryPicker: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaldığın yerden devam et'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('İşaretleri gözden geçir'));
    await tester.tap(find.text('İşaretleri gözden geçir'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationPage), findsOneWidget);
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('annotation-canvas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yakınlaştır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fotoğraf'));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    final transform = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final before = transform.value.clone();
    await tester.drag(viewer, const Offset(-35, -40));
    await tester.pumpAndSettle();
    expect(transform.value, isNot(before));
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bu alanı seç'));
    await tester.tap(find.text('Bu alanı seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuş'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fotoğrafı tamamla'));
    await tester.tap(find.text('Fotoğrafı tamamla'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Telefona kaydet'));
    await tester.tap(find.text('Telefona kaydet'));
    await tester.pumpAndSettle();
    final rows = await store.receipts();
    expect(rows, hasLength(1));
    final result = ContributionDraft.fromJson(
      Map<String, dynamic>.from(rows.single['document']),
    );
    expect(result.isGallery, true);
    expect(result.photos.single.role, isNull);
    expect(result.photos.single.regions.single.label, 'bird');
    expect(await store.load(), isNull);
    expect(await store.file(draft.photos.single.localName).exists(), true);
    debugPrint(
      'ATLAS_DEVICE_GALLERY_PASS testOnly=true role=null photos=1 regions=1 label=bird',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    await root.delete(recursive: true);
  });

  testWidgets(
    'native Android photo picker returns cancellation or a valid import',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Test-only gallery picker')),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('ATLAS_NATIVE_PICKER_WAITING');
      final result = await AndroidGalleryPicker().pick();
      if (result == null) {
        debugPrint('ATLAS_NATIVE_PICKER_CANCEL_PASS');
      } else {
        final root = await Directory.systemTemp.createTemp(
          'atlas-native-gallery-test-',
        );
        final store = DraftStore(root);
        final photo = await store.importGallery(result);
        expect(photo.role, isNull);
        expect(photo.capturedAt, isNull);
        expect(photo.width, inInclusiveRange(1, 2048));
        expect(photo.height, inInclusiveRange(1, 2048));
        expect(await store.file(photo.localName).exists(), true);
        debugPrint('ATLAS_NATIVE_PICKER_IMPORT_PASS researchOnly=true');
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
