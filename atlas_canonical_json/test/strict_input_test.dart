import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  const canonicalizer = AtlasCanonicalJson();

  AtlasCanonicalJsonResult parse(String value) =>
      canonicalizer.canonicalizeUtf8(Uint8List.fromList(utf8.encode(value)));

  Matcher failure(AtlasCanonicalJsonFailure code) => throwsA(
    isA<AtlasCanonicalJsonException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );

  test('rejects UTF-8 BOM', () {
    expect(
      () => canonicalizer.canonicalizeUtf8(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x7B, 0x7D]),
      ),
      failure(AtlasCanonicalJsonFailure.bomNotAllowed),
    );
  });

  test('rejects malformed UTF-8', () {
    expect(
      () => canonicalizer.canonicalizeUtf8(
        Uint8List.fromList([0x7B, 0x22, 0x78, 0x22, 0x3A, 0xC3, 0x28, 0x7D]),
      ),
      failure(AtlasCanonicalJsonFailure.invalidUtf8),
    );
  });

  test('rejects direct duplicate properties before canonicalization', () {
    expect(
      () => parse(r'''{"a":1,"a":2}'''),
      failure(AtlasCanonicalJsonFailure.duplicateProperty),
    );
  });

  test('rejects duplicate properties after escape decoding', () {
    expect(
      () => parse(r'''{"a":1,"\u0061":2}'''),
      failure(AtlasCanonicalJsonFailure.duplicateProperty),
    );
  });

  test('rejects lone high and low surrogate escapes', () {
    expect(
      () => parse(r'''"\ud800"'''),
      failure(AtlasCanonicalJsonFailure.invalidUnicodeScalar),
    );
    expect(
      () => parse(r'''"\udc00"'''),
      failure(AtlasCanonicalJsonFailure.invalidUnicodeScalar),
    );
  });

  test('rejects BMP and supplementary Unicode noncharacters', () {
    expect(
      () => parse(r'''"\ufdd0"'''),
      failure(AtlasCanonicalJsonFailure.unicodeNoncharacter),
    );
    expect(
      () => parse(r'''"\ud83f\udffe"'''),
      failure(AtlasCanonicalJsonFailure.unicodeNoncharacter),
    );
  });

  test('accepts exact safe-integer boundaries', () {
    expect(
      utf8.decode(parse('9007199254740991').canonicalBytes),
      '9007199254740991',
    );
    expect(
      utf8.decode(parse('-9007199254740991').canonicalBytes),
      '-9007199254740991',
    );
  });

  test('rejects integer tokens beyond the safe range', () {
    expect(
      () => parse('9007199254740992'),
      failure(AtlasCanonicalJsonFailure.unsafeInteger),
    );
    expect(
      () => parse('-9007199254740992'),
      failure(AtlasCanonicalJsonFailure.unsafeInteger),
    );
  });

  test('rejects every lexical form of negative zero', () {
    for (final value in ['-0', '-0.0', '-0e+10', '-1e-9999']) {
      expect(
        () => parse(value),
        failure(AtlasCanonicalJsonFailure.negativeZero),
        reason: value,
      );
    }
  });

  test('rejects positive binary64 overflow and underflow', () {
    expect(
      () => parse('1e9999'),
      failure(AtlasCanonicalJsonFailure.numberOutOfRange),
    );
    expect(
      () => parse('1e-9999'),
      failure(AtlasCanonicalJsonFailure.numberOutOfRange),
    );
  });

  test('accepts exact positive zero with non-zero exponent digits', () {
    for (final value in ['0e1', '0e+9999', '0.0e-1']) {
      expect(utf8.decode(parse(value).canonicalBytes), '0', reason: value);
    }
  });

  test('preserves non-NFC strings without normalizing them', () {
    const decomposed = 'e\u0301';
    final result = parse('"$decomposed"');

    expect(utf8.decode(result.canonicalBytes), '"$decomposed"');
    expect(utf8.decode(result.canonicalBytes), isNot('"é"'));
  });

  test('accepts all JSON root kinds and removes insignificant whitespace', () {
    for (final entry in {
      ' null ': 'null',
      '\r\ntrue\t': 'true',
      ' [ 1, 2 ] ': '[1,2]',
      ' { "b": 2, "a": 1 } ': r'''{"a":1,"b":2}''',
    }.entries) {
      expect(utf8.decode(parse(entry.key).canonicalBytes), entry.value);
    }
  });

  test('rejects malformed grammar and trailing data', () {
    for (final value in ['', '01', '[1,]', '{"a" 1}', '{}{}']) {
      expect(
        () => parse(value),
        failure(AtlasCanonicalJsonFailure.malformedJson),
        reason: value,
      );
    }
  });
}
