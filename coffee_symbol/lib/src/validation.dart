final RegExp _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
final RegExp _checksumPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _languagePattern = RegExp(
  r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$',
);

String validateIdentifier(String value, String name) {
  if (!_identifierPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      name,
      'must use the exact safe ASCII identifier grammar',
    );
  }
  return value;
}

int validateRevision(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be greater than zero');
  }
  return value;
}

String validateChecksum(String value, String name) {
  if (!_checksumPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      name,
      'must match sha256:<64-lowercase-hex>',
    );
  }
  return value;
}

String validateLanguage(String value) {
  if (!_languagePattern.hasMatch(value)) {
    throw ArgumentError.value(value, 'language', 'must be a valid BCP-47 tag');
  }
  return value;
}

String validateHumanText(String value, String name) {
  if (value.isEmpty || value.trim() != value) {
    throw ArgumentError.value(
      value,
      name,
      'must be non-empty without surrounding whitespace',
    );
  }
  for (final rune in value.runes) {
    if (rune <= 0x1f || (rune >= 0x7f && rune <= 0x9f)) {
      throw ArgumentError.value(value, name, 'must not contain controls');
    }
    if (_isCombiningMark(rune)) {
      throw ArgumentError.value(
        value,
        name,
        'must use precomposed Unicode NFC text',
      );
    }
  }
  return value;
}

String? validateOptionalText(String? value, String name) {
  if (value == null) return null;
  return validateHumanText(value, name);
}

bool _isCombiningMark(int rune) {
  return (rune >= 0x0300 && rune <= 0x036f) ||
      (rune >= 0x1ab0 && rune <= 0x1aff) ||
      (rune >= 0x1dc0 && rune <= 0x1dff) ||
      (rune >= 0x20d0 && rune <= 0x20ff) ||
      (rune >= 0xfe20 && rune <= 0xfe2f);
}

bool sameList<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
