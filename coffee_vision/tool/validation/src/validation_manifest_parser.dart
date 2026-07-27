import 'dart:convert';

import 'package:coffee_vision/coffee_vision.dart';

import 'validation_models.dart';

final class ValidationManifest {
  ValidationManifest({
    required this.schemaVersion,
    required Iterable<ValidationDatasetEntry> entries,
  }) : entries = List<ValidationDatasetEntry>.unmodifiable(entries);

  final String schemaVersion;
  final List<ValidationDatasetEntry> entries;
}

final class ValidationManifestException implements FormatException {
  const ValidationManifestException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'ValidationManifestException: $message';
}

final class ValidationManifestParser {
  const ValidationManifestParser();

  ValidationManifest parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const ValidationManifestException('Manifest JSON is invalid.');
    }
    final root = _object(decoded, 'manifest');
    _requireExactKeys(root, const {'schemaVersion', 'entries'}, 'manifest');
    final schemaVersion = _string(root['schemaVersion'], 'schemaVersion');
    if (schemaVersion != '1.0') {
      throw const ValidationManifestException(
        'schemaVersion must equal "1.0".',
      );
    }
    final rawEntries = root['entries'];
    if (rawEntries is! List<Object?>) {
      throw const ValidationManifestException('entries must be a JSON array.');
    }

    final sourceIds = <String>{};
    final entries = <ValidationDatasetEntry>[];
    for (var index = 0; index < rawEntries.length; index++) {
      final entry = _parseEntry(rawEntries[index], index);
      if (!sourceIds.add(entry.sourceId)) {
        throw ValidationManifestException(
          'entries[$index].sourceId must be unique.',
        );
      }
      entries.add(entry);
    }
    return ValidationManifest(schemaVersion: schemaVersion, entries: entries);
  }

  ValidationDatasetEntry _parseEntry(Object? value, int index) {
    final field = 'entries[$index]';
    final object = _object(value, field);
    _requireExactKeys(object, const {
      'sourceId',
      'relativePath',
      'surfaceType',
      'format',
      'ownership',
      'consent',
      'enabled',
      'contentChecksum',
    }, field);

    final sourceId = _nonEmptyString(object['sourceId'], '$field.sourceId');
    final relativePath = _nonEmptyString(
      object['relativePath'],
      '$field.relativePath',
    );
    _validateRelativePath(relativePath, '$field.relativePath');
    final surfaceType = switch (_string(
      object['surfaceType'],
      '$field.surfaceType',
    )) {
      'cup' => VisionSurfaceType.cup,
      'saucer' => VisionSurfaceType.saucer,
      _ => throw ValidationManifestException(
        '$field.surfaceType must be "cup" or "saucer".',
      ),
    };
    final format = switch (_string(object['format'], '$field.format')) {
      'png' => VisionImageFormat.png,
      'jpeg' => VisionImageFormat.jpeg,
      _ => throw ValidationManifestException(
        '$field.format must be "png" or "jpeg".',
      ),
    };
    final ownership = _nonEmptyString(object['ownership'], '$field.ownership');
    final consent = _nonEmptyString(object['consent'], '$field.consent');
    final enabled = object['enabled'];
    if (enabled is! bool) {
      throw ValidationManifestException('$field.enabled must be a boolean.');
    }
    final checksum = _string(
      object['contentChecksum'],
      '$field.contentChecksum',
    );
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(checksum)) {
      throw ValidationManifestException(
        '$field.contentChecksum must use sha256:<64 lowercase hex> format.',
      );
    }

    return ValidationDatasetEntry(
      sourceId: sourceId,
      relativePath: relativePath.replaceAll('\\', '/'),
      surfaceType: surfaceType,
      format: format,
      ownership: ownership,
      consent: consent,
      enabled: enabled,
      contentChecksum: checksum,
    );
  }

  Map<String, Object?> _object(Object? value, String field) {
    if (value is! Map<Object?, Object?>) {
      throw ValidationManifestException('$field must be a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ValidationManifestException('$field keys must be strings.');
      }
      result[key] = entry.value;
    }
    return result;
  }

  String _string(Object? value, String field) {
    if (value is! String) {
      throw ValidationManifestException('$field must be a string.');
    }
    return value;
  }

  String _nonEmptyString(Object? value, String field) {
    final result = _string(value, field).trim();
    if (result.isEmpty) {
      throw ValidationManifestException('$field must not be empty.');
    }
    return result;
  }

  void _requireExactKeys(
    Map<String, Object?> object,
    Set<String> expected,
    String field,
  ) {
    final actual = object.keys.toSet();
    final missing = expected.difference(actual).toList()..sort();
    final unknown = actual.difference(expected).toList()..sort();
    if (missing.isNotEmpty) {
      throw ValidationManifestException(
        '$field is missing fields: ${missing.join(', ')}.',
      );
    }
    if (unknown.isNotEmpty) {
      throw ValidationManifestException(
        '$field contains unknown fields: ${unknown.join(', ')}.',
      );
    }
  }

  void _validateRelativePath(String value, String field) {
    if (value.startsWith('/') ||
        value.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      throw ValidationManifestException('$field must be relative.');
    }
    final segments = value.split(RegExp(r'[\\/]'));
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw ValidationManifestException(
        '$field must not contain empty, dot, or parent segments.',
      );
    }
  }
}
