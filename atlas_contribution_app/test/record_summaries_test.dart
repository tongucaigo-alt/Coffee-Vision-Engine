import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/ai/record_summaries.dart';
import 'package:atlas_contribution_app/src/ai/reading_identity.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/record_summary.dart';

ReviewSession session(String root, {int revision = 1}) => ReviewSession(
  id: 'linked-$root',
  groupId: root,
  revision: revision,
  createdAtUtc: '2026-10-01T00:00:00Z',
  localConsentAtUtc: '2026-10-01T00:00:00Z',
);

Map<String, dynamic> receipt(String root) => {
  'root_id': root,
  'document': {'id': 'receipt-$root'},
};

Map<String, dynamic> result(
  String root, {
  String? focus,
  String state = 'completed',
  bool answered = true,
}) => {
  'id': 'result-$root',
  'sessionId': 'linked-$root',
  'sourceFingerprint': preparationSourceFingerprint(session(root)),
  'state': state,
  'answers': [
    if (answered) {'text': 'Sentetik fal'},
  ],
  'context': {'readingFocus': ?focus},
};

Map<String, dynamic> dataFor(List<String> roots) => {
  'version': 1,
  'profiles': [],
  'results': [for (final root in roots) result(root)],
  'links': {
    for (final root in roots) root: {'receiptId': 'receipt-$root'},
  },
  'deleted': [],
  'starredResultIds': [],
};

// The V91 callbacks, retained only as an independent compatibility/performance
// reference. Both paths use the same real stores and immutable revision files.
Future<Map<String, RecordSummary>> legacySummaries(
  List<Map<String, dynamic>> rows,
  AiStore ai,
  Future<List<ReviewSession>> Function() readSessions,
) async {
  final summaries = <String, RecordSummary>{};
  for (final row in rows) {
    final root = row['root_id'] as String;
    final id = 'linked-$root';
    final starred = await ai.hasStarredSession(id);
    final data = await ai.read();
    final results = (data['results'] as List).where(
      (r) => r['sessionId'] == id && (r['answers'] as List).isNotEmpty,
    );
    var state = 'Telefona kaydedildi';
    if (results.isNotEmpty) {
      final currentSession = (await readSessions())
          .where((s) => s.id == id)
          .firstOrNull;
      final link = (data['links'] as Map)[root] as Map?;
      if (currentSession == null ||
          link?['receiptId'] != (row['document'] as Map)['id']) {
        state = 'Önceki kayda ait fal';
      } else {
        final focus = await ai.readingFocus(id);
        final current = results.where(
          (r) =>
              resultReadingRequestKey(r as Map) ==
              readingRequestKey(
                id,
                preparationSourceFingerprint(currentSession),
                focus,
              ),
        );
        state = current.isEmpty
            ? 'Önceki kayda ait fal'
            : current.any((r) => r['state'] == 'completed')
            ? 'Fal hazır'
            : 'Fal denemesi tamamlanmadı';
      }
    }
    summaries[root] = RecordSummary(state: state, starred: starred);
  }
  return summaries;
}

class CountingAiStore extends AiStore {
  CountingAiStore(super.directory);
  int reads = 0;
  @override
  Future<Map<String, dynamic>> read() {
    reads++;
    return super.read();
  }
}

void main() {
  test('empty list does not read either registry', () async {
    final summaries = await readRecordSummaries(
      [],
      readAi: () async {
        fail('Unexpected AI read');
      },
      readSessions: () async {
        fail('Unexpected review scan');
      },
    );
    expect(summaries, isEmpty);
  });

  test(
    'one snapshot preserves topics, legacy general, stars and old sources',
    () async {
      final roots = [
        'new',
        'ready',
        'topic',
        'revision',
        'missing',
        'failed',
        'source',
        'empty',
      ];
      final data = dataFor(roots);
      data['results'] = [
        result('ready'), // Missing legacy topic is General.
        result('topic'),
        result('revision'),
        result('missing'),
        result('failed', state: 'failed'),
        result('source')..['sourceFingerprint'] = 'old-source',
        result('empty', answered: false, state: 'interrupted'),
      ];
      data['starredResultIds'] = ['result-ready', 'result-topic'];
      data['readingPreferences'] = {
        'linked-topic': {'focus': 'money'},
      };
      (data['links'] as Map)['revision'] = {'receiptId': 'old-receipt'};
      var aiReads = 0, reviewScans = 0;
      final summaries = await readRecordSummaries(
        roots.map(receipt).toList(),
        readAi: () async {
          aiReads++;
          return data;
        },
        readSessions: () async {
          reviewScans++;
          return [
            for (final root in roots)
              if (root != 'missing') session(root),
          ];
        },
      );
      expect(aiReads, 1);
      expect(reviewScans, 1);
      expect(summaries.map((k, v) => MapEntry(k, v.state)), {
        'new': 'Telefona kaydedildi',
        'ready': 'Fal hazır',
        'topic': 'Önceki kayda ait fal',
        'revision': 'Önceki kayda ait fal',
        'missing': 'Önceki kayda ait fal',
        'failed': 'Fal denemesi tamamlanmadı',
        'source': 'Önceki kayda ait fal',
        'empty': 'Telefona kaydedildi',
      });
      expect(summaries['ready']!.starred, isTrue);
      expect(summaries['topic']!.starred, isTrue);
      expect(summaries['new']!.starred, isFalse);
    },
  );

  test(
    'next refresh sees changed focus, stars, result and review revision',
    () async {
      final data = dataFor(['one']);
      var currentSession = session('one');
      Future<Map<String, RecordSummary>> refresh() => readRecordSummaries(
        [receipt('one')],
        readAi: () async => data,
        readSessions: () async => [currentSession],
      );
      expect((await refresh())['one']!.state, 'Fal hazır');
      data['readingPreferences'] = {
        'linked-one': {'focus': 'love'},
      };
      data['starredResultIds'] = ['result-one'];
      final changedTopic = (await refresh())['one']!;
      expect(changedTopic.state, 'Önceki kayda ait fal');
      expect(changedTopic.starred, isTrue);
      (data['results'] as List).add(
        result('one', focus: 'love')..['id'] = 'love-result',
      );
      expect((await refresh())['one']!.state, 'Fal hazır');
      currentSession = currentSession.next(sameSample: true);
      expect((await refresh())['one']!.state, 'Önceki kayda ait fal');
      data['starredResultIds'] = [];
      expect((await refresh())['one']!.starred, isFalse);
    },
  );

  test(
    'unreadable revisions retain stars and do not claim the answer is absent',
    () async {
      final data = dataFor(['one']);
      data['starredResultIds'] = ['result-one'];
      final summaries = await readRecordSummaries(
        [receipt('one'), receipt('new')],
        readAi: () async => data,
        readSessions: () async =>
            throw const FormatException('Checksum mismatch'),
      );
      expect(summaries['one']!.state, RecordSummary.unreadable);
      expect(summaries['one']!.starred, isTrue);
      expect(summaries['new']!.state, 'Telefona kaydedildi');
    },
  );

  test(
    'no answered results need no review scan; AI failure is not empty data',
    () async {
      final data = dataFor([]);
      final summaries = await readRecordSummaries(
        [receipt('new')],
        readAi: () async => data,
        readSessions: () async {
          fail('Unexpected scan');
        },
      );
      expect(summaries['new']!.state, 'Telefona kaydedildi');
      await expectLater(
        readRecordSummaries(
          [receipt('new')],
          readAi: () async => throw const FormatException('Corrupt AI state'),
          readSessions: () async {
            fail('Unexpected scan');
          },
        ),
        throwsFormatException,
      );
    },
  );

  test(
    '26 records / 171 revisions: same statuses, one scan, unchanged bytes',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'atlas-records-benchmark-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final reviews = ReviewStore(Directory('${temp.path}/reviews'));
      await reviews.initialize();
      final roots = [for (var i = 0; i < 26; i++) 'root$i'];
      final data = dataFor(roots.take(20).toList());
      data['starredResultIds'] = ['result-root0', 'result-root19'];
      final ai = CountingAiStore(Directory('${temp.path}/ai'));
      await ai.directory.create();
      final stateFile = File('${ai.directory.path}/state.json');
      await stateFile.writeAsString(jsonEncode(data));
      final before = <String, String>{
        stateFile.path: await stateFile.readAsString(),
      };
      for (var i = 0; i < 171; i++) {
        final root = roots[i % roots.length];
        final value = session(root, revision: i ~/ roots.length + 1).toJson();
        // Synthetic payload approximates the existing history size without
        // touching any phone backup or including personal images/readings.
        value['fixturePayload'] = 'x' * 100000;
        final envelope = jsonEncode({
          'document': value,
          'checksum':
              'sha256:${sha256.convert(utf8.encode(jsonEncode(value)))}',
        });
        final file = reviews.file(
          'review-linked-$root-${value['revision']}.json',
        );
        await file.writeAsString(envelope);
        before[file.path] = envelope;
      }
      final rows = roots.map(receipt).toList();
      var scans = 0;
      Future<List<ReviewSession>> scan() {
        scans++;
        return reviews.sessions();
      }

      final oldWatch = Stopwatch()..start();
      final old = await legacySummaries(rows, ai, scan);
      oldWatch.stop();
      expect(scans, 20);
      expect(ai.reads, 98);
      final oldReads = ai.reads;
      scans = 0;
      ai.reads = 0;
      final newWatch = Stopwatch()..start();
      final current = await readRecordSummaries(
        rows,
        readAi: ai.read,
        readSessions: scan,
      );
      newWatch.stop();
      expect(scans, 1);
      expect(ai.reads, 1);
      for (final root in roots) {
        expect(current[root]!.state, old[root]!.state);
        expect(current[root]!.starred, old[root]!.starred);
      }
      for (final entry in before.entries) {
        expect(await File(entry.key).readAsString(), entry.value);
      }
      debugPrint(
        jsonEncode({
          'syntheticRecords': rows.length,
          'revisionFiles': 171,
          'oldAiReads': oldReads,
          'newAiReads': ai.reads,
          'oldReviewScans': 20,
          'newReviewScans': scans,
          'oldMs': oldWatch.elapsedMilliseconds,
          'newMs': newWatch.elapsedMilliseconds,
          'filesUnchanged': before.length,
        }),
      );
      // Corrupt an old revision to ensure the optimization still verifies all
      // historical checksums instead of silently trusting just the latest file.
      final corrupt = File(
        before.keys.firstWhere((p) => p.endsWith('root0-1.json')),
      );
      final damaged = jsonDecode(await corrupt.readAsString()) as Map;
      (damaged['document'] as Map)['fixturePayload'] = 'changed';
      await corrupt.writeAsString(jsonEncode(damaged));
      final guarded = await readRecordSummaries(
        rows,
        readAi: ai.read,
        readSessions: scan,
      );
      expect(guarded['root0']!.state, RecordSummary.unreadable);
      expect(guarded['root0']!.starred, isTrue);
      expect(jsonDecode(await stateFile.readAsString())['starredResultIds'], [
        'result-root0',
        'result-root19',
      ]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
