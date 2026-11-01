import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bridge.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';

void main() {
  test(
    '263 synthetic historical revisions approximate the phone metadata workload',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'atlas-large-history-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final source = DraftStore(
        Directory('${temp.path}/offline-contributions'),
        manualRetention: true,
      );
      await source.initialize();
      await source
          .file('receipts.json')
          .writeAsString(jsonEncode({'rows': []}));
      final reviews = ReviewStore(
        Directory('${temp.path}/mvp-reviews'),
        contributionStore: source,
      );
      await reviews.initialize();
      final photo = ContributionPhoto(
        role: null,
        capturedAt: null,
        importedAt: '2026-10-30T00:00:00Z',
        localName: 'cup.jpg',
        checksum: 'sha256:${'a' * 64}',
        originalChecksum: 'sha256:${'b' * 64}',
        width: 160,
        height: 200,
        byteLength: 1000,
        decision: PhotoDecision.skipped,
      );
      final reviewPhoto = ReviewPhoto(
        id: 'p',
        photo: photo,
        surface: ReviewSurface.cup,
        usableConfirmedAtUtc: '2026-10-30T00:00:00Z',
        analysis: {
          'photoId': 'p',
          'photoChecksum': photo.checksum,
          'surface': 'cup',
          'runId': 'synthetic-run',
          'outcome': 'noMatch',
          'symbols': [],
          'fixtureMeasurements': [
            for (var k = 0; k < 680; k++)
              {
                'index': k,
                'values': List.generate(16, (v) => v),
                'note':
                    'synthetic physical measurement metadata, no private data',
              },
          ],
        },
      );
      ReviewSession? active;
      var seededBytes = 0, selectedBytes = 0, selectedFiles = 0;
      for (var i = 0; i < 263; i++) {
        final owner = i % 40;
        final id = owner == 0 ? 'linked-active' : 'linked-record$owner';
        final session = ReviewSession(
          id: id,
          groupId: 'group$owner',
          revision: i ~/ 40 + 1,
          createdAtUtc: '2026-10-30',
          localConsentAtUtc: '2026-10-30',
          sameSampleDeclared: true,
          photos: [reviewPhoto],
        );
        final document = session.toJson();
        final bytes = utf8.encode(
          jsonEncode({
            'document': document,
            'checksum':
                'sha256:${sha256.convert(utf8.encode(jsonEncode(document)))}',
          }),
        );
        await reviews
            .file('review-$id-${session.revision}.json')
            .writeAsBytes(bytes);
        seededBytes += bytes.length;
        if (owner == 0) {
          active = session;
          selectedBytes += bytes.length;
          selectedFiles++;
        }
      }
      final draft = ContributionDraft(
        id: 'receipt-active',
        rootId: 'active',
        groupId: 'group0',
        createdAt: '2026-10-30T00:00:00Z',
        consentedAt: '2026-10-30T00:00:00Z',
        kind: ContributionKind.gallerySingle,
        photos: [photo],
      );
      final row = <String, dynamic>{
        'id': draft.id,
        'root_id': draft.rootId,
        'local_only': true,
        'document': draft.toJson(),
      };
      await source.saveReceipt(row);
      final ai = AiStore(Directory('${temp.path}/ai-local'));
      await ai.change((data) {
        (data['links'] as Map)['active'] = {
          'sessionId': 'linked-active',
          'receiptId': draft.id,
          'revision': draft.revision,
        };
      });
      final bridge = AiBridge(source, reviews, ai);
      final timings = <String, List<int>>{};
      Future<void> measure(String name, Future<void> Function() work) async {
        final samples = <int>[];
        for (var i = 0; i < 4; i++) {
          final watch = Stopwatch()..start();
          await work();
          samples.add(watch.elapsedMicroseconds);
        }
        timings[name] = samples;
      }

      await measure('sourceCurrentUs', () async {
        expect(await bridge.isCurrent(active!), isTrue);
      });
      await measure('saveSamePhotoSourceUs', () async {
        final next = active!.next();
        await reviews.save(next);
        active = next;
      });
      expect(await bridge.isCurrent(active!), isTrue);
      // ignore: avoid_print
      print(
        'ATLAS_LARGE_HISTORY_BENCHMARK ${jsonEncode({'synthetic': true, 'revisionFiles': 263, 'recordCount': 40, 'seededBytes': seededBytes, 'activeRevisionFiles': selectedFiles, 'activeRevisionBytes': selectedBytes, 'units': 'microseconds', 'timings': timings, 'providerCalls': 0})}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
