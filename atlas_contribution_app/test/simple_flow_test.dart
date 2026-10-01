import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'fixtures.dart';
import 'package:atlas_contribution_app/src/models.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-simple-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'twenty stars persist, rapid twenty-first fails and deletion frees space',
    () async {
      final store = AiStore(root);
      for (var i = 0; i < 21; i++) {
        await store.saveResult({
          'id': 'r$i',
          'sessionId': 's$i',
          'state': 'completed',
          'answers': [
            {'text': 'test'},
          ],
        });
      }
      await Future.wait([
        for (var i = 0; i < 20; i++) store.setStarred('r$i', true),
      ]);
      await expectLater(
        store.setStarred('r20', true),
        throwsA(isA<AiFailure>()),
      );
      expect(await AiStore(root).starredIds(), hasLength(20));
      await store.saveResult({
        'id': 'new-revision',
        'sessionId': 's0',
        'state': 'completed',
        'answers': [
          {'text': 'new'},
        ],
      });
      expect((await store.starredIds()).contains('new-revision'), isFalse);
      await store.deleteSession('s0');
      expect((await store.starredIds()).contains('r0'), isFalse);
      await store.setStarred('r20', true);
      expect(await store.starredIds(), hasLength(20));
      await store.setStarred('r20', false);
      expect(await store.starredIds(), hasLength(19));
    },
  );
  test(
    'manual retention preserves old local draft and receipts but not expired online records',
    () async {
      final store = DraftStore(root, manualRetention: true);
      await store.initialize();
      final d = testDraft().toJson()..['consentedAt'] = '2000-01-01T00:00:00Z';
      await store.file('draft.json').writeAsString(jsonEncode({'draft': d}));
      expect(await store.load(), isNotNull);
      await store.saveReceipt({
        'id': 'local',
        'root_id': 'local',
        'local_only': true,
        'expires_at': '2000-01-01T00:00:00Z',
        'document': d,
      });
      await store.saveReceipt({
        'id': 'online',
        'root_id': 'online',
        'expires_at': '2000-01-01T00:00:00Z',
      });
      await store.pruneExpiredReceipts();
      expect((await store.receipts()).single['id'], 'local');
      expect(await store.hasLocalAcceptance(), isFalse);
      await store.acceptLocalUse();
      expect(await DraftStore(root).hasLocalAcceptance(), isTrue);
      final reviews = ReviewStore(
        Directory('${root.path}/reviews'),
        contributionStore: store,
      );
      await reviews.initialize();
      await store.saveReceipt({
        'id': 'new',
        'root_id': 'new',
        'local_only': true,
        'localUseVersion': DraftStore.localAcceptanceVersion,
        'document': d,
      });
      expect(await reviews.blockedContributionRoots(), contains('new'));
      expect(
        await reviews.blockedContributionRoots(),
        isNot(contains('local')),
      );
    },
  );
  test('legacy continue decision cannot bypass a technical failure', () async {
    final checker = PhotoSuitability(Directory('${root.path}/suitability'));
    final p = testPhoto(CaptureRole.free);
    final file = File('${root.path}/missing.jpg');
    final error = await checker.assess(file, p);
    expect(error['status'], 'error');
    expect(suitabilityAccepted(error, p), isFalse);
    final acknowledged = await checker.continueWith(p, error);
    final reopened = await PhotoSuitability(checker.directory).assess(file, p);
    expect(reopened['continuedAtUtc'], acknowledged['continuedAtUtc']);
    expect(suitabilityAccepted(reopened, p), isFalse);
    expect(
      suitabilityAccepted({...reopened, 'version': 'old-model'}, p),
      isFalse,
    );
  });
  test(
    'two-view conservative rule distinguishes uncertainty from rejection',
    () {
      Map<String, dynamic> row(String label, double score) => {
        'label': label,
        'score': score,
      };
      final key = row('computer keyboard', .95);
      expect(
        classifySuitability({
          'full': [key],
          'crop': [key],
        }),
        'unsuitable',
      );
      expect(
        classifySuitability({
          'full': [key],
          'crop': [row('mouse', .95)],
        }),
        'uncertain',
      );
      expect(
        classifySuitability({
          'full': [key, row('cup', .02)],
          'crop': [key],
        }),
        'uncertain',
      );
      expect(
        classifySuitability({
          'full': [row('computer keyboard', .89)],
          'crop': [key],
        }),
        'uncertain',
      );
      expect(suitabilityBlockingValidated, isFalse);
    },
  );
}
