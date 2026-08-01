import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  const canonicalizer = AtlasCanonicalJson();
  final inputDirectory = Directory('test/vectors/jcs_reference/input');
  final names =
      inputDirectory
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .toList(growable: false)
        ..sort();

  for (final name in names) {
    test('matches pinned JCS reference vector $name', () {
      final input = File(
        'test/vectors/jcs_reference/input/$name',
      ).readAsBytesSync();
      final expected = File(
        'test/vectors/jcs_reference/output/$name',
      ).readAsBytesSync();

      final result = canonicalizer.canonicalizeUtf8(Uint8List.fromList(input));

      expect(result.canonicalBytes, expected);
    });
  }
}
