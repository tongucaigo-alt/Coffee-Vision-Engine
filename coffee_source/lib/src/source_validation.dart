final RegExp _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
final RegExp _checksumPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _languagePattern = RegExp(
  r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$',
);
final RegExp _utcTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  r'(?:\.\d{1,9})?Z$',
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

String validateLanguage(String value, String name) {
  if (!_languagePattern.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'must be a valid BCP-47 tag');
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

String? validateOptionalChecksum(String? value, String name) {
  if (value == null) return null;
  return validateChecksum(value, name);
}

String? validateOptionalUtcTimestamp(String? value, String name) {
  if (value == null) return null;
  return validateUtcTimestamp(value, name);
}

String validateUtcTimestamp(String value, String name) {
  final match = _utcTimestampPattern.firstMatch(value);
  if (match == null) {
    throw ArgumentError.value(value, name, 'must be an exact UTC timestamp');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final daysInMonth = month >= 1 && month <= 12
      ? <int>[
          31,
          _isLeapYear(year) ? 29 : 28,
          31,
          30,
          31,
          30,
          31,
          31,
          30,
          31,
          30,
          31,
        ][month - 1]
      : 0;
  if (year == 0 ||
      day < 1 ||
      day > daysInMonth ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    throw ArgumentError.value(value, name, 'must be an exact UTC timestamp');
  }
  return value;
}

bool sameList<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _isCombiningMark(int rune) {
  return (rune >= 0x0300 && rune <= 0x036f) ||
      (rune >= 0x1ab0 && rune <= 0x1aff) ||
      (rune >= 0x1dc0 && rune <= 0x1dff) ||
      (rune >= 0x20d0 && rune <= 0x20ff) ||
      (rune >= 0xfe20 && rune <= 0xfe2f);
}

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
