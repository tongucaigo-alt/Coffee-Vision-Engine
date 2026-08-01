import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  const descriptorPath =
      '../docs/symbol/canonical-json/atlas_canonical_json_profile_r1.json';
  const canonicalizer = AtlasCanonicalJson();

  test('bootstrap descriptor is already canonical apart from final LF', () {
    final source = File(descriptorPath).readAsBytesSync();
    final result = canonicalizer.canonicalizeUtf8(Uint8List.fromList(source));
    final authored = utf8.decode(source).trimRight();

    expect(utf8.decode(result.canonicalBytes), authored);
    expect(result.canonicalBytes.last, isNot(0x0A));
  });

  test('descriptor is self-reference free and exact profile identity', () {
    final source = File(descriptorPath).readAsBytesSync();
    final decoded = jsonDecode(utf8.decode(source)) as Map<String, Object?>;

    expect(decoded['profileId'], 'atlas-canonical-json');
    expect(decoded['revision'], 1);
    expect(decoded, isNot(contains('canonicalJsonProfileRef')));
    expect(decoded, isNot(contains('profileChecksum')));
  });

  test('public revision identity equals canonical descriptor checksum', () {
    final source = File(descriptorPath).readAsBytesSync();
    final result = canonicalizer.canonicalizeUtf8(Uint8List.fromList(source));

    expect(
      AtlasCanonicalJsonProfile.revision1.profileId,
      'atlas-canonical-json',
    );
    expect(AtlasCanonicalJsonProfile.revision1.revision, 1);
    expect(AtlasCanonicalJsonProfile.revision1.checksum, result.checksum);
  });
}
