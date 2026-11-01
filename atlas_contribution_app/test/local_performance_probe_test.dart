import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/ai/record_summaries.dart';
import 'package:atlas_contribution_app/src/record_summary.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';
import 'mvp_review_test.dart' show fakeEngine;

void main() {
  test('synthetic local preparation benchmark', () async {
    final temp = await Directory.systemTemp.createTemp('atlas-perf-');
    addTearDown(() => temp.delete(recursive: true));
    final ai = AiStore(Directory('${temp.path}/ai'));
    await ai.change((data) {
      data['results'] = [
        for (var i = 0; i < 100; i++)
          {
            'id': 'r$i',
            'sessionId': 's0',
            'groupId': 'g',
            'state': 'completed',
            'createdAtUtc': '2026-10-30',
            'answers': [
              {'text': List.filled(400, 'ornek').join(' ')},
            ],
          },
      ];
      (data['results'] as List).add({
        'id': 'history',
        'sessionId': 'linked-root',
        'groupId': 'g',
        'state': 'completed',
        'createdAtUtc': '2026-10-30',
        'answers': [
          {'text': 'sentetik'},
        ],
      });
      (data['results'] as List).add({
        'id': 'single',
        'sessionId': 'single-session',
        'groupId': 'g',
        'state': 'completed',
        'createdAtUtc': '2026-10-30',
        'answers': [
          {'text': List.filled(400, 'ornek').join(' ')},
        ],
      });
      data['exposures'] = [
        {'resultId': 'single'},
        for (var i = 0; i < 100; i++) {'resultId': 'r$i'},
      ];
    });
    final reviews = ReviewStore(Directory('${temp.path}/reviews'));
    await reviews.initialize();
    for (var i = 1; i <= 100; i++) {
      final session = ReviewSession(
        id: 's0',
        groupId: 'g',
        revision: i,
        createdAtUtc: '2026-10-30',
        localConsentAtUtc: '2026-10-30',
      );
      final doc = session.toJson();
      // Extra synthetic metadata exercises decoding without any private data.
      doc['syntheticPadding'] = [
        for (var k = 0; k < 200; k++) {'index': k, 'value': 'ornek'},
      ];
      await reviews
          .file('review-s0-$i.json')
          .writeAsString(
            jsonEncode({
              'document': doc,
              'checksum':
                  'sha256:${sha256.convert(utf8.encode(jsonEncode(doc)))}',
            }),
          );
    }
    final results = <String, List<int>>{};
    Future<void> measure(String name, Future<void> Function() work) async {
      final samples = <int>[];
      for (var i = 0; i < 4; i++) {
        final watch = Stopwatch()..start();
        await work();
        samples.add(watch.elapsedMicroseconds);
      }
      results[name] = samples;
    }

    Future<void> openReading(String id) async {
      await ai.readingSnapshot(id);
    }

    await measure('oneSavedAnswerUs', () => openReading('single-session'));
    await measure('readingOpenUs', () => openReading('s0'));
    await measure('reviewScanUs', () async {
      await reviews.sessions();
    });
    final recordCache = RecordHistoryCache(canRetain: (s) => s.canRetain);
    final recordRows = <Map<String, dynamic>>[
      {
        'root_id': 'root',
        'document': {'id': 'receipt-root'},
      },
    ];
    Future<void> openRecords() async {
      await recordCache.load(() async {
        final summaries = await readRecordSummaries(
          recordRows,
          readAi: ai.read,
          readSessions: reviews.sessions,
        );
        return RecordHistorySnapshot(
          rows: recordRows,
          states: {
            for (final entry in summaries.entries) entry.key: entry.value.state,
          },
          stars: {
            for (final entry in summaries.entries)
              if (entry.value.starred) entry.key,
          },
        );
      });
    }

    await measure('recordsVisitUs', openRecords);
    final photo = (await reviews.importPhoto(
      testImage(),
      surface: ReviewSurface.cup,
      declaredRole: CaptureRole.free,
    )).update(confirmedAt: '2026-10-30T00:00:00Z');
    final ready = ReviewSession(
      id: 'prepared',
      groupId: 'g',
      createdAtUtc: '2026-10-30',
      localConsentAtUtc: '2026-10-30',
      sameSampleDeclared: true,
      photos: [photo],
    );
    await reviews.save(ready);
    final controller = ReviewController(
      store: reviews,
      session: ready,
      loadEngine: () async => fakeEngine(),
    );
    await controller.analyze(enrich: true);
    await measure('preparedReuseUs', () => controller.analyze(enrich: true));
    await controller.close();
    controller.dispose();
    // ignore: avoid_print
    print('ATLAS_SYNTHETIC_BENCHMARK ${jsonEncode(results)}');
  });
}
