import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'k6a_models.dart';

final class K6aDatasetException implements FormatException {
  const K6aDatasetException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'K6aDatasetException: $message';
}

final class K6aDatasetPreflight {
  const K6aDatasetPreflight();

  Future<K6aFrozenDataset> validate({
    required String datasetRoot,
    required String manifestPath,
    required String freezePath,
  }) async {
    final manifestFile = File(manifestPath);
    final freezeFile = File(freezePath);
    final List<int> manifestBytes;
    final String freezeSource;
    try {
      manifestBytes = await manifestFile.readAsBytes();
      freezeSource = await freezeFile.readAsString();
    } on FileSystemException {
      throw const K6aDatasetException(
        'Dataset manifest or freeze record could not be read.',
      );
    }

    final manifestChecksum = 'sha256:${sha256.convert(manifestBytes)}';
    final freeze = _parseFreeze(freezeSource);
    if (freeze['manifestSha256'] != manifestChecksum) {
      throw const K6aDatasetException(
        'Manifest checksum does not match the freeze record.',
      );
    }

    final expectedManifestPath = _normalizedAbsolutePath(
      _resolveRelativePath(datasetRoot, freeze['manifestRelativePath']!),
    );
    if (_normalizedAbsolutePath(manifestPath) != expectedManifestPath) {
      throw const K6aDatasetException(
        'Manifest path does not match the freeze record.',
      );
    }

    final manifestSource = utf8.decode(manifestBytes, allowMalformed: false);
    final entries = _parseManifest(manifestSource);
    _validateFreezeCounts(entries, freeze);
    await _validatePhysicalFiles(datasetRoot: datasetRoot, entries: entries);

    return K6aFrozenDataset(
      datasetVersion: freeze['datasetVersion']!,
      manifestChecksum: manifestChecksum,
      entries: entries,
    );
  }

  static Map<String, String> _parseFreeze(String source) {
    final values = <String, String>{};
    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator <= 0 || separator == line.length - 1) {
        throw const K6aDatasetException(
          'Freeze record contains an invalid line.',
        );
      }
      final key = line.substring(0, separator);
      final value = line.substring(separator + 1);
      if (values.containsKey(key)) {
        throw K6aDatasetException(
          'Freeze record contains duplicate key: $key.',
        );
      }
      values[key] = value;
    }

    const requiredKeys = {
      'datasetVersion',
      'physicalCupCount',
      'physicalSaucerCount',
      'physicalTotalCount',
      'enabledCupCount',
      'enabledSaucerCount',
      'enabledTotalCount',
      'disabledCount',
      'duplicateCount',
      'manifestSha256',
      'manifestRelativePath',
    };
    final missing = requiredKeys.difference(values.keys.toSet()).toList()
      ..sort();
    if (missing.isNotEmpty) {
      throw K6aDatasetException(
        'Freeze record is missing keys: ${missing.join(', ')}.',
      );
    }
    if (values['datasetVersion']!.trim() != values['datasetVersion'] ||
        values['datasetVersion']!.isEmpty) {
      throw const K6aDatasetException('datasetVersion is invalid.');
    }
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(values['manifestSha256']!)) {
      throw const K6aDatasetException('Manifest checksum format is invalid.');
    }
    _validateRelativePath(
      values['manifestRelativePath']!,
      'manifestRelativePath',
    );
    for (final key in const {
      'physicalCupCount',
      'physicalSaucerCount',
      'physicalTotalCount',
      'enabledCupCount',
      'enabledSaucerCount',
      'enabledTotalCount',
      'disabledCount',
      'duplicateCount',
    }) {
      final value = int.tryParse(values[key]!);
      if (value == null || value < 0) {
        throw K6aDatasetException('$key must be a non-negative integer.');
      }
    }
    return values;
  }

  static List<K6aDatasetEntry> _parseManifest(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const K6aDatasetException('Manifest JSON is invalid.');
    }
    final root = _object(decoded, 'manifest');
    _requireExactKeys(root, const {'schemaVersion', 'entries'}, 'manifest');
    if (_string(root['schemaVersion'], 'schemaVersion') != '1.0') {
      throw const K6aDatasetException('schemaVersion must equal "1.0".');
    }
    final rawEntries = root['entries'];
    if (rawEntries is! List<Object?>) {
      throw const K6aDatasetException('entries must be a JSON array.');
    }

    final sourceIds = <String>{};
    final relativePaths = <String>{};
    final entries = <K6aDatasetEntry>[];
    for (var index = 0; index < rawEntries.length; index++) {
      final field = 'entries[$index]';
      final object = _object(rawEntries[index], field);
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
      final sourceId = _identityString(object['sourceId'], '$field.sourceId');
      if (!sourceIds.add(sourceId)) {
        throw K6aDatasetException('$field.sourceId must be unique.');
      }
      final relativePath = _identityString(
        object['relativePath'],
        '$field.relativePath',
      ).replaceAll('\\', '/');
      _validateRelativePath(relativePath, '$field.relativePath');
      if (!relativePaths.add(relativePath)) {
        throw K6aDatasetException('$field.relativePath must be unique.');
      }
      final surfaceType = switch (_string(
        object['surfaceType'],
        '$field.surfaceType',
      )) {
        'cup' => K6aSurfaceType.cup,
        'saucer' => K6aSurfaceType.saucer,
        _ => throw K6aDatasetException(
          '$field.surfaceType must be "cup" or "saucer".',
        ),
      };
      final format = _string(object['format'], '$field.format');
      if (format != 'png' && format != 'jpeg') {
        throw K6aDatasetException('$field.format must be "png" or "jpeg".');
      }
      _validateFormatPath(format, relativePath, '$field.format');
      final ownership = _nonEmptyString(
        object['ownership'],
        '$field.ownership',
      );
      final consent = _nonEmptyString(object['consent'], '$field.consent');
      final enabled = object['enabled'];
      if (enabled is! bool) {
        throw K6aDatasetException('$field.enabled must be a boolean.');
      }
      final contentChecksum = _string(
        object['contentChecksum'],
        '$field.contentChecksum',
      );
      if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(contentChecksum)) {
        throw K6aDatasetException('$field.contentChecksum format is invalid.');
      }
      entries.add(
        K6aDatasetEntry(
          sourceId: sourceId,
          relativePath: relativePath,
          surfaceType: surfaceType,
          format: format,
          ownership: ownership,
          consent: consent,
          enabled: enabled,
          contentChecksum: contentChecksum,
        ),
      );
    }
    return List<K6aDatasetEntry>.unmodifiable(entries);
  }

  static void _validateFreezeCounts(
    List<K6aDatasetEntry> entries,
    Map<String, String> freeze,
  ) {
    final physicalCup = entries
        .where((entry) => entry.surfaceType == K6aSurfaceType.cup)
        .length;
    final physicalSaucer = entries.length - physicalCup;
    final enabled = entries.where((entry) => entry.enabled).toList();
    final enabledCup = enabled
        .where((entry) => entry.surfaceType == K6aSurfaceType.cup)
        .length;
    final enabledSaucer = enabled.length - enabledCup;
    final actual = <String, int>{
      'physicalCupCount': physicalCup,
      'physicalSaucerCount': physicalSaucer,
      'physicalTotalCount': entries.length,
      'enabledCupCount': enabledCup,
      'enabledSaucerCount': enabledSaucer,
      'enabledTotalCount': enabled.length,
      'disabledCount': entries.length - enabled.length,
      'duplicateCount': 0,
    };
    for (final item in actual.entries) {
      if (int.parse(freeze[item.key]!) != item.value) {
        throw K6aDatasetException(
          '${item.key} does not match the freeze record.',
        );
      }
    }
  }

  static Future<void> _validatePhysicalFiles({
    required String datasetRoot,
    required List<K6aDatasetEntry> entries,
  }) async {
    final checksums = <String>{};
    for (final entry in entries) {
      if (!checksums.add(entry.contentChecksum)) {
        throw K6aDatasetException(
          'Duplicate physical checksum found for ${entry.sourceId}.',
        );
      }
      if (!entry.enabled) continue;
      final file = File(_resolveRelativePath(datasetRoot, entry.relativePath));
      final List<int> bytes;
      try {
        bytes = await file.readAsBytes();
      } on FileSystemException {
        throw K6aDatasetException(
          'Enabled file could not be read for ${entry.sourceId}.',
        );
      }
      if (bytes.isEmpty) {
        throw K6aDatasetException(
          'Enabled file is empty for ${entry.sourceId}.',
        );
      }
      final checksum = 'sha256:${sha256.convert(bytes)}';
      if (checksum != entry.contentChecksum) {
        throw K6aDatasetException('Checksum mismatch for ${entry.sourceId}.');
      }
    }
  }

  static Map<String, Object?> _object(Object? value, String field) {
    if (value is! Map<Object?, Object?>) {
      throw K6aDatasetException('$field must be a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw K6aDatasetException('$field keys must be strings.');
      }
      result[entry.key! as String] = entry.value;
    }
    return result;
  }

  static void _requireExactKeys(
    Map<String, Object?> object,
    Set<String> expected,
    String field,
  ) {
    final actual = object.keys.toSet();
    final missing = expected.difference(actual).toList()..sort();
    final unknown = actual.difference(expected).toList()..sort();
    if (missing.isNotEmpty) {
      throw K6aDatasetException(
        '$field is missing fields: ${missing.join(', ')}.',
      );
    }
    if (unknown.isNotEmpty) {
      throw K6aDatasetException(
        '$field contains unknown fields: ${unknown.join(', ')}.',
      );
    }
  }

  static String _string(Object? value, String field) {
    if (value is! String) {
      throw K6aDatasetException('$field must be a string.');
    }
    return value;
  }

  static String _identityString(Object? value, String field) {
    final result = _string(value, field);
    if (result.isEmpty || result.trim() != result) {
      throw K6aDatasetException(
        '$field must be non-empty with no surrounding whitespace.',
      );
    }
    return result;
  }

  static String _nonEmptyString(Object? value, String field) {
    final result = _string(value, field);
    if (result.trim().isEmpty) {
      throw K6aDatasetException('$field must not be empty.');
    }
    return result;
  }

  static void _validateRelativePath(String value, String field) {
    if (value.startsWith('/') ||
        value.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      throw K6aDatasetException('$field must be relative.');
    }
    final segments = value.split(RegExp(r'[\\/]'));
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw K6aDatasetException(
        '$field must not contain empty, dot, or parent segments.',
      );
    }
  }

  static void _validateFormatPath(
    String format,
    String relativePath,
    String field,
  ) {
    final lowerPath = relativePath.toLowerCase();
    final valid = switch (format) {
      'png' => lowerPath.endsWith('.png'),
      'jpeg' => lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg'),
      _ => false,
    };
    if (!valid) {
      throw K6aDatasetException('$field does not match the file extension.');
    }
  }

  static String _resolveRelativePath(String root, String relativePath) {
    return [
      Directory(root).absolute.path,
      ...relativePath.split('/'),
    ].join(Platform.pathSeparator);
  }

  static String _normalizedAbsolutePath(String value) {
    final normalized = File(value).absolute.uri.normalizePath().toFilePath();
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }
}
