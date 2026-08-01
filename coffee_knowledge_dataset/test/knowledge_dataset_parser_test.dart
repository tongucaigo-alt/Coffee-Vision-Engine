import 'dart:convert';
import 'dart:io';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:test/test.dart';

void main() {
  const parser = KnowledgeDatasetParser();

  group('KnowledgeDatasetParser', () {
    test('parses every constraint kind and canonicalizes public output', () {
      final snapshot = parser.parse(
        _dataset([
          _record('record-b', [
            _boolean('topologyIsIsolated', false),
            _integer('topologyNodeCount', 2, 4),
            _double('geometryCentroidX', 0.2, 0.4),
          ]),
          _record('record-a', [_integer('topologyDirectedEdgeCount', 0, 8)]),
        ]),
      );

      expect(snapshot.activeRecords.map((record) => record.id), [
        'record-a',
        'record-b',
      ]);
      expect(snapshot.activeRecords[1].constraints.map((item) => item.key), [
        KnowledgeConstraintKey.geometryCentroidX,
        KnowledgeConstraintKey.topologyNodeCount,
        KnowledgeConstraintKey.topologyIsIsolated,
      ]);
      expect(snapshot.totalRecordCount, 2);
      expect(snapshot.disabledRecordCount, 0);
    });

    test('validates disabled records but omits them from active records', () {
      final snapshot = parser.parse(
        _dataset([
          _record('disabled', [
            _boolean('geometryTouchesWorkingImageBorder', true),
          ], enabled: false),
          _record('active', [_integer('topologyNodeCount', 1, 1)]),
        ]),
      );

      expect(snapshot.activeRecords.single.id, 'active');
      expect(snapshot.totalRecordCount, 2);
      expect(snapshot.disabledRecordCount, 1);

      expect(
        () => parser.parse(
          _dataset([_record('disabled', const [], enabled: false)]),
        ),
        throwsA(isA<KnowledgeDatasetException>()),
      );
    });

    test('uses exact case-sensitive record identities', () {
      final snapshot = parser.parse(
        _dataset([
          _record('record', [_integer('topologyNodeCount', 1, 1)]),
          _record('Record', [_integer('topologyNodeCount', 1, 1)]),
        ]),
      );

      expect(snapshot.activeRecords.map((record) => record.id), [
        'Record',
        'record',
      ]);
      expect(
        () => parser.parse(
          _dataset([
            _record('same', [_integer('topologyNodeCount', 1, 1)]),
            _record('same', [_integer('topologyNodeCount', 2, 2)]),
          ]),
        ),
        throwsA(isA<KnowledgeDatasetException>()),
      );
    });

    test('rejects duplicate constraint keys', () {
      expect(
        () => parser.parse(
          _dataset([
            _record('record-a', [
              _integer('topologyNodeCount', 1, 1),
              _integer('topologyNodeCount', 2, 2),
            ]),
          ]),
        ),
        throwsA(isA<KnowledgeDatasetException>()),
      );
    });

    test('rejects missing and unknown fields at every contract level', () {
      final missingRoot = jsonDecode(_dataset(const [])) as Map<String, Object?>
        ..remove('datasetVersion');
      final unknownRoot = jsonDecode(_dataset(const [])) as Map<String, Object?>
        ..['extra'] = true;
      final missingRecord =
          jsonDecode(
                _dataset([
                  _record('record-a', [_integer('topologyNodeCount', 1, 1)]),
                ]),
              )
              as Map<String, Object?>;
      (missingRecord['records']! as List<Object?>).single
            as Map<String, Object?>
        ..remove('enabled');
      final unknownConstraint = _integer('topologyNodeCount', 1, 1)
        ..['extra'] = true;

      for (final invalid in [
        jsonEncode(missingRoot),
        jsonEncode(unknownRoot),
        jsonEncode(missingRecord),
        _dataset([
          _record('record-a', [unknownConstraint]),
        ]),
      ]) {
        expect(
          () => parser.parse(invalid),
          throwsA(isA<KnowledgeDatasetException>()),
        );
      }
    });

    test('rejects unsupported versions, keys, kinds, and key-kind pairs', () {
      final unsupportedVersion =
          jsonDecode(_dataset(const [])) as Map<String, Object?>
            ..['schemaVersion'] = '2.0';

      for (final invalid in [
        jsonEncode(unsupportedVersion),
        _dataset([
          _record('record-a', [_integer('unknownKey', 1, 1)]),
        ]),
        _dataset([
          _record('record-a', [
            {
              'key': 'topologyNodeCount',
              'kind': 'unknownKind',
              'minimum': 1,
              'maximum': 1,
            },
          ]),
        ]),
        _dataset([
          _record('record-a', [_double('topologyNodeCount', 1.0, 2.0)]),
        ]),
      ]) {
        expect(
          () => parser.parse(invalid),
          throwsA(isA<KnowledgeDatasetException>()),
        );
      }
    });

    test('rejects malformed JSON, invalid numbers, and non-integer bounds', () {
      for (final invalid in [
        '{',
        _dataset([
          _record('record-a', [_double('geometryCentroidX', -0.1, 0.2)]),
        ]),
        _dataset([
          _record('record-a', [_integer('topologyNodeCount', 2, 1)]),
        ]),
        _dataset([
          _record('record-a', [
            {
              'key': 'topologyNodeCount',
              'kind': 'integerRange',
              'minimum': 1.0,
              'maximum': 2,
            },
          ]),
        ]),
      ]) {
        expect(
          () => parser.parse(invalid),
          throwsA(isA<KnowledgeDatasetException>()),
        );
      }
    });

    test('never trims or normalizes dataset and record identities', () {
      final spacedVersion =
          jsonDecode(_dataset(const [])) as Map<String, Object?>
            ..['datasetVersion'] = ' kds-test';

      expect(
        () => parser.parse(jsonEncode(spacedVersion)),
        throwsA(isA<KnowledgeDatasetException>()),
      );
      expect(
        () => parser.parse(
          _dataset([
            _record(' record-a', [_integer('topologyNodeCount', 1, 1)]),
          ]),
        ),
        throwsA(isA<KnowledgeDatasetException>()),
      );
    });

    test('parses the approved kds-001 candidate exactly', () {
      final snapshot = parser.parse(
        File('datasets/kds-001/knowledge_dataset.json').readAsStringSync(),
      );

      expect(snapshot.datasetVersion, 'kds-001');
      expect(snapshot.activeRecords, hasLength(1));
      expect(snapshot.activeRecords.single.id, 'physical-pattern-001');
      expect(
        snapshot.activeRecords.single.constraints.map((item) => item.key),
        [
          KnowledgeConstraintKey.geometryCentroidX,
          KnowledgeConstraintKey.geometryCentroidY,
          KnowledgeConstraintKey.topologyNodeCount,
        ],
      );
    });

    test('returns equal immutable snapshots for repeated parsing', () {
      final source = _dataset([
        _record('record-a', [_integer('topologyNodeCount', 1, 2)]),
      ]);
      final first = parser.parse(source);
      final second = parser.parse(source);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(() => first.activeRecords.clear(), throwsUnsupportedError);
    });
  });
}

String _dataset(List<Map<String, Object?>> records) => jsonEncode({
  'schemaVersion': '1.0',
  'datasetVersion': 'kds-test',
  'records': records,
});

Map<String, Object?> _record(
  String id,
  List<Map<String, Object?>> constraints, {
  bool enabled = true,
}) => {'id': id, 'enabled': enabled, 'constraints': constraints};

Map<String, Object?> _double(String key, double minimum, double maximum) => {
  'key': key,
  'kind': 'doubleRange',
  'minimum': minimum,
  'maximum': maximum,
};

Map<String, Object?> _integer(String key, int minimum, int maximum) => {
  'key': key,
  'kind': 'integerRange',
  'minimum': minimum,
  'maximum': maximum,
};

Map<String, Object?> _boolean(String key, bool expected) => {
  'key': key,
  'kind': 'booleanEquals',
  'expected': expected,
};
