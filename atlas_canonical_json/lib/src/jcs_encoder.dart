import 'dart:convert';

final class JcsEncoder {
  const JcsEncoder();

  List<int> encode(Object? value) {
    final output = StringBuffer();
    _writeValue(output, value);
    return utf8.encode(output.toString());
  }

  void _writeValue(StringBuffer output, Object? value) {
    if (value == null) {
      output.write('null');
    } else if (value is bool) {
      output.write(value ? 'true' : 'false');
    } else if (value is int) {
      output.write(value);
    } else if (value is double) {
      output.write(_formatDouble(value));
    } else if (value is String) {
      _writeString(output, value);
    } else if (value is List<Object?>) {
      _writeArray(output, value);
    } else if (value is Map<String, Object?>) {
      _writeObject(output, value);
    } else {
      throw StateError('Validated JSON graph contains ${value.runtimeType}.');
    }
  }

  void _writeArray(StringBuffer output, List<Object?> values) {
    output.writeCharCode(0x5B);
    for (var index = 0; index < values.length; index++) {
      if (index != 0) output.writeCharCode(0x2C);
      _writeValue(output, values[index]);
    }
    output.writeCharCode(0x5D);
  }

  void _writeObject(StringBuffer output, Map<String, Object?> value) {
    final keys = value.keys.toList(growable: false)..sort(_compareUtf16);
    output.writeCharCode(0x7B);
    for (var index = 0; index < keys.length; index++) {
      if (index != 0) output.writeCharCode(0x2C);
      final key = keys[index];
      _writeString(output, key);
      output.writeCharCode(0x3A);
      _writeValue(output, value[key]);
    }
    output.writeCharCode(0x7D);
  }

  void _writeString(StringBuffer output, String value) {
    output.writeCharCode(0x22);
    for (var index = 0; index < value.length; index++) {
      final codeUnit = value.codeUnitAt(index);
      switch (codeUnit) {
        case 0x08:
          output.write(r'\b');
          continue;
        case 0x09:
          output.write(r'\t');
          continue;
        case 0x0A:
          output.write(r'\n');
          continue;
        case 0x0C:
          output.write(r'\f');
          continue;
        case 0x0D:
          output.write(r'\r');
          continue;
        case 0x22:
          output.write(r'\"');
          continue;
        case 0x5C:
          output.write(r'\\');
          continue;
        default:
          if (codeUnit < 0x20) {
            output
              ..write(r'\u')
              ..write(codeUnit.toRadixString(16).padLeft(4, '0'));
          } else {
            output.writeCharCode(codeUnit);
          }
      }
    }
    output.writeCharCode(0x22);
  }

  String _formatDouble(double value) {
    var result = value.toString();
    final exponentIndex = result.indexOf('e');
    if (exponentIndex >= 0) {
      var mantissa = result.substring(0, exponentIndex);
      if (mantissa.endsWith('.0')) {
        mantissa = mantissa.substring(0, mantissa.length - 2);
      }
      return '$mantissa${result.substring(exponentIndex)}';
    }
    if (result.endsWith('.0')) {
      result = result.substring(0, result.length - 2);
    }
    return result;
  }

  int _compareUtf16(String left, String right) {
    final length = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final difference = left.codeUnitAt(index) - right.codeUnitAt(index);
      if (difference != 0) return difference;
    }
    return left.length - right.length;
  }
}
