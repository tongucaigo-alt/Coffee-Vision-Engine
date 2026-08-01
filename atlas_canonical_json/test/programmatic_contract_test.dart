import 'dart:convert';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:test/test.dart';

void main() {
  const canonicalizer = AtlasCanonicalJson();

  Matcher failure(AtlasCanonicalJsonFailure code) => throwsA(
    isA<AtlasCanonicalJsonException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );

  test('computes exact lowercase prefixed SHA-256', () {
    final result = canonicalizer.canonicalizeValue(<String, Object?>{});

    expect(utf8.decode(result.canonicalBytes), '{}');
    expect(
      result.checksum,
      'sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a',
    );
  });

  test('returns runtime-unmodifiable defensive bytes', () {
    final source = <String, Object?>{'a': 1};
    final result = canonicalizer.canonicalizeValue(source);
    source['a'] = 2;

    expect(utf8.decode(result.canonicalBytes), r'''{"a":1}''');
    expect(() => result.canonicalBytes.add(0), throwsUnsupportedError);
    expect(() => result.canonicalBytes[0] = 0, throwsUnsupportedError);
  });

  test('rejects non-string map keys and unsupported objects', () {
    expect(
      () => canonicalizer.canonicalizeValue(<Object?, Object?>{1: 'value'}),
      failure(AtlasCanonicalJsonFailure.unsupportedValue),
    );
    expect(
      () => canonicalizer.canonicalizeValue(DateTime.utc(2026)),
      failure(AtlasCanonicalJsonFailure.unsupportedValue),
    );
  });

  test('rejects cyclic lists and maps without retaining hidden state', () {
    final list = <Object?>[];
    list.add(list);
    final map = <String, Object?>{};
    map['self'] = map;

    expect(
      () => canonicalizer.canonicalizeValue(list),
      failure(AtlasCanonicalJsonFailure.cyclicValue),
    );
    expect(
      () => canonicalizer.canonicalizeValue(map),
      failure(AtlasCanonicalJsonFailure.cyclicValue),
    );
    expect(canonicalizer.canonicalizeValue({'ok': true}), isNotNull);
  });

  test('allows shared acyclic containers', () {
    final shared = <Object?>[1, 2];
    final result = canonicalizer.canonicalizeValue([shared, shared]);

    expect(utf8.decode(result.canonicalBytes), '[[1,2],[1,2]]');
  });

  test('rejects non-finite doubles and negative zero', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => canonicalizer.canonicalizeValue(value),
        failure(AtlasCanonicalJsonFailure.nonFiniteNumber),
      );
    }
    expect(
      () => canonicalizer.canonicalizeValue(-0.0),
      failure(AtlasCanonicalJsonFailure.negativeZero),
    );
  });

  test('rejects unsafe programmatic integers', () {
    expect(
      () => canonicalizer.canonicalizeValue(9007199254740992),
      failure(AtlasCanonicalJsonFailure.unsafeInteger),
    );
    expect(
      () => canonicalizer.canonicalizeValue(-9007199254740992),
      failure(AtlasCanonicalJsonFailure.unsafeInteger),
    );
  });

  test('rejects invalid programmatic Unicode and preserves valid text', () {
    expect(
      () => canonicalizer.canonicalizeValue(String.fromCharCode(0xD800)),
      failure(AtlasCanonicalJsonFailure.invalidUnicodeScalar),
    );
    expect(
      () => canonicalizer.canonicalizeValue(String.fromCharCode(0xFFFF)),
      failure(AtlasCanonicalJsonFailure.unicodeNoncharacter),
    );
    expect(
      utf8.decode(canonicalizer.canonicalizeValue(' A ').canonicalBytes),
      '" A "',
    );
  });

  test(
    'repeated canonicalization is deterministic with safe value semantics',
    () {
      final first = canonicalizer.canonicalizeValue({
        'text': 'Atlas',
        'values': [null, true, 1.5],
      });
      final second = canonicalizer.canonicalizeValue({
        'values': [null, true, 1.5],
        'text': 'Atlas',
      });

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains(first.checksum));
      expect(first.toString(), isNot(contains('"Atlas"')));
      expect(first.toString(), isNot(contains('values')));
    },
  );

  test('exception toString exposes category and safe offset only', () {
    const error = AtlasCanonicalJsonException(
      AtlasCanonicalJsonFailure.malformedJson,
      'Invalid JSON.',
      offset: 3,
    );

    expect(error.toString(), contains('malformedJson'));
    expect(error.toString(), contains('byte 3'));
    expect(error.source, isNull);
  });
}
