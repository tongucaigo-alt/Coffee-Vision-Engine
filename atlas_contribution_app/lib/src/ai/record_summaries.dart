import '../mvp/review_models.dart';
import '../record_summary.dart';
import 'fortune_personalization.dart';
import 'reading_identity.dart';

/// One refresh owns one snapshot. No persistent cache or storage writes: later
/// refreshes must see changed topics, stars, results and review revisions.
Future<Map<String, RecordSummary>> readRecordSummaries(
  List<Map<String, dynamic>> rows, {
  required Future<Map<String, dynamic>> Function() readAi,
  required Future<List<ReviewSession>> Function() readSessions,
}) async {
  if (rows.isEmpty) return const {};
  final data = await readAi();
  final resultsBySession = <String, List<Map<String, dynamic>>>{};
  for (final result in data['results'] as List) {
    final row = Map<String, dynamic>.from(result as Map);
    (resultsBySession[row['sessionId'] as String] ??= []).add(row);
  }
  final stars = Set<String>.from(data['starredResultIds'] as List? ?? []);
  final answeredByRoot = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final root = row['root_id'] as String;
    answeredByRoot[root] = [
      for (final result
          in resultsBySession['linked-$root'] ?? <Map<String, dynamic>>[])
        if ((result['answers'] as List).isNotEmpty) result,
    ];
  }

  final sessions = <String, ReviewSession>{};
  var reviewsUnreadable = false;
  if (answeredByRoot.values.any((results) => results.isNotEmpty)) {
    try {
      for (final session in await readSessions()) {
        sessions[session.id] = session;
      }
    } catch (_) {
      // A failed integrity check is not evidence of an absent/old answer.
      reviewsUnreadable = true;
    }
  }
  final fingerprints = <String, String>{};
  final summaries = <String, RecordSummary>{};
  for (final row in rows) {
    final root = row['root_id'] as String;
    final id = 'linked-$root';
    final starred = (resultsBySession[id] ?? <Map<String, dynamic>>[]).any(
      (result) => stars.contains(result['id']),
    );
    String state;
    try {
      final results = answeredByRoot[root]!;
      if (results.isEmpty) {
        state = 'Telefona kaydedildi';
      } else if (reviewsUnreadable) {
        state = RecordSummary.unreadable;
      } else {
        final session = sessions[id];
        final link = (data['links'] as Map)[root] as Map?;
        if (session == null ||
            link?['receiptId'] != (row['document'] as Map)['id']) {
          state = 'Önceki kayda ait fal';
        } else {
          final preference = (data['readingPreferences'] as Map?)?[id];
          final storedFocus = preference is Map ? preference['focus'] : null;
          final focus = readingFocusValues.contains(storedFocus)
              ? storedFocus as String
              : 'general';
          final fingerprint = fingerprints.putIfAbsent(
            id,
            () => preparationSourceFingerprint(session),
          );
          final key = readingRequestKey(id, fingerprint, focus);
          final current = results
              .where((result) => resultReadingRequestKey(result) == key)
              .toList();
          state = current.isEmpty
              ? 'Önceki kayda ait fal'
              : current.any((result) => result['state'] == 'completed')
              ? 'Fal hazır'
              : 'Fal denemesi tamamlanmadı';
        }
      }
    } catch (_) {
      state = RecordSummary.unreadable;
    }
    summaries[root] = RecordSummary(state: state, starred: starred);
  }
  return Map.unmodifiable(summaries);
}
