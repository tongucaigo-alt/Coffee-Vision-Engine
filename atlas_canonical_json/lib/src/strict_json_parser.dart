import 'dart:convert';
import 'dart:typed_data';

import 'atlas_canonical_json_exception.dart';
import 'json_value_validator.dart';

final class StrictJsonParser {
  StrictJsonParser._(this._source);

  static Object? parseUtf8(Uint8List source) {
    if (source.length >= 3 &&
        source[0] == 0xEF &&
        source[1] == 0xBB &&
        source[2] == 0xBF) {
      throw const AtlasCanonicalJsonException(
        AtlasCanonicalJsonFailure.bomNotAllowed,
        'UTF-8 BOM is not accepted by Atlas Canonical JSON.',
        offset: 0,
      );
    }

    final String decoded;
    try {
      decoded = utf8.decode(source, allowMalformed: false);
    } on FormatException catch (error) {
      throw AtlasCanonicalJsonException(
        AtlasCanonicalJsonFailure.invalidUtf8,
        'Input must be well-formed UTF-8.',
        offset: error.offset,
      );
    }
    return StrictJsonParser._(decoded)._parseDocument();
  }

  final String _source;
  var _index = 0;

  Object? _parseDocument() {
    _skipWhitespace();
    if (_isAtEnd) _malformed('JSON input is empty.');
    final result = _parseValue();
    _skipWhitespace();
    if (!_isAtEnd) _malformed('Unexpected data after the root JSON value.');
    return result;
  }

  Object? _parseValue() {
    if (_isAtEnd) _malformed('Unexpected end of JSON input.');
    return switch (_source.codeUnitAt(_index)) {
      0x6E => _parseLiteral('null', null),
      0x74 => _parseLiteral('true', true),
      0x66 => _parseLiteral('false', false),
      0x22 => _parseString(),
      0x5B => _parseArray(),
      0x7B => _parseObject(),
      0x2D || >= 0x30 && <= 0x39 => _parseNumber(),
      _ => _malformed('Unexpected JSON token.'),
    };
  }

  Object? _parseLiteral(String literal, Object? value) {
    if (!_source.startsWith(literal, _index)) {
      _malformed('Invalid JSON literal.');
    }
    _index += literal.length;
    return value;
  }

  List<Object?> _parseArray() {
    _index++;
    _skipWhitespace();
    if (_consume(0x5D)) return const <Object?>[];

    final result = <Object?>[];
    while (true) {
      result.add(_parseValue());
      _skipWhitespace();
      if (_consume(0x5D)) return List<Object?>.unmodifiable(result);
      _expect(0x2C, 'Expected a comma between array elements.');
      _skipWhitespace();
    }
  }

  Map<String, Object?> _parseObject() {
    _index++;
    _skipWhitespace();
    if (_consume(0x7D)) return const <String, Object?>{};

    final result = <String, Object?>{};
    while (true) {
      if (_isAtEnd || _source.codeUnitAt(_index) != 0x22) {
        _malformed('JSON object property names must be strings.');
      }
      final keyOffset = _index;
      final key = _parseString();
      if (result.containsKey(key)) {
        _error(
          AtlasCanonicalJsonFailure.duplicateProperty,
          'Duplicate JSON object property after escape decoding.',
          keyOffset,
        );
      }
      _skipWhitespace();
      _expect(0x3A, 'Expected a colon after the object property name.');
      _skipWhitespace();
      result[key] = _parseValue();
      _skipWhitespace();
      if (_consume(0x7D)) return Map<String, Object?>.unmodifiable(result);
      _expect(0x2C, 'Expected a comma between object properties.');
      _skipWhitespace();
    }
  }

  String _parseString() {
    _index++;
    final result = StringBuffer();
    while (!_isAtEnd) {
      final sourceOffset = _index;
      final codeUnit = _source.codeUnitAt(_index++);
      if (codeUnit == 0x22) return result.toString();
      if (codeUnit == 0x5C) {
        _parseEscape(result, sourceOffset);
        continue;
      }
      if (codeUnit < 0x20) {
        _malformed('Unescaped control character in JSON string.', sourceOffset);
      }
      if (isHighSurrogate(codeUnit)) {
        if (_isAtEnd) _invalidScalar(sourceOffset);
        final low = _source.codeUnitAt(_index);
        if (!isLowSurrogate(low)) _invalidScalar(sourceOffset);
        _index++;
        _writeCodePoint(
          result,
          0x10000 + ((codeUnit - 0xD800) << 10) + (low - 0xDC00),
          sourceOffset,
        );
      } else if (isLowSurrogate(codeUnit)) {
        _invalidScalar(sourceOffset);
      } else {
        _writeCodePoint(result, codeUnit, sourceOffset);
      }
    }
    _malformed('Unterminated JSON string.');
  }

  void _parseEscape(StringBuffer result, int sourceOffset) {
    if (_isAtEnd) _malformed('Unterminated JSON escape.', sourceOffset);
    final escaped = _source.codeUnitAt(_index++);
    switch (escaped) {
      case 0x22:
      case 0x2F:
      case 0x5C:
        result.writeCharCode(escaped);
        return;
      case 0x62:
        result.writeCharCode(0x08);
        return;
      case 0x66:
        result.writeCharCode(0x0C);
        return;
      case 0x6E:
        result.writeCharCode(0x0A);
        return;
      case 0x72:
        result.writeCharCode(0x0D);
        return;
      case 0x74:
        result.writeCharCode(0x09);
        return;
      case 0x75:
        final first = _parseHexCodeUnit(sourceOffset);
        if (isHighSurrogate(first)) {
          if (_index + 1 >= _source.length ||
              _source.codeUnitAt(_index) != 0x5C ||
              _source.codeUnitAt(_index + 1) != 0x75) {
            _invalidScalar(sourceOffset);
          }
          _index += 2;
          final second = _parseHexCodeUnit(sourceOffset);
          if (!isLowSurrogate(second)) _invalidScalar(sourceOffset);
          _writeCodePoint(
            result,
            0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00),
            sourceOffset,
          );
        } else if (isLowSurrogate(first)) {
          _invalidScalar(sourceOffset);
        } else {
          _writeCodePoint(result, first, sourceOffset);
        }
        return;
      default:
        _malformed('Invalid JSON escape sequence.', sourceOffset);
    }
  }

  int _parseHexCodeUnit(int sourceOffset) {
    if (_index + 4 > _source.length) {
      _malformed('Incomplete Unicode escape.', sourceOffset);
    }
    var value = 0;
    for (var count = 0; count < 4; count++) {
      final codeUnit = _source.codeUnitAt(_index++);
      final digit = switch (codeUnit) {
        >= 0x30 && <= 0x39 => codeUnit - 0x30,
        >= 0x41 && <= 0x46 => codeUnit - 0x41 + 10,
        >= 0x61 && <= 0x66 => codeUnit - 0x61 + 10,
        _ => -1,
      };
      if (digit < 0) _malformed('Invalid Unicode escape.', sourceOffset);
      value = (value << 4) | digit;
    }
    return value;
  }

  num _parseNumber() {
    final start = _index;
    _consume(0x2D);
    if (_isAtEnd) _malformed('Incomplete JSON number.', start);

    if (_consume(0x30)) {
      if (!_isAtEnd && _isDigit(_source.codeUnitAt(_index))) {
        _malformed('JSON numbers must not contain leading zeroes.', start);
      }
    } else {
      _consumeDigits(required: true, sourceOffset: start);
    }

    var hasFractionOrExponent = false;
    if (_consume(0x2E)) {
      hasFractionOrExponent = true;
      _consumeDigits(required: true, sourceOffset: start);
    }
    if (!_isAtEnd &&
        (_source.codeUnitAt(_index) == 0x65 ||
            _source.codeUnitAt(_index) == 0x45)) {
      hasFractionOrExponent = true;
      _index++;
      if (!_isAtEnd &&
          (_source.codeUnitAt(_index) == 0x2B ||
              _source.codeUnitAt(_index) == 0x2D)) {
        _index++;
      }
      _consumeDigits(required: true, sourceOffset: start);
    }

    final token = _source.substring(start, _index);
    if (!hasFractionOrExponent) {
      final integer = BigInt.parse(token);
      if (integer == BigInt.zero && token.startsWith('-')) {
        _negativeZero(start);
      }
      if (integer < BigInt.from(minimumSafeInteger) ||
          integer > BigInt.from(maximumSafeInteger)) {
        _error(
          AtlasCanonicalJsonFailure.unsafeInteger,
          'Integer is outside the Atlas safe-integer range.',
          start,
        );
      }
      return integer.toInt();
    }

    final value = double.tryParse(token);
    if (value == null || !value.isFinite) {
      _error(
        AtlasCanonicalJsonFailure.numberOutOfRange,
        'JSON number is outside the finite binary64 range.',
        start,
      );
    }
    if (value == 0.0 && token.startsWith('-')) _negativeZero(start);
    if (value == 0.0 && _containsNonZeroSignificandDigit(token)) {
      _error(
        AtlasCanonicalJsonFailure.numberOutOfRange,
        'JSON number underflows the finite binary64 range.',
        start,
      );
    }
    return value;
  }

  void _consumeDigits({required bool required, required int sourceOffset}) {
    final start = _index;
    while (!_isAtEnd && _isDigit(_source.codeUnitAt(_index))) {
      _index++;
    }
    if (required && start == _index) {
      _malformed('Expected a digit in JSON number.', sourceOffset);
    }
  }

  bool _containsNonZeroSignificandDigit(String token) {
    for (final codeUnit in token.codeUnits) {
      if (codeUnit == 0x65 || codeUnit == 0x45) return false;
      if (codeUnit >= 0x31 && codeUnit <= 0x39) return true;
    }
    return false;
  }

  void _writeCodePoint(StringBuffer result, int codePoint, int sourceOffset) {
    if (isUnicodeNoncharacter(codePoint)) {
      _error(
        AtlasCanonicalJsonFailure.unicodeNoncharacter,
        'Unicode noncharacters are not accepted by Atlas Canonical JSON.',
        sourceOffset,
      );
    }
    result.writeCharCode(codePoint);
  }

  Never _invalidScalar(int sourceOffset) => _error(
    AtlasCanonicalJsonFailure.invalidUnicodeScalar,
    'Strings must contain valid Unicode scalar values.',
    sourceOffset,
  );

  Never _negativeZero(int sourceOffset) => _error(
    AtlasCanonicalJsonFailure.negativeZero,
    'Negative zero is not accepted by Atlas Canonical JSON.',
    sourceOffset,
  );

  void _skipWhitespace() {
    while (!_isAtEnd) {
      final codeUnit = _source.codeUnitAt(_index);
      if (codeUnit != 0x20 &&
          codeUnit != 0x09 &&
          codeUnit != 0x0A &&
          codeUnit != 0x0D) {
        return;
      }
      _index++;
    }
  }

  void _expect(int codeUnit, String message) {
    if (!_consume(codeUnit)) _malformed(message);
  }

  bool _consume(int codeUnit) {
    if (_isAtEnd || _source.codeUnitAt(_index) != codeUnit) return false;
    _index++;
    return true;
  }

  bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
  bool get _isAtEnd => _index >= _source.length;

  Never _malformed(String message, [int? sourceOffset]) => _error(
    AtlasCanonicalJsonFailure.malformedJson,
    message,
    sourceOffset ?? _index,
  );

  Never _error(
    AtlasCanonicalJsonFailure code,
    String message,
    int sourceOffset,
  ) {
    throw AtlasCanonicalJsonException(
      code,
      message,
      offset: utf8.encode(_source.substring(0, sourceOffset)).length,
    );
  }
}
