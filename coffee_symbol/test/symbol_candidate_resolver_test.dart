import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  const resolver = SymbolCandidateResolver();

  test('empty inputs produce an immutable empty result', () {
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: const [],
      definitions: const [],
      bindings: const [],
    );

    expect(result, isEmpty);
    expect(() => result.add(_candidate()), throwsUnsupportedError);
  });

  test('one matched Knowledge result produces one exact Symbol candidate', () {
    final model = definition();
    final link = binding();
    final physicalMatch = match();
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [physicalMatch],
      definitions: [model],
      bindings: [link],
    );

    expect(result, hasLength(1));
    expect(result.single.patternCandidateId, 1);
    expect(result.single.definition, same(model));
    expect(result.single.supports.single.binding, same(link));
    expect(result.single.supports.single.knowledgeMatch, same(physicalMatch));
  });

  test('failed and unavailable Knowledge results produce no candidate', () {
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [
        match(outcome: KnowledgeConstraintOutcome.failed),
        match(candidateId: 2, outcome: KnowledgeConstraintOutcome.unavailable),
      ],
      definitions: [definition()],
      bindings: [binding()],
    );

    expect(result, isEmpty);
  });

  test('returns every candidate in canonical three-part identity order', () {
    final lowerRevision = definition(
      symbolId: 'test-symbol-b',
      revision: 1,
      checksumCharacter: 'c',
    );
    final higherRevision = definition(
      symbolId: 'test-symbol-b',
      revision: 2,
      checksumCharacter: 'd',
    );
    final alphabeticFirst = definition(
      symbolId: 'test-symbol-a',
      checksumCharacter: 'e',
    );
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [
        match(candidateId: 2, recordId: 'test-record-b1'),
        match(candidateId: 1, recordId: 'test-record-b2'),
        match(candidateId: 1, recordId: 'test-record-a'),
        match(candidateId: 1, recordId: 'test-record-b1'),
      ],
      definitions: [higherRevision, lowerRevision, alphabeticFirst],
      bindings: [
        binding(
          bindingId: 'test-binding-b1',
          symbolId: 'test-symbol-b',
          recordId: 'test-record-b1',
        ),
        binding(
          bindingId: 'test-binding-b2',
          symbolId: 'test-symbol-b',
          symbolRevision: 2,
          symbolChecksumCharacter: 'd',
          recordId: 'test-record-b2',
        ),
        binding(
          bindingId: 'test-binding-a',
          symbolId: 'test-symbol-a',
          symbolChecksumCharacter: 'e',
          recordId: 'test-record-a',
        ),
      ],
    );

    expect(
      result
          .map(
            (candidate) => (
              candidate.patternCandidateId,
              candidate.symbolId,
              candidate.symbolRevision,
            ),
          )
          .toList(),
      [
        (1, 'test-symbol-a', 1),
        (1, 'test-symbol-b', 1),
        (1, 'test-symbol-b', 2),
        (2, 'test-symbol-b', 1),
      ],
    );
  });

  test('groups multiple binding hits without losing any support', () {
    final first = binding(bindingId: 'test-binding-001');
    final second = binding(bindingId: 'test-binding-002');
    final physicalMatch = match();
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [physicalMatch],
      definitions: [definition()],
      bindings: [second, first],
    );

    expect(result, hasLength(1));
    expect(result.single.supports, hasLength(2));
    expect(result.single.supports.map((support) => support.binding), [
      first,
      second,
    ]);
    expect(
      result.single.supports.every(
        (support) => identical(support.knowledgeMatch, physicalMatch),
      ),
      isTrue,
    );
  });

  test('groups different matched records for the same Symbol identity', () {
    final firstMatch = match(recordId: 'test-record-001');
    final secondMatch = match(recordId: 'test-record-002');
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [secondMatch, firstMatch],
      definitions: [definition()],
      bindings: [
        binding(),
        binding(bindingId: 'test-binding-002', recordId: 'test-record-002'),
      ],
    );

    expect(result, hasLength(1));
    expect(
      result.single.supports.map((support) => support.knowledgeMatch.recordId),
      ['test-record-001', 'test-record-002'],
    );
  });

  test('input permutations produce equal deterministic results and hashes', () {
    final model = definition();
    final firstBinding = binding(bindingId: 'test-binding-001');
    final secondBinding = binding(
      bindingId: 'test-binding-002',
      recordId: 'test-record-002',
    );
    final firstMatch = match();
    final secondMatch = match(recordId: 'test-record-002');

    final first = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [firstMatch, secondMatch],
      definitions: [model],
      bindings: [firstBinding, secondBinding],
    );
    final second = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [secondMatch, firstMatch],
      definitions: [model],
      bindings: [secondBinding, firstBinding],
    );

    expect(first, second);
    expect(Object.hashAll(first), Object.hashAll(second));
  });

  test('materializes each caller iterable exactly once', () {
    final matches = _CountingIterable([match()]);
    final definitions = _CountingIterable([definition()]);
    final bindings = _CountingIterable([binding()]);

    resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: matches,
      definitions: definitions,
      bindings: bindings,
    );

    expect(matches.iteratorRequests, 1);
    expect(definitions.iteratorRequests, 1);
    expect(bindings.iteratorRequests, 1);
  });

  test('rejects duplicate Knowledge identities before resolution', () {
    expect(
      () => resolver.resolve(
        knowledgeRelease: knowledgeRelease(),
        knowledgeMatches: [match(), match()],
        definitions: const [],
        bindings: const [],
      ),
      throwsArgumentError,
    );
  });

  test('rejects duplicate SymbolDefinition revision identities', () {
    expect(
      () => resolver.resolve(
        knowledgeRelease: knowledgeRelease(),
        knowledgeMatches: const [],
        definitions: [definition(), definition()],
        bindings: const [],
      ),
      throwsArgumentError,
    );
  });

  test('rejects duplicate binding revision identities', () {
    expect(
      () => resolver.resolve(
        knowledgeRelease: knowledgeRelease(),
        knowledgeMatches: const [],
        definitions: const [],
        bindings: [binding(), binding()],
      ),
      throwsArgumentError,
    );
  });

  test('rejects a binding for another Knowledge release', () {
    final otherRelease = KnowledgeDatasetReleaseRef(
      releaseId: 'test-kds-002',
      checksum: checksum('f'),
    );

    expect(
      () => resolver.resolve(
        knowledgeRelease: knowledgeRelease(),
        knowledgeMatches: [match()],
        definitions: [definition()],
        bindings: [binding(release: otherRelease)],
      ),
      throwsStateError,
    );
  });

  test('rejects unknown SymbolDefinition references', () {
    expect(
      () => resolver.resolve(
        knowledgeRelease: knowledgeRelease(),
        knowledgeMatches: [match()],
        definitions: const [],
        bindings: [binding()],
      ),
      throwsStateError,
    );
  });

  test('rejects stale SymbolDefinition checksums', () {
    expect(
      () => resolver.resolve(
        knowledgeRelease: knowledgeRelease(),
        knowledgeMatches: [match()],
        definitions: [definition(checksumCharacter: 'e')],
        bindings: [binding(symbolChecksumCharacter: 'f')],
      ),
      throwsStateError,
    );
  });

  test('does not mutate caller collections or recreate source objects', () {
    final physicalMatch = match();
    final model = definition();
    final link = binding();
    final matches = [physicalMatch];
    final definitions = [model];
    final bindings = [link];

    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: matches,
      definitions: definitions,
      bindings: bindings,
    );

    expect(matches, [physicalMatch]);
    expect(definitions, [model]);
    expect(bindings, [link]);
    expect(result.single.definition, same(model));
    expect(result.single.supports.single.binding, same(link));
    expect(result.single.supports.single.knowledgeMatch, same(physicalMatch));
  });

  test('case-distinct Symbol identities remain distinct', () {
    final upper = definition(symbolId: 'Test-symbol', checksumCharacter: 'e');
    final lower = definition(symbolId: 'test-symbol', checksumCharacter: 'f');
    final result = resolver.resolve(
      knowledgeRelease: knowledgeRelease(),
      knowledgeMatches: [match()],
      definitions: [lower, upper],
      bindings: [
        binding(
          bindingId: 'test-binding-upper',
          symbolId: 'Test-symbol',
          symbolChecksumCharacter: 'e',
        ),
        binding(
          bindingId: 'test-binding-lower',
          symbolId: 'test-symbol',
          symbolChecksumCharacter: 'f',
        ),
      ],
    );

    expect(result.map((candidate) => candidate.symbolId), [
      'Test-symbol',
      'test-symbol',
    ]);
  });
}

SymbolCandidate _candidate() {
  final model = definition();
  return SymbolCandidate(
    patternCandidateId: 1,
    definition: model,
    supports: [
      SymbolCandidateSupport(binding: binding(), knowledgeMatch: match()),
    ],
  );
}

final class _CountingIterable<T> extends Iterable<T> {
  _CountingIterable(this.values);

  final List<T> values;
  int iteratorRequests = 0;

  @override
  Iterator<T> get iterator {
    iteratorRequests++;
    return values.iterator;
  }
}
