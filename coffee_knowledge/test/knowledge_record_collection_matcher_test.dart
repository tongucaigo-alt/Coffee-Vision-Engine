import 'dart:io';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeRecordCollectionMatcher', () {
    const matcher = KnowledgeRecordCollectionMatcher();

    test('empty collection returns immutable empty output', () {
      final results = matcher.match(
        candidate: _completeCandidate(),
        records: const [],
      );

      expect(results, isEmpty);
      expect(() => results.add(_manualMatchResult()), throwsUnsupportedError);
    });

    test('one record produces one result', () {
      final record = KnowledgeRecord(
        id: 'wide-middle',
        constraints: [_widthConstraint()],
      );

      final results = matcher.match(
        candidate: _completeCandidate(),
        records: [record],
      );

      expect(results, hasLength(1));
      expect(results.single.candidateId, 11);
      expect(results.single.recordId, 'wide-middle');
      expect(results.single.matched, isTrue);
    });

    test('multiple records produce one result per record', () {
      final records = [
        _record('beta', _heightConstraint()),
        _record('alpha', _widthConstraint()),
        _record('gamma', _nodeCountConstraint()),
      ];

      final results = matcher.match(
        candidate: _completeCandidate(),
        records: records,
      );

      expect(results, hasLength(records.length));
      expect(results.map((result) => result.recordId), [
        'alpha',
        'beta',
        'gamma',
      ]);
    });

    test('passed, failed and unavailable outcomes are retained', () {
      final results = matcher.match(
        candidate: PatternCandidate.withGeometry(
          id: 3,
          evidence: [PatternEvidence.componentFeature(1)],
          geometry: _geometry(),
        ),
        records: [
          _record('failed', _tooNarrowConstraint()),
          _record('passed', _widthConstraint()),
          _record('unavailable', _nodeCountConstraint()),
        ],
      );

      expect(results.map((result) => result.recordId), [
        'failed',
        'passed',
        'unavailable',
      ]);
      expect(
        results[0].constraintResults.single.outcome,
        KnowledgeConstraintOutcome.failed,
      );
      expect(
        results[1].constraintResults.single.outcome,
        KnowledgeConstraintOutcome.passed,
      );
      expect(
        results[2].constraintResults.single.outcome,
        KnowledgeConstraintOutcome.unavailable,
      );
    });

    test('reverse input produces canonical ID order', () {
      final results = matcher.match(
        candidate: _completeCandidate(),
        records: [
          _record('third', _heightConstraint()),
          _record('second', _nodeCountConstraint()),
          _record('first', _widthConstraint()),
        ],
      );

      expect(results.map((result) => result.recordId), [
        'first',
        'second',
        'third',
      ]);
    });

    test('different input orders produce element-wise equal output', () {
      final records = [
        _record('alpha', _widthConstraint()),
        _record('beta', _heightConstraint()),
        _record('gamma', _nodeCountConstraint()),
      ];
      final forward = matcher.match(
        candidate: _completeCandidate(),
        records: records,
      );
      final shuffled = matcher.match(
        candidate: _completeCandidate(),
        records: [records[2], records[0], records[1]],
      );

      expect(shuffled, forward);
    });

    test('already canonical input remains canonical', () {
      final results = matcher.match(
        candidate: _completeCandidate(),
        records: [
          _record('alpha', _widthConstraint()),
          _record('beta', _heightConstraint()),
          _record('gamma', _nodeCountConstraint()),
        ],
      );

      expect(results.map((result) => result.recordId), [
        'alpha',
        'beta',
        'gamma',
      ]);
    });

    test('repeating the same record instance is rejected', () {
      final record = _record('same', _widthConstraint());

      expect(
        () => matcher.match(
          candidate: _completeCandidate(),
          records: [record, record],
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.invalidValue, 'invalidValue', 'same')
              .having((error) => error.name, 'name', 'records')
              .having(
                (error) => error.message,
                'message',
                'must contain unique KnowledgeRecord IDs',
              ),
        ),
      );
    });

    test('non-adjacent duplicate IDs are rejected', () {
      final first = _record('same', _widthConstraint());
      final middle = _record('middle', _nodeCountConstraint());
      final last = _record('same', _heightConstraint());

      expect(
        () => matcher.match(
          candidate: _completeCandidate(),
          records: [first, middle, last],
        ),
        throwsArgumentError,
      );
    });

    test('duplicate validation occurs before sorting or evaluation', () {
      final source = File(
        'lib/src/knowledge_record_collection_matcher.dart',
      ).readAsStringSync();
      final duplicateCheck = source.indexOf('!seenIds.add(duplicateId)');
      final sort = source.indexOf('canonicalRecords.sort');
      final evaluate = source.indexOf('evaluator.evaluate(');

      expect(duplicateCheck, isNonNegative);
      expect(sort, isNonNegative);
      expect(evaluate, isNonNegative);
      expect(duplicateCheck, lessThan(sort));
      expect(sort, lessThan(evaluate));
    });

    test('IDs are case-sensitive and ordering uses String.compareTo', () {
      final results = matcher.match(
        candidate: _completeCandidate(),
        records: [
          _record('a', _heightConstraint()),
          _record('A', _widthConstraint()),
        ],
      );

      expect(results.map((result) => result.recordId), ['A', 'a']);
    });

    test('a lazy iterable is enumerated exactly once', () {
      var yielded = 0;
      final records =
          [
            _record('width', _widthConstraint()),
            _record('height', _heightConstraint()),
          ].map((record) {
            yielded++;
            return record;
          });

      final results = matcher.match(
        candidate: _completeCandidate(),
        records: records,
      );

      expect(yielded, 2);
      expect(results.map((result) => result.recordId), ['height', 'width']);
    });

    test('a matched result does not stop traversal', () {
      final results = matcher.match(
        candidate: _completeCandidate(),
        records: [
          _record('alpha', _widthConstraint()),
          _record('beta', _heightConstraint()),
        ],
      );

      expect(results, hasLength(2));
      expect(results.every((result) => result.matched), isTrue);
    });

    test('failed and unavailable results do not stop traversal', () {
      final results = matcher.match(
        candidate: PatternCandidate.withGeometry(
          id: 3,
          evidence: [PatternEvidence.componentFeature(1)],
          geometry: _geometry(),
        ),
        records: [
          _record('after', _widthConstraint()),
          _record('failed', _tooNarrowConstraint()),
          _record('unavailable', _nodeCountConstraint()),
        ],
      );

      expect(results.map((result) => result.recordId), [
        'after',
        'failed',
        'unavailable',
      ]);
      expect(results[0].matched, isTrue);
      expect(
        results[1].constraintResults.single.outcome,
        KnowledgeConstraintOutcome.failed,
      );
      expect(
        results[2].constraintResults.single.outcome,
        KnowledgeConstraintOutcome.unavailable,
      );
    });

    test('candidate, record and constraint identities are preserved', () {
      final width = _widthConstraint();
      final nodeCount = _nodeCountConstraint();
      final record = KnowledgeRecord(
        id: 'identity',
        constraints: [width, nodeCount],
      );

      final result = matcher
          .match(candidate: _completeCandidate(id: 42), records: [record])
          .single;

      expect(result.candidateId, 42);
      expect(result.recordId, same(record.id));
      expect(result.constraintResults[0].constraint, same(width));
      expect(result.constraintResults[1].constraint, same(nodeCount));
    });

    test('output is immutable and inputs remain unchanged', () {
      final candidate = _completeCandidate();
      final geometry = candidate.geometry;
      final topology = candidate.topology;
      final records = [
        _record('width', _widthConstraint()),
        _record('height', _heightConstraint()),
      ];
      final beforeRecords = List<KnowledgeRecord>.of(records);
      final beforeEvidence = List<PatternEvidence>.of(candidate.evidence);

      final results = matcher.match(candidate: candidate, records: records);

      expect(() => results.clear(), throwsUnsupportedError);
      expect(records, beforeRecords);
      expect(candidate.evidence, beforeEvidence);
      expect(candidate.geometry, same(geometry));
      expect(candidate.topology, same(topology));
    });

    test('repeated calls are deterministic', () {
      final records = [
        _record('width', _widthConstraint()),
        _record('height', _heightConstraint()),
      ];

      final first = matcher.match(
        candidate: _completeCandidate(),
        records: records,
      );
      final second = matcher.match(
        candidate: _completeCandidate(),
        records: records.reversed,
      );

      expect(second, first);
      expect(second.map((result) => result.hashCode), [
        for (final result in first) result.hashCode,
      ]);
    });

    test('iterable failure propagates and no partial output escapes', () {
      final records = <KnowledgeRecord>[
        _record('valid', _widthConstraint()),
      ].followedBy(_throwingRecords());

      expect(
        () => matcher.match(candidate: _completeCandidate(), records: records),
        throwsStateError,
      );
    });

    test('source/API boundary verifies exact K3/K4 reuse', () {
      final barrel = File('lib/coffee_knowledge.dart').readAsStringSync();
      final source = File(
        'lib/src/knowledge_record_collection_matcher.dart',
      ).readAsStringSync();
      final executable = source
          .replaceAll(RegExp(r'//[^\r\n]*'), '')
          .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");

      expect(barrel, contains('KnowledgeRecordCollectionMatcher'));
      expect(
        RegExp(r'List<KnowledgeMatchResult> match\(').allMatches(executable),
        hasLength(1),
      );
      expect(executable, contains('records.toList(growable: false)'));
      expect(executable, contains('first.id.compareTo(second.id)'));
      expect(
        executable,
        contains('const evaluator = KnowledgeRecordEvaluator()'),
      );
      expect(
        executable,
        contains('const decider = KnowledgeRecordMatchDecider()'),
      );
      expect(
        RegExp(r'evaluator\.evaluate\(').allMatches(executable),
        hasLength(1),
      );
      expect(RegExp(r'decider\.decide\(').allMatches(executable), hasLength(1));
      expect(executable, isNot(contains('ConstraintEvaluator')));
      for (final forbidden in [
        'KnowledgeEngine',
        'KnowledgeDataset',
        'KnowledgeMatchRequest',
        'KnowledgeValidationResult',
        'KnowledgeValidationIssue',
        'CoffeeVisionEngine',
        'VisionKnowledge',
        'Graph',
        'score',
        'confidence',
        'rank',
        'weight',
        'interpretation',
        'json',
        'File(',
        'Future<',
        'Stream<',
        'try {',
        'catch (',
      ]) {
        expect(executable, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

KnowledgeRecord _record(String id, KnowledgeConstraint constraint) {
  return KnowledgeRecord(id: id, constraints: [constraint]);
}

KnowledgeConstraint _widthConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.5,
    maximum: 0.7,
  );
}

KnowledgeConstraint _heightConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryHeight,
    minimum: 0.5,
    maximum: 0.7,
  );
}

KnowledgeConstraint _tooNarrowConstraint() {
  return KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.1,
    maximum: 0.2,
  );
}

KnowledgeConstraint _nodeCountConstraint() {
  return KnowledgeConstraint.integerRange(
    key: KnowledgeConstraintKey.topologyNodeCount,
    minimum: 3,
    maximum: 3,
  );
}

PatternCandidate _completeCandidate({int id = 11}) {
  return PatternCandidate.withGeometryAndTopology(
    id: id,
    evidence: [PatternEvidence.componentFeature(1)],
    geometry: _geometry(),
    topology: PatternTopology(nodeCount: 3, directedEdgeCount: 4),
  );
}

PatternGeometry _geometry() {
  return PatternGeometry(
    left: 0.1,
    top: 0.2,
    right: 0.7,
    bottom: 0.8,
    centroidX: 0.4,
    centroidY: 0.5,
  );
}

KnowledgeMatchResult _manualMatchResult() {
  final constraint = _widthConstraint();
  return KnowledgeMatchResult(
    candidateId: 1,
    recordId: 'manual',
    constraintResults: [
      ConstraintMatchResult.doubleObserved(
        constraint: constraint,
        observedValue: 0.6,
        outcome: KnowledgeConstraintOutcome.passed,
      ),
    ],
  );
}

Iterable<KnowledgeRecord> _throwingRecords() sync* {
  throw StateError('record iteration failed');
}
