import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';

void main() {
  test(
    'warm parsed metadata still verifies actual bytes and every revision',
    () async {
      final temp = await Directory.systemTemp.createTemp('atlas-verified-');
      addTearDown(() => temp.delete(recursive: true));
      final store = ReviewStore(temp);
      final first = ReviewSession(
        id: 's',
        groupId: 'g',
        createdAtUtc: '2026-10-30',
        localConsentAtUtc: '2026-10-30',
      );
      await store.save(first);
      await store.save(first.next());
      expect((await store.sessions()).single.revision, 2);
      expect((await store.sessions()).single.revision, 2);
      // Same length replacement with a restored timestamp must not hit the cache.
      final file = store.file('review-s-1.json');
      final stamp = await file.lastModified();
      final original = await file.readAsString();
      final changed = original.replaceFirst('2026-10-30', '2026-10-31');
      expect(changed.length, original.length);
      await file.writeAsString(changed);
      await file.setLastModified(stamp);
      await expectLater(store.sessions(), throwsFormatException);
      await file.writeAsString(original);
      expect((await store.sessions()).single.revision, 2);
      await store.file('review-s-2.json').delete();
      expect((await store.sessions()).single.revision, 1);
      // A checksum-valid document with the wrong filename also stays rejected.
      final envelope = jsonDecode(original) as Map;
      await store
          .file('review-other-1.json')
          .writeAsString(jsonEncode(envelope));
      await expectLater(store.sessions(), throwsFormatException);
    },
  );
}
