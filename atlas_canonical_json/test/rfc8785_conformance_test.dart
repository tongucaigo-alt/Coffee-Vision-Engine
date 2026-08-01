import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  const canonicalizer = AtlasCanonicalJson();

  test('matches the RFC 8785 canonicalization sample', () {
    const source = r'''
      {
        "numbers": [333333333.33333329, 1E30, 4.50, 2e-3, 0.000000000000000000000000001],
        "string": "\u20ac$\u000F\u000aA'\u0042\u0022\u005c\\\"\/",
        "literals": [null, true, false]
      }
    ''';
    const expected =
        r'''{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27],"string":"€$\u000f\nA'B\"\\\\\"/"}''';

    final result = canonicalizer.canonicalizeUtf8(
      Uint8List.fromList(utf8.encode(source)),
    );

    expect(utf8.decode(result.canonicalBytes), expected);
  });

  test('uses unsigned UTF-16 code-unit property ordering', () {
    const source = r'''
      {
        "\u20ac": "Euro Sign",
        "\r": "Carriage Return",
        "\ufb33": "Hebrew Letter Dalet With Dagesh",
        "1": "One",
        "\ud83d\ude00": "Emoji: Grinning Face",
        "\u0080": "Control",
        "\u00f6": "Latin Small Letter O With Diaeresis"
      }
    ''';

    final result = canonicalizer.canonicalizeUtf8(
      Uint8List.fromList(utf8.encode(source)),
    );
    final decoded = jsonDecode(utf8.decode(result.canonicalBytes));

    expect((decoded as Map<String, Object?>).values.toList(), [
      'Carriage Return',
      'One',
      'Control',
      'Latin Small Letter O With Diaeresis',
      'Euro Sign',
      'Emoji: Grinning Face',
      'Hebrew Letter Dalet With Dagesh',
    ]);
  });

  test('matches RFC 8785 Appendix B finite number vectors', () {
    const vectors = <String, String>{
      '0000000000000000': '0',
      '0000000000000001': '5e-324',
      '8000000000000001': '-5e-324',
      '7fefffffffffffff': '1.7976931348623157e+308',
      'ffefffffffffffff': '-1.7976931348623157e+308',
      '4340000000000000': '9007199254740992',
      'c340000000000000': '-9007199254740992',
      '4430000000000000': '295147905179352830000',
      '44b52d02c7e14af5': '9.999999999999997e+22',
      '44b52d02c7e14af6': '1e+23',
      '44b52d02c7e14af7': '1.0000000000000001e+23',
      '444b1ae4d6e2ef4e': '999999999999999700000',
      '444b1ae4d6e2ef4f': '999999999999999900000',
      '444b1ae4d6e2ef50': '1e+21',
      '3eb0c6f7a0b5ed8c': '9.999999999999997e-7',
      '3eb0c6f7a0b5ed8d': '0.000001',
      '41b3de4355555553': '333333333.3333332',
      '41b3de4355555554': '333333333.33333325',
      '41b3de4355555555': '333333333.3333333',
      '41b3de4355555556': '333333333.3333334',
      '41b3de4355555557': '333333333.33333343',
      'becbf647612f3696': '-0.0000033333333333333333',
      '43143ff3c1cb0959': '1424953923781206.2',
    };

    for (final entry in vectors.entries) {
      final result = canonicalizer.canonicalizeValue(_doubleFromHex(entry.key));
      expect(
        utf8.decode(result.canonicalBytes),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('preserves array order while canonicalizing nested objects', () {
    final first = canonicalizer.canonicalizeValue([
      {'z': 1, 'a': 2},
      {'b': 3, 'a': 4},
    ]);
    final second = canonicalizer.canonicalizeValue([
      {'b': 3, 'a': 4},
      {'z': 1, 'a': 2},
    ]);

    expect(
      utf8.decode(first.canonicalBytes),
      r'''[{"a":2,"z":1},{"a":4,"b":3}]''',
    );
    expect(first, isNot(second));
  });

  test('equivalent object permutations produce identical bytes and hash', () {
    final first = canonicalizer.canonicalizeValue({
      'z': 1,
      'a': {'y': true, 'x': false},
    });
    final second = canonicalizer.canonicalizeValue({
      'a': {'x': false, 'y': true},
      'z': 1,
    });

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}

double _doubleFromHex(String hex) {
  final data = ByteData(8)
    ..setUint32(0, int.parse(hex.substring(0, 8), radix: 16))
    ..setUint32(4, int.parse(hex.substring(8), radix: 16));
  return data.getFloat64(0);
}
