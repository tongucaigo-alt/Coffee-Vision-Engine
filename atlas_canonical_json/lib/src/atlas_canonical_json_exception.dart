/// Stable failure categories for the Atlas Canonical JSON boundary.
enum AtlasCanonicalJsonFailure {
  invalidUtf8,
  bomNotAllowed,
  malformedJson,
  duplicateProperty,
  invalidUnicodeScalar,
  unicodeNoncharacter,
  unsafeInteger,
  numberOutOfRange,
  nonFiniteNumber,
  negativeZero,
  unsupportedValue,
  cyclicValue,
}

/// Fail-closed validation error produced by Atlas Canonical JSON.
final class AtlasCanonicalJsonException implements FormatException {
  const AtlasCanonicalJsonException(this.code, this.message, {this.offset});

  final AtlasCanonicalJsonFailure code;

  @override
  final String message;

  @override
  final int? offset;

  @override
  Object? get source => null;

  @override
  String toString() {
    final location = offset == null ? '' : ' at byte $offset';
    return 'AtlasCanonicalJsonException(${code.name}$location): $message';
  }
}
