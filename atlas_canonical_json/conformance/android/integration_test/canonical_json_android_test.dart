import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const canonicalizer = AtlasCanonicalJson();

  testWidgets('matches the frozen revision-1 bytes and checksum', (
    tester,
  ) async {
    final descriptor = <String, Object?>{
      'checksum': {
        'algorithm': 'SHA-256',
        'format': 'sha256:<64-lowercase-hex>',
      },
      'inputRestrictions': {
        'arrays': 'preserve-order',
        'bom': 'reject',
        'duplicateObjectProperties': 'reject-after-escape-decoding',
        'integerMaximum': 9007199254740991,
        'integerMinimum': -9007199254740991,
        'negativeZero': 'reject',
        'nonFiniteNumbers': 'reject',
        'strings': 'preserve-exactly',
        'unicodeNoncharacters': 'reject',
        'unicodeScalars': 'required',
        'utf8': 'required',
      },
      'output': {
        'objectPropertyOrder': 'unsigned-utf16-code-units',
        'trailingNewline': false,
        'whitespace': 'none',
      },
      'profileId': 'atlas-canonical-json',
      'revision': 1,
      'standards': {
        'canonicalization': 'RFC 8785',
        'iJson': 'RFC 7493',
        'json': 'RFC 8259',
        'verifiedErrata': [6292, 7920],
      },
    };

    final result = canonicalizer.canonicalizeValue(descriptor);

    expect(result.checksum, AtlasCanonicalJsonProfile.revision1.checksum);
    expect(result.canonicalBytes.last, isNot(0x0A));
  });

  testWidgets('matches RFC canonical sample and strict failures', (
    tester,
  ) async {
    const source =
        r'''{"numbers":[333333333.33333329,1E30,4.50,2e-3,0.000000000000000000000000001],"literals":[null,true,false]}''';
    const expected =
        r'''{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27]}''';

    final result = canonicalizer.canonicalizeUtf8(
      Uint8List.fromList(utf8.encode(source)),
    );

    expect(utf8.decode(result.canonicalBytes), expected);
    expect(
      () => canonicalizer.canonicalizeValue(-0.0),
      throwsA(
        isA<AtlasCanonicalJsonException>().having(
          (error) => error.code,
          'code',
          AtlasCanonicalJsonFailure.negativeZero,
        ),
      ),
    );
  });
}
