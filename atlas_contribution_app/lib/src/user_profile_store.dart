import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

enum ZodiacSign {
  aries('Koç'),
  taurus('Boğa'),
  gemini('İkizler'),
  cancer('Yengeç'),
  leo('Aslan'),
  virgo('Başak'),
  libra('Terazi'),
  scorpio('Akrep'),
  sagittarius('Yay'),
  capricorn('Oğlak'),
  aquarius('Kova'),
  pisces('Balık');

  const ZodiacSign(this.label);
  final String label;
}

class UserProfile {
  const UserProfile({
    this.addressName = '',
    this.zodiac,
    this.useZodiacInReading = false,
  });
  final String addressName;
  final ZodiacSign? zodiac;
  final bool useZodiacInReading;
}

/// Kept outside contribution, AI and audit stores; never part of an export.
class UserProfileStore {
  UserProfileStore(this.directory);
  final Directory directory;
  static final Map<String, Future<void>> _writes = {};

  File get _file => File(path.join(directory.path, 'profile.json'));
  File get _pending => File(path.join(directory.path, 'profile.pending'));
  String get _key {
    final key = path.normalize(directory.absolute.path);
    return Platform.isWindows ? key.toLowerCase() : key;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final key = _key;
    final result = (_writes[key] ?? Future<void>.value()).then((_) => action());
    late final Future<void> tail;
    void clear() {
      if (identical(_writes[key], tail)) _writes.remove(key);
    }

    tail = result.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    _writes[key] = tail;
    return result;
  }

  Future<UserProfile> read() => _serial(() async {
    if (!await _file.exists()) return const UserProfile();
    final data = jsonDecode(await _file.readAsString());
    if (data is! Map ||
        ![1, 2].contains(data['version']) ||
        data['addressName'] is! String ||
        (data['zodiac'] != null && data['zodiac'] is! String)) {
      throw const FormatException('Unsupported profile');
    }
    final name = (data['addressName'] as String).trim();
    if (name.runes.length > 60) throw const FormatException('Invalid name');
    final zodiac = ZodiacSign.values
        .where((sign) => sign.name == data['zodiac'])
        .firstOrNull;
    if (data['zodiac'] != null && zodiac == null) {
      throw const FormatException('Invalid zodiac');
    }
    final useZodiac = data['version'] == 2 ? data['useZodiacInReading'] : false;
    if (useZodiac is! bool || (useZodiac && zodiac == null)) {
      throw const FormatException('Invalid zodiac preference');
    }
    return UserProfile(
      addressName: name,
      zodiac: zodiac,
      useZodiacInReading: useZodiac,
    );
  });

  Future<void> save(UserProfile profile) => _serial(() async {
    final name = profile.addressName.trim();
    if (name.runes.length > 60) throw ArgumentError('Name too long');
    if (profile.useZodiacInReading && profile.zodiac == null) {
      throw ArgumentError('Zodiac opt-in requires a selection');
    }
    await directory.create(recursive: true);
    await _pending.writeAsString(
      jsonEncode({
        'version': 2,
        'addressName': name,
        'zodiac': profile.zodiac?.name,
        'useZodiacInReading': profile.useZodiacInReading,
      }),
      flush: true,
    );
    // Atomic replacement on Android, with no old-profile backup to resurrect.
    await _pending.rename(_file.path);
  });

  Future<void> delete() => _serial(() async {
    // Remove an interrupted write first so it cannot restore deleted data.
    if (await _pending.exists()) await _pending.delete();
    if (await _file.exists()) await _file.delete();
  });
}
