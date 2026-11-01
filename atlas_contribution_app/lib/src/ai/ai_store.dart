import 'dart:convert';
import 'dart:io';
import '../local_revision_cache.dart';
import 'ai_contract.dart';
import 'fortune_personalization.dart';
import 'fortune_memory.dart';

/// App-local AI metadata. Never included in either research ZIP exporter.
class AiStore {
  AiStore(this.directory, {FortuneMemoryEngine? memory})
    : _memory = memory ?? FortuneMemoryEngine();
  final Directory directory;
  final FortuneMemoryEngine _memory;
  Future<void> _tail = Future.value();
  Future<Map<String, dynamic>> read() async {
    await _tail;
    return _read();
  }

  Future<Map<String, dynamic>> _read() async {
    final file = File('${directory.path}/state.json');
    if (!await file.exists()) {
      return {
        'version': 1,
        'profiles': [],
        'results': [],
        'exposures': [],
        'links': {},
        'deleted': [],
      };
    }
    final value = Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    if (value['version'] != 1) {
      throw const FormatException('Unsupported AI store');
    }
    return value;
  }

  Future<void> change(void Function(Map<String, dynamic>) operation) =>
      _update((data) {
        operation(data);
        return true;
      });

  Future<void> _update(bool Function(Map<String, dynamic>) operation) {
    final next = _tail.then((_) async {
      final data = await _read();
      if (!operation(data)) return;
      try {
        await directory.create(recursive: true);
        final file = File('${directory.path}/state.pending');
        await file.writeAsString(jsonEncode(data), flush: true);
        await file.rename('${directory.path}/state.json');
      } finally {
        markLocalDataChanged();
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> queueReport(Map<String, dynamic> row) => change((d) {
    final reports = d.putIfAbsent('contentReports', () => <dynamic>[]) as List;
    if (reports.any((r) => r['id'] == row['id'])) return;
    reports.add(row);
  });

  /// Bounded operational events; no request body, user profile or remote text.
  Future<void> recordDiagnostic(AiFailure error, Map<String, int> stageMs) =>
      change((d) {
        final rows = d.putIfAbsent('diagnostics', () => <dynamic>[]) as List;
        rows.add({
          'atUtc': DateTime.now().toUtc().toIso8601String(),
          ...safeAiDiagnostics(error.diagnostics),
          'stageMs': {
            for (final e in stageMs.entries)
              if ([
                    'saving',
                    'analyzing',
                    'highlighting',
                    'generating',
                    'repairing',
                    'queued',
                    'completed',
                    'failed',
                    'cancelled',
                  ].contains(e.key) &&
                  e.value >= 0)
                e.key: e.value,
          },
        });
        if (rows.length > 100) rows.removeRange(0, rows.length - 100);
      });
  Future<List<Map<String, dynamic>>> pendingReports() async =>
      ((await read())['contentReports'] as List? ?? [])
          .where((r) => r['state'] == 'pending')
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Future<void> markReportSent(String id) => change((d) {
    for (final r in d['contentReports'] as List? ?? []) {
      if (r['id'] == id) {
        r['state'] = 'sent';
        r.remove('text');
      }
    }
  });

  Future<Set<String>> starredIds() async =>
      Set<String>.from((await read())['starredResultIds'] as List? ?? []);
  Future<void> setStarred(String resultId, bool starred) => change((d) {
    final ids = Set<String>.from(d['starredResultIds'] as List? ?? []);
    final result = (d['results'] as List)
        .where((r) => r['id'] == resultId)
        .firstOrNull;
    if (result == null || result['state'] != 'completed') {
      throw const AiFailure('Yalnız tamamlanmış bir fal yıldızlanabilir.');
    }
    if (starred && !ids.contains(resultId) && ids.length >= 20) {
      throw const AiFailure(
        '20 fal yıldızlı. Yeni bir fal için önce bir yıldızı kaldır.',
      );
    }
    if (starred) {
      ids.add(resultId);
    } else {
      ids.remove(resultId);
    }
    d['starredResultIds'] = ids.toList();
    d['starsVersion'] = 1;
  });
  Future<bool> hasStarredSession(String sessionId) async {
    final ids = await starredIds();
    return (await results(sessionId)).any((r) => ids.contains(r['id']));
  }

  Future<List<AiProfile>> profiles() async =>
      ((await read())['profiles'] as List)
          .map((p) => AiProfile.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
  Future<void> saveProfile(AiProfile p) => change((d) {
    final list = d['profiles'] as List;
    list.removeWhere((v) => v['id'] == p.id);
    list.add(p.toJson());
  });
  Future<List<Map<String, dynamic>>> results(String sessionId) async =>
      ((await read())['results'] as List)
          .where((r) => r['sessionId'] == sessionId)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Future<List<Map<String, dynamic>>> recentSuccessfulResults() async {
    final rows = ((await read())['results'] as List)
        .where((r) => r['state'] == 'completed')
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    rows.sort(
      (a, b) =>
          (b['createdAtUtc'] as String).compareTo(a['createdAtUtc'] as String),
    );
    return rows.take(5).toList();
  }

  Future<String> readingFocus(String sessionId) async {
    final stored = ((await read())['readingPreferences'] as Map?)?[sessionId];
    final focus = stored is Map ? stored['focus'] : null;
    return readingFocusValues.contains(focus) ? focus as String : 'general';
  }

  Future<void> setReadingFocus(String sessionId, String focus) => change((d) {
    if (!readingFocusValues.contains(focus)) {
      throw ArgumentError.value(focus, 'focus');
    }
    if ((d['deleted'] as List).contains(sessionId)) {
      throw const AiFailure('Bu kayıt silindi.');
    }
    final preferences =
        d.putIfAbsent('readingPreferences', () => <String, dynamic>{}) as Map;
    preferences[sessionId] = {'focus': focus};
  });

  Future<FortuneMemoryCandidate?> prepareMemory({
    required String readingKey,
    required String focus,
    required Map<String, dynamic> context,
  }) async {
    FortuneMemoryCandidate? candidate;
    await change((d) {
      candidate = _memory.prepare(
        d,
        readingKey: readingKey,
        focus: focus,
        context: context,
      );
    });
    return candidate;
  }

  Future<bool> memoryStillCurrent(
    String key,
    FortuneMemoryCandidate candidate,
  ) async => _memory.isCurrent(await read(), key, candidate);

  Future<void> saveResult(
    Map<String, dynamic> result, {
    FortuneMemoryCandidate? memoryCandidate,
  }) => change((d) {
    if ((d['deleted'] as List).contains(result['sessionId'])) {
      throw const AiFailure('Bu kayıt silindi.');
    }
    final list = d['results'] as List;
    _memory.complete(d, result, candidate: memoryCandidate);
    list.removeWhere((r) => r['id'] == result['id']);
    list.add({
      ...result,
      if (result['context'] is Map)
        'context': storedFortuneContext(
          Map<String, dynamic>.from(result['context'] as Map),
        ),
    });
  });

  /// Cold-start recovery never silently resubmits an interrupted generation.
  Future<void> recoverInterruptedResults() => change((d) {
    for (final result in d['results'] as List) {
      if (result['context'] is Map) {
        result['context'] = storedFortuneContext(
          Map<String, dynamic>.from(result['context'] as Map),
        );
      }
      if (result['state'] == 'running') result['state'] = 'interrupted';
    }
  });

  /// One verified snapshot for opening a reading; no long-lived AI data cache.
  Future<AiReadingSnapshot> readingSnapshot(String sessionId) async {
    final data = await read();
    final results = (data['results'] as List)
        .where((r) => r['sessionId'] == sessionId)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final exposed = (data['exposures'] as List? ?? const [])
        .map((r) => r['resultId'])
        .toSet();
    final pending = results
        .where(
          (r) =>
              (r['answers'] as List).isNotEmpty && !exposed.contains(r['id']),
        )
        .toList();
    final preference = (data['readingPreferences'] as Map?)?[sessionId];
    final focus = preference is Map ? preference['focus'] : null;
    final snapshot = AiReadingSnapshot(
      profiles: (data['profiles'] as List)
          .map((p) => AiProfile.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      results: results,
      stars: Set<String>.from(data['starredResultIds'] as List? ?? []),
      focus: readingFocusValues.contains(focus) ? focus as String : 'general',
    );
    // Validate all presentation metadata before any exposure write. A corrupt
    // profile/preferences registry must remain available for read-only recovery.
    if (pending.isNotEmpty) await exposeResults(pending);
    return snapshot;
  }

  Future<void> expose(Map<String, dynamic> result) => exposeResults([result]);

  Future<void> exposeResults(List<Map<String, dynamic>> results) =>
      _update((d) {
        final list = d['exposures'] as List;
        final exposed = list.map((r) => r['resultId']).toSet();
        var changed = false;
        for (final result in results) {
          if ((d['deleted'] as List).contains(result['sessionId'])) {
            throw const AiFailure('Bu kayıt silindi.');
          }
          if (exposed.add(result['id'])) {
            list.add({
              'kind': 'aiNarrative',
              'resultId': result['id'],
              'sessionId': result['sessionId'],
              'groupId': result['groupId'],
              'exposedAtUtc': DateTime.now().toUtc().toIso8601String(),
            });
            changed = true;
          }
        }
        return changed;
      });

  Future<void> exposeTraceAid({
    required String sessionId,
    required String groupId,
    required String photoIdentity,
    required String algorithm,
  }) => change((data) {
    if ((data['deleted'] as List).contains(sessionId)) {
      throw const AiFailure('Bu kayıt silindi.');
    }
    final id = 'traceAid:$sessionId:$photoIdentity:$algorithm';
    final list = data['exposures'] as List;
    if (!list.any((row) => row['resultId'] == id)) {
      list.add({
        'kind': 'coloredTraceAid',
        'resultId': id,
        'sessionId': sessionId,
        'groupId': groupId,
        'algorithm': algorithm,
        'exposedAtUtc': DateTime.now().toUtc().toIso8601String(),
      });
    }
  });

  Future<List<Map<String, dynamic>>> exposures(String groupId) async =>
      ((await read())['exposures'] as List)
          .where((r) => r['groupId'] == groupId)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Future<Map<String, dynamic>> researchAudit(String groupId) async {
    final history = await exposures(groupId);
    return {
      'version': 'atlas-ai-exposure-audit-v1',
      'currentObservations': history.isEmpty
          ? 'noKnownAiExposure'
          : 'potentiallyAiInfluenced',
      'initialObservations':
          'Use sealed snapshots and their exposure history; current labels are not independent ground truth.',
      'exposures': [
        for (final e in history)
          {'kind': 'aiNarrative', 'exposedAtUtc': e['exposedAtUtc']},
      ],
    };
  }

  Future<void> deleteSession(String id) => change((d) {
    final removed = (d['results'] as List)
        .where((r) => r['sessionId'] == id)
        .map((r) => r['id'])
        .toSet();
    (d['starredResultIds'] as List?)?.removeWhere(removed.contains);
    (d['contentReports'] as List?)?.removeWhere((r) => r['sessionId'] == id);
    (d['results'] as List).removeWhere((r) => r['sessionId'] == id);
    (d['readingPreferences'] as Map?)?.remove(id);
    final pending = (d['fortuneMemoryV1'] as Map?)?['pending'] as Map?;
    pending?.removeWhere(
      (key, receipt) =>
          key.toString().startsWith('$id|') ||
          removed.contains(receipt['sourceId']),
    );
    // Minimal exposure history remains alongside existing research tombstones;
    // no narrative, profile, input or media is retained here.
    if (!(d['deleted'] as List).contains(id)) (d['deleted'] as List).add(id);
  });
  Future<bool> isDeleted(String id) async =>
      ((await read())['deleted'] as List).contains(id);
}

class AiReadingSnapshot {
  const AiReadingSnapshot({
    required this.profiles,
    required this.results,
    required this.stars,
    required this.focus,
  });
  final List<AiProfile> profiles;
  final List<Map<String, dynamic>> results;
  final Set<String> stars;
  final String focus;
}
