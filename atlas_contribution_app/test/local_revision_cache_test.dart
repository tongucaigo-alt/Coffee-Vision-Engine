import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/local_revision_cache.dart';

void main() {
  test(
    'unchanged visits reuse one snapshot and concurrent reads join',
    () async {
      final cache = LocalRevisionCache<int>(canRetain: (_) => true);
      final pending = Completer<int>();
      var reads = 0;
      Future<int> read() {
        reads++;
        return pending.future;
      }

      final first = cache.load(read), second = cache.load(read);
      expect(identical(first, second), isTrue);
      pending.complete(7);
      expect(await first, 7);
      expect(await cache.load(read), 7);
      expect(reads, 1);
    },
  );
  test(
    'mutation during a load discards old data and joins the fresh read',
    () async {
      final cache = LocalRevisionCache<int>(canRetain: (_) => true);
      final stale = Completer<int>();
      var reads = 0;
      Future<int> read() async => ++reads == 1 ? stale.future : 2;
      final first = cache.load(read);
      markLocalDataChanged();
      final fresh = cache.load(read);
      stale.complete(1);
      expect(await fresh, 2);
      expect(await first, 2);
      expect(cache.value, 2);
      expect(reads, 2);
    },
  );
  test(
    'errors, oversized snapshots and explicit refresh are never stale hits',
    () async {
      final cache = LocalRevisionCache<int>(canRetain: (size) => size <= 2);
      await expectLater(
        cache.load(() async => throw StateError('read failed')),
        throwsStateError,
      );
      expect(await cache.load(() async => 3), 3);
      expect(cache.value, isNull);
      expect(await cache.load(() async => 2), 2);
      cache.invalidate();
      expect(await cache.load(() async => 1), 1);
      markLocalDataChanged();
      expect(cache.value, isNull);
    },
  );
}
