import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  group('exact references', () {
    test('validate identity, revision, checksum, equality, and hashCode', () {
      final first = SymbolRevisionRef(
        symbolId: 'test-symbol-001',
        revision: 2,
        checksum: checksum('a'),
      );
      final second = SymbolRevisionRef(
        symbolId: 'test-symbol-001',
        revision: 2,
        checksum: checksum('a'),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('test-symbol-001'));
      expect(
        () => SymbolRevisionRef(
          symbolId: 'bad id',
          revision: 1,
          checksum: checksum('a'),
        ),
        throwsArgumentError,
      );
      expect(
        () => SymbolRevisionRef(
          symbolId: 'test-symbol-001',
          revision: 0,
          checksum: checksum('a'),
        ),
        throwsArgumentError,
      );
    });

    test('accept only sha256 with 64 lowercase hexadecimal characters', () {
      expect(
        () => KnowledgeDatasetReleaseRef(
          releaseId: 'test-kds-001',
          checksum: 'sha256:${'A' * 64}',
        ),
        throwsArgumentError,
      );
      expect(
        () => CanonicalJsonProfileRef(
          profileId: 'test-profile',
          revision: 1,
          checksum: 'sha256:abcd',
        ),
        throwsArgumentError,
      );
    });

    test('identifiers remain exact and case-sensitive', () {
      final upper = KnowledgeDatasetReleaseRef(
        releaseId: 'Test-Release',
        checksum: checksum('a'),
      );
      final lower = KnowledgeDatasetReleaseRef(
        releaseId: 'test-release',
        checksum: checksum('a'),
      );

      expect(upper, isNot(lower));
      expect(
        () => KnowledgeDatasetReleaseRef(
          releaseId: ' test-release',
          checksum: checksum('a'),
        ),
        throwsArgumentError,
      );
    });

    test('SourceRef stays small and protects locator content in toString', () {
      final ref = SourceRef(
        sourceId: 'test-source-001',
        revision: 3,
        locator: 'private locator',
      );

      expect(ref.locator, 'private locator');
      expect(ref.toString(), isNot(contains('private locator')));
      expect(
        () => SourceRef(
          sourceId: 'test-source-001',
          revision: 3,
          locator: ' bad',
        ),
        throwsArgumentError,
      );
    });
  });

  group('source-backed text and definitions', () {
    test('canonicalizes SourceRefs without replacing exact objects', () {
      final second = sourceRef('test-source-002');
      final first = sourceRef('test-source-001');
      final input = [second, first];
      final text = SourcedLocalizedText(
        language: 'en-US',
        value: 'Neutral text.',
        sourceRefs: input,
      );

      expect(text.sourceRefs.map((entry) => entry.sourceId), [
        'test-source-001',
        'test-source-002',
      ]);
      expect(text.sourceRefs[0], same(first));
      expect(text.sourceRefs[1], same(second));
      expect(() => text.sourceRefs.add(first), throwsUnsupportedError);
      expect(input, [second, first]);
    });

    test(
      'rejects invalid BCP-47, controls, whitespace, and decomposed text',
      () {
        expect(
          () => SourcedLocalizedText(
            language: 'not_a_tag',
            value: 'Text',
            sourceRefs: [sourceRef()],
          ),
          throwsArgumentError,
        );
        for (final value in [' Text', 'Text\u0001', 'Cafe\u0301']) {
          expect(
            () => SourcedLocalizedText(
              language: 'en',
              value: value,
              sourceRefs: [sourceRef()],
            ),
            throwsArgumentError,
            reason: value,
          );
        }
      },
    );

    test('definition canonicalizes text collections and preserves objects', () {
      final english = localized('Test name', language: 'en');
      final turkish = localized('Test adi', language: 'tr');
      final neutral = localized('Neutral.', language: 'en');
      final values = [turkish, english];
      final model = SymbolDefinition(
        symbolRef: SymbolRevisionRef(
          symbolId: 'test-symbol-001',
          revision: 1,
          checksum: checksum('c'),
        ),
        canonicalJsonProfileRef: profileRef(),
        preferredNames: values,
        neutralDefinitions: [neutral],
      );

      expect(model.preferredNames, [english, turkish]);
      expect(model.preferredNames[0], same(english));
      expect(model.neutralDefinitions.single, same(neutral));
      expect(values, [turkish, english]);
      expect(() => model.preferredNames.clear(), throwsUnsupportedError);
      expect(model.toString(), isNot(contains('Neutral.')));
    });

    test(
      'definition requires neutral text and one preferred name per language',
      () {
        expect(
          () => SymbolDefinition(
            symbolRef: definition().symbolRef,
            canonicalJsonProfileRef: profileRef(),
            preferredNames: [localized('One')],
            neutralDefinitions: const [],
          ),
          throwsArgumentError,
        );
        expect(
          () => SymbolDefinition(
            symbolRef: definition().symbolRef,
            canonicalJsonProfileRef: profileRef(),
            preferredNames: [localized('One'), localized('Two')],
            neutralDefinitions: [localized('Neutral.')],
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('binding and candidate contracts', () {
    test('binding canonicalizes exact references and is deeply immutable', () {
      final later = assessmentRef(
        assessmentId: 'test-assessment-002',
        type: EvidenceAssessmentType.holdoutValidation,
      );
      final earlier = assessmentRef(
        assessmentId: 'test-assessment-001',
        type: EvidenceAssessmentType.cohortValidation,
      );
      final assessments = [later, earlier];
      final model = SymbolEvidenceBinding(
        bindingId: 'test-binding-001',
        revision: 1,
        canonicalJsonProfileRef: profileRef(),
        symbolRef: definition().symbolRef,
        knowledgeTargetRef: KnowledgeTargetRef(
          knowledgeRelease: knowledgeRelease(),
          knowledgeRecordId: 'test-record-001',
        ),
        sourceRefs: [sourceRef()],
        evidenceAssessmentRefs: assessments,
      );

      expect(model.evidenceAssessmentRefs, [earlier, later]);
      expect(model.evidenceAssessmentRefs.first, same(earlier));
      expect(assessments, [later, earlier]);
      expect(
        () => model.evidenceAssessmentRefs.clear(),
        throwsUnsupportedError,
      );
    });

    test('binding requires unique non-empty assessment references', () {
      final assessment = assessmentRef();
      expect(
        () => SymbolEvidenceBinding(
          bindingId: 'test-binding-001',
          revision: 1,
          canonicalJsonProfileRef: profileRef(),
          symbolRef: definition().symbolRef,
          knowledgeTargetRef: KnowledgeTargetRef(
            knowledgeRelease: knowledgeRelease(),
            knowledgeRecordId: 'test-record-001',
          ),
          evidenceAssessmentRefs: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => SymbolEvidenceBinding(
          bindingId: 'test-binding-001',
          revision: 1,
          canonicalJsonProfileRef: profileRef(),
          symbolRef: definition().symbolRef,
          knowledgeTargetRef: KnowledgeTargetRef(
            knowledgeRelease: knowledgeRelease(),
            knowledgeRecordId: 'test-record-001',
          ),
          evidenceAssessmentRefs: [assessment, assessment],
        ),
        throwsArgumentError,
      );
    });

    test('support accepts only matched result for its exact record', () {
      final model = binding();
      expect(
        () => SymbolCandidateSupport(
          binding: model,
          knowledgeMatch: match(outcome: KnowledgeConstraintOutcome.failed),
        ),
        throwsArgumentError,
      );
      expect(
        () => SymbolCandidateSupport(
          binding: model,
          knowledgeMatch: match(recordId: 'test-record-002'),
        ),
        throwsArgumentError,
      );
    });

    test(
      'candidate preserves exact objects with canonical immutable support',
      () {
        final model = definition();
        final secondBinding = binding(
          bindingId: 'test-binding-002',
          recordId: 'test-record-002',
        );
        final firstBinding = binding();
        final second = SymbolCandidateSupport(
          binding: secondBinding,
          knowledgeMatch: match(recordId: 'test-record-002'),
        );
        final first = SymbolCandidateSupport(
          binding: firstBinding,
          knowledgeMatch: match(),
        );
        final candidate = SymbolCandidate(
          patternCandidateId: 1,
          definition: model,
          supports: [second, first],
        );
        final equal = SymbolCandidate(
          patternCandidateId: 1,
          definition: model,
          supports: [first, second],
        );

        expect(candidate.definition, same(model));
        expect(candidate.supports, [first, second]);
        expect(candidate.supports.first, same(first));
        expect(candidate, equal);
        expect(candidate.hashCode, equal.hashCode);
        expect(() => candidate.supports.clear(), throwsUnsupportedError);
        expect(candidate.toString(), isNot(contains('Neutral')));
      },
    );
  });
}
