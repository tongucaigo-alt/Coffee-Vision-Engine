import 'dart:convert';
import 'dart:io';
import 'ai_bridge.dart';

/// One-shot, explicitly requested local measurement for diagnostic debug builds.
/// Has no AI client, prompt, image decoder or network dependency. Persists only
/// timings/status; no record IDs, photos, topics, profile or narrative content.
Future<void> runRequestedLocalPerformanceProbe(AiBridge bridge) async {
  final directory = bridge.ai.directory;
  final request = File(
    '${directory.path}/atlas-v120-local-performance.request',
  );
  if (!await request.exists()) return;
  if (await request.readAsString() != 'atlas-v120-local-check') return;
  await request.rename(
    '${directory.path}/atlas-v120-local-performance.consumed',
  );
  final result = <String, dynamic>{'version': 1, 'providerCalls': 0};
  try {
    if ((await bridge.source.pendingDeletes()).isNotEmpty) {
      result['status'] = 'pending_deletion';
    } else {
      final data = await bridge.ai.read();
      final rows = await bridge.source.receipts();
      result['status'] = 'no_current_source';
      for (final row in rows) {
        final root = row['root_id'] as String;
        final id = bridge.sessionId(root);
        final link = (data['links'] as Map)[root] as Map?;
        if (link?['receiptId'] != (row['document'] as Map)['id'] ||
            (data['deleted'] as List).contains(id)) {
          continue;
        }
        final snapshot = await bridge.reviews.session(id);
        if (snapshot == null ||
            snapshot.deleted ||
            snapshot.preparedInput == null) {
          continue;
        }
        final samples = <int>[];
        var current = true;
        for (var index = 0; index < 3; index++) {
          final watch = Stopwatch()..start();
          current = await bridge.isCurrent(snapshot);
          samples.add(watch.elapsedMicroseconds);
          if (!current) break;
        }
        result['status'] = current ? 'measured' : 'source_changed';
        result['sourceCurrentUs'] = samples;
        break;
      }
    }
  } catch (_) {
    // Never copy an exception message or personal source into a diagnostic.
    result['status'] = 'unavailable';
  }
  final pending = File(
    '${directory.path}/atlas-v120-local-performance.pending',
  );
  await pending.writeAsString(jsonEncode(result), flush: true);
  await pending.rename(
    '${directory.path}/atlas-v120-local-performance.result.json',
  );
}
