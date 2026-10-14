import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/coffee_guide_store.dart';

void main() {
  late Directory root;
  late CoffeeGuideStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-guide-store-');
    store = CoffeeGuideStore(Directory('${root.path}/coffee-guide'));
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'first, interrupted, second and subsequent presentations persist separately',
    () async {
      final first = (await store.read()).presented();
      expect(first.shownCount, 1);
      await store.save(first);
      final restarted = CoffeeGuideStore(store.directory);
      expect((await restarted.read()).dontShowAgain, false);
      final second = (await restarted.read()).presented();
      expect(second.shownCount, 2);
      await restarted.save(second);
      expect((await store.read()).presented().shownCount, 2);
      await store.save(
        const CoffeeGuideState(shownCount: 2, dontShowAgain: true),
      );
      expect(
        (await CoffeeGuideStore(store.directory).read()).dontShowAgain,
        true,
      );
    },
  );

  test(
    'cannot suppress first launch; contribution/consent data are untouched',
    () async {
      final data = Directory('${root.path}/offline-contributions');
      await data.create();
      final sentinels = <String, String>{
        'draft.json': '{"draft":"keep"}',
        'local-use.json': '{"adultDeclared":false}',
        'receipts.json': '{"rows":["keep"]}',
      };
      for (final entry in sentinels.entries) {
        await File('${data.path}/${entry.key}').writeAsString(entry.value);
      }
      await store.save(
        const CoffeeGuideState(shownCount: 1, dontShowAgain: true),
      );
      expect((await store.read()).dontShowAgain, false);
      for (final entry in sentinels.entries) {
        expect(
          await File('${data.path}/${entry.key}').readAsString(),
          entry.value,
        );
      }
      expect(await data.list().length, sentinels.length);
    },
  );

  test('damaged state falls back to backup, then to visible guide', () async {
    await store.save(const CoffeeGuideState(shownCount: 1));
    await store.save(const CoffeeGuideState(shownCount: 2));
    await File('${store.directory.path}/state.json').writeAsString('broken');
    expect((await store.read()).shownCount, 1);
    await File('${store.directory.path}/state.bak').writeAsString('broken');
    final state = await store.read();
    expect(state.shownCount, 0);
    expect(state.dontShowAgain, false);
  });

  test('invalid data never hide the guide', () async {
    await store.directory.create();
    for (final data in [
      '{"version":1,"shownCount":-1,"dontShowAgain":true}',
      '{"version":1,"shownCount":"2","dontShowAgain":true}',
      '{"version":1,"shownCount":0,"dontShowAgain":true}',
      '{"version":7,"shownCount":2,"dontShowAgain":true}',
    ]) {
      await File('${store.directory.path}/state.json').writeAsString(data);
      expect((await store.read()).dontShowAgain, false);
    }
  });

  test('write failure does not break subsequent guide writes', () async {
    final blocked = File('${root.path}/blocked');
    await blocked.writeAsString('not a directory');
    final retry = CoffeeGuideStore(Directory(blocked.path));
    await expectLater(
      retry.save(const CoffeeGuideState(shownCount: 1)),
      throwsA(isA<FileSystemException>()),
    );
    expect((await retry.read()).dontShowAgain, false);
    await blocked.delete();
    await retry.save(const CoffeeGuideState(shownCount: 1));
    expect((await retry.read()).shownCount, 1);
  });
}
