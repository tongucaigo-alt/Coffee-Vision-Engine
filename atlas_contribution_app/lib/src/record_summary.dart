import 'dart:convert';
import 'local_revision_cache.dart';
import 'mvp/review_models.dart' show immutableDocument;

/// Read-only presentation metadata for one saved contribution.
class RecordSummary {
  const RecordSummary({required this.state, required this.starred});

  static const unreadable = 'Fal durumu okunamadı';
  final String state;
  final bool starred;
}

typedef RecordSummaryLoader =
    Future<Map<String, RecordSummary>> Function(
      List<Map<String, dynamic>> rows,
    );

class RecordHistorySnapshot {
  RecordHistorySnapshot({
    required List<Map<String, dynamic>> rows,
    required Map<String, String> states,
    required Set<String> stars,
    this.message,
  }) : rows = List.unmodifiable(rows.map(immutableDocument)),
       states = Map.unmodifiable(states),
       stars = Set.unmodifiable(stars);
  final List<Map<String, dynamic>> rows;
  final Map<String, String> states;
  final Set<String> stars;
  final String? message;
  bool get canRetain =>
      message == null &&
      !states.values.contains(RecordSummary.unreadable) &&
      rows.length <= 200 &&
      utf8.encode(jsonEncode(rows)).length <= 4 * 1024 * 1024;
}

typedef RecordHistoryCache = LocalRevisionCache<RecordHistorySnapshot>;
