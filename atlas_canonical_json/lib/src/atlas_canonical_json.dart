import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'atlas_canonical_json_result.dart';
import 'jcs_encoder.dart';
import 'json_value_validator.dart';
import 'strict_json_parser.dart';

/// Restricted RFC 8785 canonicalization for Atlas technical payloads.
final class AtlasCanonicalJson {
  const AtlasCanonicalJson();

  /// Strictly parses UTF-8 JSON, canonicalizes it, and computes SHA-256.
  AtlasCanonicalJsonResult canonicalizeUtf8(Uint8List source) {
    final value = StrictJsonParser.parseUtf8(source);
    return _resultFor(value);
  }

  /// Validates and canonicalizes an in-memory JSON-compatible value.
  AtlasCanonicalJsonResult canonicalizeValue(Object? value) {
    final validated = validateProgrammaticJsonValue(value);
    return _resultFor(validated);
  }

  AtlasCanonicalJsonResult _resultFor(Object? value) {
    final bytes = const JcsEncoder().encode(value);
    return AtlasCanonicalJsonResult.internal(
      canonicalBytes: bytes,
      checksum: 'sha256:${sha256.convert(bytes)}',
    );
  }
}
