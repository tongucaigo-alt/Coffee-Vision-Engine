import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  test('matches 256 deterministic independent RFC 8785 number vectors', () {
    final root =
        jsonDecode(
              File(
                'test/vectors/rfc8785_random_numbers.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(root['generator'], 'rfc8785 0.1.4');
    expect(root['seed'], '0xA71A5');
    final vectors = root['vectors']! as List<Object?>;

    for (final rawVector in vectors) {
      final vector = rawVector! as Map<String, Object?>;
      final bits = vector['bits']! as String;
      final expected = vector['expected']! as String;
      final result = const AtlasCanonicalJson().canonicalizeValue(
        _doubleFromHex(bits),
      );

      expect(utf8.decode(result.canonicalBytes), expected, reason: bits);
    }
  });
}

double _doubleFromHex(String hex) {
  final data = ByteData(8)
    ..setUint32(0, int.parse(hex.substring(0, 8), radix: 16))
    ..setUint32(4, int.parse(hex.substring(8), radix: 16));
  return data.getFloat64(0);
}
