import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bridge.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/ai/local_performance_probe.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'fixtures.dart';

void main() {
  test(
    'diagnostic measurement requires an explicit marker and preserves stored records',
    () async {
      final temp = await Directory.systemTemp.createTemp('atlas-probe-');
      addTearDown(() => temp.delete(recursive: true));
      final source = DraftStore(
        Directory('${temp.path}/offline-contributions'),
        manualRetention: true,
      );
      await source.initialize();
      final ai = AiStore(Directory('${temp.path}/ai-local'));
      final reviews = ReviewStore(
        Directory('${temp.path}/mvp-reviews'),
        contributionStore: source,
      );
      final bridge = AiBridge(source, reviews, ai);
      final result = File(
        '${ai.directory.path}/atlas-v120-local-performance.result.json',
      );
      await runRequestedLocalPerformanceProbe(bridge);
      expect(await result.exists(), isFalse);
      final photo = ContributionPhoto.fromJson({
        ...testPhoto(
          CaptureRole.free,
          decision: PhotoDecision.skipped,
        ).toJson(),
        'role': null,
        'capturedAt': null,
        'origin': 'gallery',
        'importedAtUtc': '2026-10-30T00:00:00Z',
      });
      final draft = ContributionDraft(
        id: 'receipt',
        rootId: 'root',
        groupId: 'group',
        createdAt: '2026-10-30T00:00:00Z',
        consentedAt: '2026-10-30T00:00:00Z',
        kind: ContributionKind.gallerySingle,
        photos: [photo],
      );
      await source.saveReceipt({
        'root_id': 'root',
        'local_only': true,
        'document': draft.toJson(),
      });
      await reviews.initialize();
      final first = ReviewSession(
        id: 'linked-root',
        groupId: 'group',
        createdAtUtc: '2026-10-30T00:00:00Z',
        localConsentAtUtc: '2026-10-30T00:00:00Z',
        sameSampleDeclared: true,
        photos: [
          ReviewPhoto(
            id: 'p',
            photo: photo,
            surface: ReviewSurface.cup,
            usableConfirmedAtUtc: '2026-10-30T00:00:00Z',
          ),
        ],
      );
      final captured = captureInitialObservations(
        first,
        capturedAtUtc: '2026-10-30T00:00:00Z',
      );
      final prepared = captured.next(
        preparedInput: prepareReviewInput(
          captured,
          preparedAtUtc: '2026-10-30T00:00:00Z',
        ),
      );
      final document = prepared.toJson();
      // Publish the immutable fixture directly; the probe never reads photo bytes.
      // Use the normal envelope checksum through the helper below.
      await writeFixture(reviews, prepared, document);
      await ai.change((data) {
        (data['links'] as Map)['root'] = {'receiptId': 'receipt'};
      });
      final marker = File(
        '${ai.directory.path}/atlas-v120-local-performance.request',
      );
      await marker.writeAsString('not-authorized');
      await runRequestedLocalPerformanceProbe(bridge);
      expect(await result.exists(), isFalse);
      final beforeAi = await File(
        '${ai.directory.path}/state.json',
      ).readAsBytes();
      final beforeReview = await reviews
          .file('review-linked-root-${prepared.revision}.json')
          .readAsBytes();
      final beforeReceipts = await source.file('receipts.json').readAsBytes();
      await marker.writeAsString('atlas-v120-local-check');
      await runRequestedLocalPerformanceProbe(bridge);
      final metrics = jsonDecode(await result.readAsString()) as Map;
      expect(metrics['status'], 'measured');
      expect(metrics['providerCalls'], 0);
      expect(metrics['sourceCurrentUs'], hasLength(3));
      expect(
        await File('${ai.directory.path}/state.json').readAsBytes(),
        beforeAi,
      );
      expect(await source.file('receipts.json').readAsBytes(), beforeReceipts);
      expect(
        await reviews
            .file('review-linked-root-${prepared.revision}.json')
            .readAsBytes(),
        beforeReview,
      );
      expect((await result.readAsString()).contains('linked-root'), isFalse);
      final once = await result.readAsString();
      await runRequestedLocalPerformanceProbe(bridge);
      expect(await result.readAsString(), once);
    },
  );
}

Future<void> writeFixture(
  ReviewStore store,
  ReviewSession session,
  Map<String, dynamic> document,
) => store
    .file('review-${session.id}-${session.revision}.json')
    .writeAsString(
      jsonEncode({
        'document': document,
        'checksum':
            'sha256:${sha256.convert(utf8.encode(jsonEncode(document)))}',
      }),
    )
    .then((_) {});
