import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/local_revision_cache.dart';

void main() {
  late Directory temp;
  late AiStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('atlas-reading-snapshot-');
    store = AiStore(temp);
    await store.change((data) {
      data['results'] = [
        for (var i = 0; i < 3; i++)
          {
            'id': 'r$i',
            'sessionId': 's',
            'groupId': 'g',
            'state': 'completed',
            'answers': [
              {'text': 'synthetic'},
            ],
          },
      ];
      data['starredResultIds'] = ['r1'];
      data['readingPreferences'] = {
        's': {'focus': 'love'},
      };
    });
  });
  tearDown(() => temp.delete(recursive: true));
  test(
    'one opening batches exposures; repeated opening never rewrites',
    () async {
      final initial = localDataRevision;
      final snapshot = await store.readingSnapshot('s');
      expect(snapshot.results.length, 3);
      expect(snapshot.stars, {'r1'});
      expect(snapshot.focus, 'love');
      expect(localDataRevision, initial + 1);
      final before = await File('${temp.path}/state.json').readAsBytes();
      final revision = localDataRevision;
      await store.readingSnapshot('s');
      await store.expose(snapshot.results.first);
      expect(localDataRevision, revision);
      expect(await File('${temp.path}/state.json').readAsBytes(), before);
      expect((await store.read())['exposures'], hasLength(3));
    },
  );
  test(
    'topic, star and deletion stay current; corrupt storage fails closed',
    () async {
      await store.readingSnapshot('s');
      await store.setReadingFocus('s', 'general');
      await store.setStarred('r1', false);
      final updated = await store.readingSnapshot('s');
      expect(updated.focus, 'general');
      expect(updated.stars, isEmpty);
      await store.deleteSession('s');
      expect((await store.readingSnapshot('s')).results, isEmpty);
      await File('${temp.path}/state.json').writeAsString('broken');
      await expectLater(store.readingSnapshot('s'), throwsFormatException);
      expect(await File('${temp.path}/state.json').readAsString(), 'broken');
    },
  );
  test('invalid reading metadata stays read-only before recovery', () async {
    await store.change((data) {
      data['profiles'] = [
        {'invalid': true},
      ];
    });
    final before = await File('${temp.path}/state.json').readAsBytes();
    final revision = localDataRevision;
    await expectLater(store.readingSnapshot('s'), throwsA(anything));
    expect(await File('${temp.path}/state.json').readAsBytes(), before);
    expect(localDataRevision, revision);
  });
}
