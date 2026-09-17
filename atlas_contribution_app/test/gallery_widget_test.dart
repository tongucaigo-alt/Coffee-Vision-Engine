import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'fixtures.dart';
import 'gallery_import_test.dart' show FakeGallery, galleryDraft;

// Real disk transactions are covered separately; widget tests use memory I/O.
class MemoryStore extends DraftStore {
  MemoryStore(this.current) : super(Directory('test-unused-gallery-store'));
  ContributionDraft? current;
  final rows = <Map<String, dynamic>>[];
  @override
  Future<ContributionDraft?> load() async => current;
  @override
  Future<void> save(ContributionDraft draft) async {
    current = draft;
  }

  @override
  Future<void> clear() async {
    current = null;
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
    rows.add(row);
  }
}

class WidgetBackend extends OfflineContributionService {
  WidgetBackend(super.store);
  @override
  Future<Map<String, dynamic>> submit(
    ContributionDraft draft,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int) progress,
  ) async {
    if (!draft.reviewed) throw StateError('Not reviewed');
    return {
      'id': draft.id,
      'root_id': draft.rootId,
      'local_only': true,
      'document': draft.toJson(),
    };
  }
}

void main() {
  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'single gallery review and local completion $size text $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = ContributionPhoto(
            role: null,
            localName: 'test.jpg',
            checksum: 'sha256:${'a' * 64}',
            originalChecksum: 'sha256:${'b' * 64}',
            width: 160,
            height: 200,
            byteLength: 1000,
            capturedAt: null,
            importedAt: DateTime.now().toUtc().toIso8601String(),
            decision: PhotoDecision.skipped,
          );
          final store = MemoryStore(galleryDraft().withPhoto(p));
          await tester.pumpWidget(
            MaterialApp(
              theme: contributionTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ContributionHome(
                store: store,
                service: WidgetBackend(store),
                galleryPicker: FakeGallery(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Kaldığın yerden devam et'));
          await tester.tap(find.text('Kaldığın yerden devam et'));
          await tester.pumpAndSettle();
          expect(find.text('1 / 1 fotoğraf hazır'), findsOneWidget);
          expect(find.text('Üst açı çek'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Telefona kaydet'));
          await tester.tap(find.text('Telefona kaydet'));
          await tester.pumpAndSettle();
          expect(store.current, isNull);
          expect(store.rows, hasLength(1));
          expect(store.rows.single['document']['kind'], 'gallerySingle');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('gallery request cannot silently overwrite camera draft', (
    tester,
  ) async {
    final camera = testDraft(photos: [testPhoto(CaptureRole.top)]);
    final store = MemoryStore(camera);
    final picker = FakeGallery();
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: ContributionHome(
          store: store,
          service: WidgetBackend(store),
          galleryPicker: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeriden fotoğraf seç'));
    await tester.pumpAndSettle();
    expect(find.text('Yarım kalan çalışman var'), findsOneWidget);
    await tester.tap(find.text('Çalışmaya dön'));
    await tester.pumpAndSettle();
    expect(picker.calls, 0);
    expect(store.current, same(camera));
  });
}
