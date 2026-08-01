import 'dart:collection';

import 'atlas_canonical_json_exception.dart';

const int minimumSafeInteger = -9007199254740991;
const int maximumSafeInteger = 9007199254740991;

Object? validateProgrammaticJsonValue(Object? value) {
  return _validateValue(value, HashSet<Object>.identity());
}

Object? _validateValue(Object? value, Set<Object> activeContainers) {
  if (value == null || value is bool) return value;
  if (value is String) {
    validateUnicodeString(value);
    return value;
  }
  if (value is int) {
    if (value < minimumSafeInteger || value > maximumSafeInteger) {
      throw const AtlasCanonicalJsonException(
        AtlasCanonicalJsonFailure.unsafeInteger,
        'Integer is outside the Atlas safe-integer range.',
      );
    }
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const AtlasCanonicalJsonException(
        AtlasCanonicalJsonFailure.nonFiniteNumber,
        'NaN and infinity are not valid Atlas JSON numbers.',
      );
    }
    if (value == 0.0 && value.isNegative) {
      throw const AtlasCanonicalJsonException(
        AtlasCanonicalJsonFailure.negativeZero,
        'Negative zero is not accepted by Atlas Canonical JSON.',
      );
    }
    return value;
  }
  if (value is List<Object?>) {
    _enterContainer(value, activeContainers);
    try {
      return List<Object?>.unmodifiable(
        value.map((element) => _validateValue(element, activeContainers)),
      );
    } finally {
      activeContainers.remove(value);
    }
  }
  if (value is Map<Object?, Object?>) {
    _enterContainer(value, activeContainers);
    try {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw const AtlasCanonicalJsonException(
            AtlasCanonicalJsonFailure.unsupportedValue,
            'JSON object keys must be strings.',
          );
        }
        validateUnicodeString(key);
        result[key] = _validateValue(entry.value, activeContainers);
      }
      return Map<String, Object?>.unmodifiable(result);
    } finally {
      activeContainers.remove(value);
    }
  }

  throw AtlasCanonicalJsonException(
    AtlasCanonicalJsonFailure.unsupportedValue,
    'Unsupported programmatic JSON value: ${value.runtimeType}.',
  );
}

void _enterContainer(Object value, Set<Object> activeContainers) {
  if (!activeContainers.add(value)) {
    throw const AtlasCanonicalJsonException(
      AtlasCanonicalJsonFailure.cyclicValue,
      'Programmatic JSON values must not contain cycles.',
    );
  }
}

void validateUnicodeString(String value) {
  for (var index = 0; index < value.length; index++) {
    final first = value.codeUnitAt(index);
    final int codePoint;
    if (_isHighSurrogate(first)) {
      if (index + 1 >= value.length) {
        _invalidScalar();
      }
      final second = value.codeUnitAt(index + 1);
      if (!_isLowSurrogate(second)) {
        _invalidScalar();
      }
      codePoint = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00);
      index++;
    } else if (_isLowSurrogate(first)) {
      _invalidScalar();
    } else {
      codePoint = first;
    }

    if (isUnicodeNoncharacter(codePoint)) {
      throw const AtlasCanonicalJsonException(
        AtlasCanonicalJsonFailure.unicodeNoncharacter,
        'Unicode noncharacters are not accepted by Atlas Canonical JSON.',
      );
    }
  }
}

Never _invalidScalar() {
  throw const AtlasCanonicalJsonException(
    AtlasCanonicalJsonFailure.invalidUnicodeScalar,
    'Strings must contain valid Unicode scalar values.',
  );
}

bool isUnicodeNoncharacter(int codePoint) =>
    (codePoint >= 0xFDD0 && codePoint <= 0xFDEF) ||
    (codePoint <= 0x10FFFF && (codePoint & 0xFFFE) == 0xFFFE);

bool isHighSurrogate(int codeUnit) => _isHighSurrogate(codeUnit);
bool isLowSurrogate(int codeUnit) => _isLowSurrogate(codeUnit);

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
