import 'dart:convert';
import 'dart:io';
import 'ai_contract.dart';

/// App-local AI metadata. Never included in either research ZIP exporter.
class AiStore {
  AiStore(this.directory);
  final Directory directory;
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

  Future<void> change(void Function(Map<String, dynamic>) operation) {
    final next = _tail.then((_) async {
      await directory.create(recursive: true);
      final data = await _read();
      operation(data);
      final file = File('${directory.path}/state.pending');
      await file.writeAsString(jsonEncode(data), flush: true);
      await file.rename('${directory.path}/state.json');
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
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

  Future<void> saveResult(Map<String, dynamic> result) => change((d) {
    if ((d['deleted'] as List).contains(result['sessionId'])) {
      throw const AiFailure('Bu kayıt silindi.');
    }
    final list = d['results'] as List;
    list.removeWhere((r) => r['id'] == result['id']);
    list.add(result);
  });

  /// Cold-start recovery never silently resubmits an interrupted generation.
  Future<void> recoverInterruptedResults() => change((d) {
    for (final result in d['results'] as List) {
      if (result['state'] == 'running') result['state'] = 'interrupted';
    }
  });
  Future<void> expose(Map<String, dynamic> result) => change((d) {
    if ((d['deleted'] as List).contains(result['sessionId'])) {
      throw const AiFailure('Bu kayıt silindi.');
    }
    final list = d['exposures'] as List;
    if (!list.any((r) => r['resultId'] == result['id'])) {
      list.add({
        'kind': 'aiNarrative',
        'resultId': result['id'],
        'sessionId': result['sessionId'],
        'groupId': result['groupId'],
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
    (d['results'] as List).removeWhere((r) => r['sessionId'] == id);
    // Minimal exposure history remains alongside existing research tombstones;
    // no narrative, profile, input or media is retained here.
    if (!(d['deleted'] as List).contains(id)) (d['deleted'] as List).add(id);
  });
  Future<bool> isDeleted(String id) async =>
      ((await read())['deleted'] as List).contains(id);
}
