import 'dart:convert';

import 'package:coffee_knowledge/coffee_knowledge.dart';

import 'knowledge_dataset_exception.dart';
import 'knowledge_dataset_snapshot.dart';

/// Strict parser for Atlas physical Knowledge dataset JSON text.
///
/// This parser performs no file I/O and never normalizes identities.
final class KnowledgeDatasetParser {
  const KnowledgeDatasetParser();

  KnowledgeDatasetSnapshot parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const KnowledgeDatasetException('Dataset JSON is invalid.');
    }

    final root = _object(decoded, 'dataset');
    _requireExactKeys(root, const {
      'schemaVersion',
      'datasetVersion',
      'records',
    }, 'dataset');
    final schemaVersion = _string(root['schemaVersion'], 'schemaVersion');
    if (schemaVersion != '1.0') {
      throw const KnowledgeDatasetException('schemaVersion must equal "1.0".');
    }
    final datasetVersion = _identity(root['datasetVersion'], 'datasetVersion');
    final rawRecords = root['records'];
    if (rawRecords is! List<Object?>) {
      throw const KnowledgeDatasetException('records must be a JSON array.');
    }

    final recordIds = <String>{};
    final activeRecords = <KnowledgeRecord>[];
    for (var index = 0; index < rawRecords.length; index++) {
      final field = 'records[$index]';
      final recordObject = _object(rawRecords[index], field);
      _requireExactKeys(recordObject, const {
        'id',
        'enabled',
        'constraints',
      }, field);
      final id = _identity(recordObject['id'], '$field.id');
      if (!recordIds.add(id)) {
        throw KnowledgeDatasetException(
          '$field.id duplicates an existing record ID.',
        );
      }
      final enabled = recordObject['enabled'];
      if (enabled is! bool) {
        throw KnowledgeDatasetException('$field.enabled must be a boolean.');
      }
      final rawConstraints = recordObject['constraints'];
      if (rawConstraints is! List<Object?>) {
        throw KnowledgeDatasetException(
          '$field.constraints must be a JSON array.',
        );
      }
      final constraints = <KnowledgeConstraint>[];
      for (
        var constraintIndex = 0;
        constraintIndex < rawConstraints.length;
        constraintIndex++
      ) {
        constraints.add(
          _parseConstraint(
            rawConstraints[constraintIndex],
            '$field.constraints[$constraintIndex]',
          ),
        );
      }

      final KnowledgeRecord record;
      try {
        record = KnowledgeRecord(id: id, constraints: constraints);
      } on ArgumentError {
        throw KnowledgeDatasetException('$field is invalid.');
      }
      if (enabled) activeRecords.add(record);
    }

    return KnowledgeDatasetSnapshot(
      schemaVersion: schemaVersion,
      datasetVersion: datasetVersion,
      activeRecords: activeRecords,
      totalRecordCount: rawRecords.length,
    );
  }

  static KnowledgeConstraint _parseConstraint(Object? value, String field) {
    final object = _object(value, field);
    final kindSource = _string(object['kind'], '$field.kind');
    final key = _constraintKey(object['key'], '$field.key');

    try {
      return switch (kindSource) {
        'doubleRange' => _doubleRange(object, key, field),
        'integerRange' => _integerRange(object, key, field),
        'booleanEquals' => _booleanEquals(object, key, field),
        _ => throw KnowledgeDatasetException('$field.kind is not supported.'),
      };
    } on ArgumentError {
      throw KnowledgeDatasetException('$field is invalid.');
    }
  }

  static KnowledgeConstraint _doubleRange(
    Map<String, Object?> object,
    KnowledgeConstraintKey key,
    String field,
  ) {
    _requireExactKeys(object, const {
      'key',
      'kind',
      'minimum',
      'maximum',
    }, field);
    return KnowledgeConstraint.doubleRange(
      key: key,
      minimum: _double(object['minimum'], '$field.minimum'),
      maximum: _double(object['maximum'], '$field.maximum'),
    );
  }

  static KnowledgeConstraint _integerRange(
    Map<String, Object?> object,
    KnowledgeConstraintKey key,
    String field,
  ) {
    _requireExactKeys(object, const {
      'key',
      'kind',
      'minimum',
      'maximum',
    }, field);
    return KnowledgeConstraint.integerRange(
      key: key,
      minimum: _integer(object['minimum'], '$field.minimum'),
      maximum: _integer(object['maximum'], '$field.maximum'),
    );
  }

  static KnowledgeConstraint _booleanEquals(
    Map<String, Object?> object,
    KnowledgeConstraintKey key,
    String field,
  ) {
    _requireExactKeys(object, const {'key', 'kind', 'expected'}, field);
    final expected = object['expected'];
    if (expected is! bool) {
      throw KnowledgeDatasetException('$field.expected must be a boolean.');
    }
    return KnowledgeConstraint.booleanEquals(key: key, expected: expected);
  }

  static KnowledgeConstraintKey _constraintKey(Object? value, String field) {
    final source = _string(value, field);
    for (final key in KnowledgeConstraintKey.values) {
      if (key.name == source) return key;
    }
    throw KnowledgeDatasetException('$field is not supported.');
  }

  static Map<String, Object?> _object(Object? value, String field) {
    if (value is! Map<Object?, Object?>) {
      throw KnowledgeDatasetException('$field must be a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw KnowledgeDatasetException('$field keys must be strings.');
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
      throw KnowledgeDatasetException(
        '$field is missing fields: ${missing.join(', ')}.',
      );
    }
    if (unknown.isNotEmpty) {
      throw KnowledgeDatasetException(
        '$field contains unknown fields: ${unknown.join(', ')}.',
      );
    }
  }

  static String _string(Object? value, String field) {
    if (value is! String) {
      throw KnowledgeDatasetException('$field must be a string.');
    }
    return value;
  }

  static String _identity(Object? value, String field) {
    final result = _string(value, field);
    if (result.isEmpty || result.trim() != result) {
      throw KnowledgeDatasetException(
        '$field must be non-empty with no surrounding whitespace.',
      );
    }
    return result;
  }

  static double _double(Object? value, String field) {
    if (value is! num) {
      throw KnowledgeDatasetException('$field must be a number.');
    }
    final result = value.toDouble();
    if (!result.isFinite) {
      throw KnowledgeDatasetException('$field must be finite.');
    }
    return result;
  }

  static int _integer(Object? value, String field) {
    if (value is! int) {
      throw KnowledgeDatasetException('$field must be an integer.');
    }
    return value;
  }
}
