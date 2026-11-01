import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';

void main() {
  late Directory temp;
  late ReviewStore store;
  ReviewSession record(String id) => ReviewSession(
    id: id,
    groupId: 'g',
    createdAtUtc: '2026-10-30',
    localConsentAtUtc: '2026-10-30',
  );
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('atlas-target-');
    store = ReviewStore(temp);
  });
  tearDown(() => temp.delete(recursive: true));
  test(
    'lookup isolates hyphen/digit IDs and keeps deletion and stale-write checks',
    () async {
      final first = record('target');
      await store.save(first);
      await store.save(first.next());
      var neighbor = record('target-1');
      for (var i = 0; i < 4; i++) {
        await store.save(neighbor);
        neighbor = neighbor.next();
      }
      expect((await store.session('target'))!.revision, 2);
      expect((await store.session('target-1'))!.revision, 4);
      expect(await store.session('missing'), isNull);
      await expectLater(store.session('../unsafe'), throwsFormatException);
      final current = (await store.session('target'))!;
      await store.save(current.next(deleted: true));
      expect((await store.session('target'))!.deleted, isTrue);
      await expectLater(store.save(current.next()), throwsStateError);
    },
  );
  test(
    'current lookup verifies old target bytes even with a restored timestamp',
    () async {
      final first = record('target');
      await store.save(first);
      await store.save(first.next());
      await store.session('target');
      final file = store.file('review-target-1.json');
      final stamp = await file.lastModified();
      final original = await file.readAsString();
      await file.writeAsString(
        original.replaceFirst('2026-10-30', '2026-10-31'),
      );
      await file.setLastModified(stamp);
      await expectLater(store.session('target'), throwsFormatException);
      await expectLater(store.save(first.next().next()), throwsFormatException);
      await file.writeAsString(original);
      expect((await store.session('target'))!.revision, 2);
      final doc = jsonDecode(original) as Map;
      await store.file('review-target-0.json').writeAsString(jsonEncode(doc));
      await expectLater(store.session('target'), throwsFormatException);
    },
  );
  test(
    'unrelated history is excluded from a current check but retained in full audits',
    () async {
      await store.save(record('target'));
      await store.save(record('neighbor'));
      await store.file('review-neighbor-1.json').writeAsString('damaged');
      expect((await store.session('target'))!.id, 'target');
      await expectLater(store.sessions(), throwsFormatException);
      await expectLater(
        store.knownGroupExposures(record('target')),
        throwsFormatException,
      );
    },
  );
  test('new non-linked records retain the existing capacity limit', () async {
    for (var i = 0; i < 30; i++) {
      await store.save(record('record$i'));
    }
    await expectLater(store.save(record('overflow')), throwsStateError);
    await store.save(record('linked-independent'));
    expect((await store.session('linked-independent'))!.revision, 1);
  });
}
