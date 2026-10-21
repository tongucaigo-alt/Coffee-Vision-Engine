import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/ai/ai_bridge.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DraftStore source;
  late ReviewStore reviews;
  late AiStore ai;
  late AiBridge bridge;
  Future<Map<String, dynamic>> record(String id) async {
    final photo = (await source.importGallery(testImage())).annotated([
      RegionAnnotation(
        id: 'mark-$id',
        label: 'bird',
        box: RegionBox(.1, .2, .3, .4),
      ),
    ], PhotoDecision.marked);
    final draft = ContributionDraft(
      id: id,
      rootId: id,
      groupId: id,
      createdAt: '2026-10-01T00:00:00Z',
      consentedAt: '2026-10-01T00:00:00Z',
      kind: ContributionKind.gallerySingle,
      photos: [photo],
    );
    final row = await OfflineContributionService(
      source,
    ).submit(draft, (p) => source.file(p.localName).readAsBytes(), (_) {});
    await source.saveReceipt(row);
    final session = await bridge.importReceipt(row);
    await ai.saveResult({
      'id': 'result-$id',
      'sessionId': session.id,
      'groupId': id,
      'state': 'completed',
      'answers': [
        {'text': 'Fal $id'},
      ],
    });
    await ai.setStarred('result-$id', true);
    return row;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-recovery-test-');
    source = DraftStore(
      Directory('${root.path}/offline-contributions'),
      manualRetention: true,
    );
    await source.initialize();
    reviews = ReviewStore(
      Directory('${root.path}/mvp-reviews'),
      contributionStore: source,
    );
    ai = AiStore(Directory('${root.path}/ai-local'));
    bridge = AiBridge(source, reviews, ai);
    reviews.onDelete = ai.deleteSession;
    source.onDeleteRoot = bridge.deleteRoot;
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'old A backup never deletes B, its marks, result or star and cannot overwrite evidence',
    () async {
      await record('A');
      final b = await record('B');
      final original = '{damaged-original';
      await source.file('receipts.json').writeAsString(original);
      final backup = await source.file('receipts.bak').readAsBytes();
      final aiBefore = await File(
        '${ai.directory.path}/state.json',
      ).readAsBytes();
      final media =
          (b['document']['photos'] as List).single['localName'] as String;
      final photoBefore = await source.file(media).readAsBytes();
      final sessionBefore = (await reviews.sessions())
          .singleWhere((s) => s.id == 'linked-B')
          .toJson();
      final snapshot = await source.receiptSnapshot();
      expect(snapshot.state, ReceiptReadState.recovered);
      expect(snapshot.rows.map((r) => r['id']), ['A']);
      await bridge.reconcile();
      for (final operation in <Future<void> Function()>[
        source.pruneExpiredReceipts,
        () => source.saveReceipt(b),
        source.clear,
        source.collectOrphans,
        () => source.queueDelete('B'),
      ]) {
        await expectLater(operation(), throwsA(isA<LocalStoreRecovery>()));
      }
      expect(await source.file('receipts.json').readAsString(), original);
      expect(await source.file('receipts.bak').readAsBytes(), backup);
      expect(await source.file(media).readAsBytes(), photoBefore);
      expect(
        (await reviews.sessions())
            .singleWhere((s) => s.id == 'linked-B')
            .toJson(),
        sessionBefore,
      );
      expect(
        await File('${ai.directory.path}/state.json').readAsBytes(),
        aiBefore,
      );
      expect(await ai.starredIds(), {'result-A', 'result-B'});
    },
  );

  test(
    'missing or doubly corrupt registry is not an empty new store',
    () async {
      await record('A');
      await source.file('receipts.json').delete();
      if (await source.file('receipts.bak').exists()) {
        await source.file('receipts.bak').delete();
      }
      expect((await source.receiptSnapshot()).state, ReceiptReadState.missing);
      await bridge.reconcile();
      await expectLater(source.receipts(), throwsA(isA<LocalStoreRecovery>()));
      await expectLater(
        source.collectOrphans(),
        throwsA(isA<LocalStoreRecovery>()),
      );
      expect(await ai.results('linked-A'), hasLength(1));
      await source.file('receipts.json').writeAsString('{');
      await source.file('receipts.bak').writeAsString('[]');
      expect(
        (await source.receiptSnapshot()).state,
        ReceiptReadState.unreadable,
      );
      await expectLater(
        source.pruneExpiredReceipts(),
        throwsA(isA<LocalStoreRecovery>()),
      );
      expect(await source.file('receipts.json').readAsString(), '{');
      expect(await source.file('receipts.bak').readAsString(), '[]');
    },
  );

  test(
    'separate online store does not inherit the offline AI registry',
    () async {
      await record('A');
      final before = await source.file('receipts.json').readAsBytes();
      final online = DraftStore(Directory('${root.path}/contributions'));
      await online.initialize();
      await online.saveReceipt({
        'id': 'cloud',
        'root_id': 'cloud',
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
      });
      expect((await online.receipts()).single['id'], 'cloud');
      expect(await source.file('receipts.json').readAsBytes(), before);
      expect(await ai.results('linked-A'), hasLength(1));
    },
  );
  test(
    'healthy-list absence is not delete intent; explicit deletion still works',
    () async {
      final a = await record('A');
      final b = await record('B');
      await source
          .file('receipts.json')
          .writeAsString(
            jsonEncode({
              'rows': [a],
            }),
          );
      await bridge.reconcile();
      expect(await ai.results('linked-B'), hasLength(1));
      await expectLater(
        source.collectOrphans(),
        throwsA(isA<LocalStoreRecovery>()),
      );
      await source
          .file('receipts.json')
          .writeAsString(
            jsonEncode({
              'rows': [a, b],
            }),
          );
      await expectLater(
        source.acknowledgeDelete('A'),
        throwsA(isA<LocalStoreRecovery>()),
      );
      await source.queueDelete('A');
      await source.acknowledgeDelete('A');
      await source.collectOrphans();
      expect(await ai.results('linked-A'), isEmpty);
      expect(await ai.results('linked-B'), hasLength(1));
      expect(await ai.starredIds(), {'result-B'});
      expect((await source.receipts()).single['id'], 'B');
    },
  );
}
