import 'package:coffee_source/coffee_source.dart';
import 'package:test/test.dart';

const _checksum =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('SourceUseAssessment', () {
    test('preserves exact target and source with canonical limitations', () {
      final limitations = ['Second limitation', 'First limitation'];
      final assessment = _assessment(limitations: limitations);

      expect(assessment.useAssessmentId, 'test-use-001');
      expect(assessment.targetRef.targetPath, '/preferredNames/0');
      expect(assessment.sourceRef.locator, 'p. 16');
      expect(assessment.limitations, ['First limitation', 'Second limitation']);
      expect(limitations, ['Second limitation', 'First limitation']);
      expect(() => assessment.limitations.clear(), throwsUnsupportedError);
    });

    test('rejects invalid schema, revision, pointer, and duplicates', () {
      expect(() => _assessment(schemaVersion: '2.0'), throwsArgumentError);
      expect(() => _assessment(revision: 0), throwsArgumentError);
      expect(
        () => DomainTargetRef(
          recordType: 'atlas.symbolDefinition',
          recordId: 'symbol-tree',
          revision: 1,
          checksum: _checksum,
          targetPath: 'preferredNames/0',
        ),
        throwsArgumentError,
      );
      expect(
        () => _assessment(limitations: const ['Same', 'Same']),
        throwsArgumentError,
      );
    });

    test('has value equality and content-safe toString', () {
      final first = _assessment();
      final second = _assessment();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), isNot(contains('p. 16')));
      expect(first.toString(), isNot(contains('Reviewable rationale')));
    });

    test('exposes exact frozen vocabularies', () {
      expect(SourceEvidenceRole.values.map((value) => value.name), [
        'primary',
        'secondary',
        'tertiary',
        'discovery',
      ]);
      expect(SourceSupportRelation.values.map((value) => value.name), [
        'supports',
        'contradicts',
        'contextualizes',
        'mentionsOnly',
      ]);
      expect(SourceAssessmentOutcome.values.map((value) => value.name), [
        'eligibleCore',
        'eligibleCorroborative',
        'discoveryOnly',
        'ineligible',
      ]);
      expect(EditorialControlQuality.values, hasLength(7));
      expect(MethodTransparencyQuality.values, hasLength(4));
      expect(SourceStabilityQuality.values, hasLength(4));
    });
  });
}

SourceUseAssessment _assessment({
  String schemaVersion = '1.0',
  int revision = 1,
  Iterable<String> limitations = const [],
}) {
  return SourceUseAssessment(
    schemaVersion: schemaVersion,
    useAssessmentId: 'test-use-001',
    revision: revision,
    canonicalJsonProfileRef: CanonicalJsonProfileRef(
      profileId: 'atlas-canonical-json',
      revision: 1,
      checksum: _checksum,
    ),
    targetRef: DomainTargetRef(
      recordType: 'atlas.symbolDefinition',
      recordId: 'symbol-tree',
      revision: 1,
      checksum: _checksum,
      targetPath: '/preferredNames/0',
    ),
    sourceRef: SourceRef(
      sourceId: 'test-source-001',
      revision: 1,
      locator: 'p. 16',
    ),
    evidenceRole: SourceEvidenceRole.primary,
    supportRelation: SourceSupportRelation.supports,
    independenceGroupId: 'test-family-001',
    independenceRationale: 'Independent synthetic source family.',
    qualityDimensions: const QualityDimensions(
      provenance: ProvenanceQuality.verified,
      attribution: AttributionQuality.identified,
      editorialControl: EditorialControlQuality.professionalEditorial,
      methodTransparency: MethodTransparencyQuality.partial,
      sourceStability: SourceStabilityQuality.fixedEdition,
      culturalProximity: CulturalProximityQuality.recognizedSpecialist,
    ),
    assessmentOutcome: SourceAssessmentOutcome.eligibleCore,
    limitations: limitations,
    rationale: 'Reviewable rationale for a synthetic assessment.',
  );
}
