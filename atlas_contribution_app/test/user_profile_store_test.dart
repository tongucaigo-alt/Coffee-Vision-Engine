import 'dart:convert';
import 'dart:io';

import 'package:atlas_contribution_app/src/user_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late UserProfileStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-profile-test-');
    store = UserProfileStore(Directory('${root.path}/user-profile'));
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'optional fields persist, reopen and edit using schema version 3',
    () async {
      expect((await store.read()).addressName, isEmpty);
      expect((await store.read()).zodiac, isNull);
      await store.save(
        const UserProfile(addressName: '  Çağrı  ', zodiac: ZodiacSign.libra),
      );
      final reopened = UserProfileStore(store.directory);
      expect((await reopened.read()).addressName, 'Çağrı');
      expect((await reopened.read()).zodiac, ZodiacSign.libra);
      final json =
          jsonDecode(
                await File(
                  '${store.directory.path}/profile.json',
                ).readAsString(),
              )
              as Map;
      expect(json, {
        'version': 3,
        'addressName': 'Çağrı',
        'zodiac': 'libra',
        'useZodiacInReading': false,
        'age': null,
      });
      await reopened.save(const UserProfile());
      expect((await store.read()).addressName, isEmpty);
      expect((await store.read()).zodiac, isNull);
    },
  );

  test(
    'legacy zodiac never opts in; explicit preference persists and clears',
    () async {
      await store.directory.create();
      await File('${store.directory.path}/profile.json').writeAsString(
        jsonEncode({'version': 1, 'addressName': 'Eski ad', 'zodiac': 'libra'}),
      );
      final old = await store.read();
      expect(old.zodiac, ZodiacSign.libra);
      expect(old.useZodiacInReading, false);
      await store.save(old);
      expect(
        (await UserProfileStore(store.directory).read()).useZodiacInReading,
        false,
      );
      await store.save(
        const UserProfile(zodiac: ZodiacSign.libra, useZodiacInReading: true),
      );
      expect(
        (await UserProfileStore(store.directory).read()).useZodiacInReading,
        true,
      );
      await store.save(const UserProfile());
      expect((await store.read()).useZodiacInReading, false);
      await expectLater(
        store.save(const UserProfile(useZodiacInReading: true)),
        throwsArgumentError,
      );
    },
  );

  test(
    'age is optional in older profiles and persists, clears and deletes',
    () async {
      await store.directory.create();
      final file = File('${store.directory.path}/profile.json');
      for (final version in [1, 2]) {
        await file.writeAsString(
          jsonEncode({
            'version': version,
            'addressName': '',
            'zodiac': null,
            if (version == 2) 'useZodiacInReading': false,
          }),
        );
        expect((await store.read()).age, isNull);
      }
      for (final age in [18, 65, 120]) {
        await store.save(UserProfile(age: age));
        expect((await UserProfileStore(store.directory).read()).age, age);
      }
      await store.save(const UserProfile());
      expect((await store.read()).age, isNull);
      await store.save(const UserProfile(age: 60));
      await store.delete();
      expect((await store.read()).age, isNull);
    },
  );

  test(
    'invalid ages never replace a valid profile or silently normalize on read',
    () async {
      await store.save(const UserProfile(age: 60));
      for (final age in [-1, 0, 17, 121]) {
        await expectLater(
          store.save(UserProfile(age: age)),
          throwsArgumentError,
        );
        expect((await store.read()).age, 60);
      }
      final file = File('${store.directory.path}/profile.json');
      for (final age in [17, 121, '60', 60.5, true]) {
        final text = jsonEncode({
          'version': 3,
          'addressName': '',
          'zodiac': null,
          'useZodiacInReading': false,
          'age': age,
        });
        await file.writeAsString(text);
        await expectLater(store.read(), throwsFormatException);
        expect(await file.readAsString(), text);
      }
    },
  );

  test(
    'delete clears committed and interrupted profile, preserves sibling data',
    () async {
      final sibling = await File(
        '${root.path}/keep.json',
      ).writeAsString('retained');
      await store.save(const UserProfile(addressName: 'Silinecek'));
      await File(
        '${store.directory.path}/profile.pending',
      ).writeAsString('old-private-data');
      await store.delete();
      expect(await store.directory.list().toList(), isEmpty);
      expect(
        (await UserProfileStore(store.directory).read()).addressName,
        isEmpty,
      );
      expect(await sibling.readAsString(), 'retained');
      await store.delete();
    },
  );

  test('multiple store instances serialize saves and deletion', () async {
    final other = UserProfileStore(store.directory);
    await Future.wait([
      store.save(const UserProfile(addressName: 'First')),
      other.save(const UserProfile(addressName: 'Second')),
      store.delete(),
    ]);
    expect((await other.read()).addressName, isEmpty);
    expect(await store.directory.list().toList(), isEmpty);
  });

  test('malformed or future schema is reported without rewriting it', () async {
    await store.directory.create();
    for (final data in [
      'broken',
      '{"version":2,"addressName":"Future"}',
      '{"version":1,"addressName":"Name","zodiac":"unknown"}',
    ]) {
      final file = await File(
        '${store.directory.path}/profile.json',
      ).writeAsString(data);
      await expectLater(store.read(), throwsFormatException);
      expect(await file.readAsString(), data);
    }
    await store.delete();
    await store.save(const UserProfile(addressName: 'Recovered'));
    expect((await store.read()).addressName, 'Recovered');
  });

  test(
    'failed write is reported and does not poison subsequent operations',
    () async {
      await File(store.directory.path).writeAsString('blocked');
      await expectLater(
        store.save(const UserProfile()),
        throwsA(isA<FileSystemException>()),
      );
      await File(store.directory.path).delete();
      await store.save(const UserProfile(zodiac: ZodiacSign.pisces));
      expect((await store.read()).zodiac, ZodiacSign.pisces);
    },
  );
}
