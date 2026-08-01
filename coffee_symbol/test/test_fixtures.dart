import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_symbol/coffee_symbol.dart';

String checksum(String character) => 'sha256:${character * 64}';

CanonicalJsonProfileRef profileRef() => CanonicalJsonProfileRef(
  profileId: 'test-canonical-json',
  revision: 1,
  checksum: checksum('a'),
);

KnowledgeDatasetReleaseRef knowledgeRelease() => KnowledgeDatasetReleaseRef(
  releaseId: 'test-kds-001',
  checksum: checksum('b'),
);

SourceRef sourceRef([String id = 'test-source-001']) =>
    SourceRef(sourceId: id, revision: 1, locator: 'p. 1');

SourcedLocalizedText localized(
  String value, {
  String language = 'en',
  String sourceId = 'test-source-001',
}) => SourcedLocalizedText(
  language: language,
  value: value,
  sourceRefs: [sourceRef(sourceId)],
);

SymbolDefinition definition({
  String symbolId = 'test-symbol-001',
  int revision = 1,
  String checksumCharacter = 'c',
}) => SymbolDefinition(
  symbolRef: SymbolRevisionRef(
    symbolId: symbolId,
    revision: revision,
    checksum: checksum(checksumCharacter),
  ),
  canonicalJsonProfileRef: profileRef(),
  preferredNames: [localized('Test symbol')],
  neutralDefinitions: [localized('A neutral test definition.')],
);

EvidenceAssessmentRef assessmentRef({
  String assessmentId = 'test-assessment-001',
  EvidenceAssessmentType type = EvidenceAssessmentType.holdoutValidation,
}) => EvidenceAssessmentRef(
  assessmentId: assessmentId,
  revision: 1,
  assessmentType: type,
  checksum: checksum('d'),
);

SymbolEvidenceBinding binding({
  String bindingId = 'test-binding-001',
  int revision = 1,
  String symbolId = 'test-symbol-001',
  int symbolRevision = 1,
  String symbolChecksumCharacter = 'c',
  String recordId = 'test-record-001',
  KnowledgeDatasetReleaseRef? release,
}) => SymbolEvidenceBinding(
  bindingId: bindingId,
  revision: revision,
  canonicalJsonProfileRef: profileRef(),
  symbolRef: SymbolRevisionRef(
    symbolId: symbolId,
    revision: symbolRevision,
    checksum: checksum(symbolChecksumCharacter),
  ),
  knowledgeTargetRef: KnowledgeTargetRef(
    knowledgeRelease: release ?? knowledgeRelease(),
    knowledgeRecordId: recordId,
  ),
  evidenceAssessmentRefs: [assessmentRef()],
);

KnowledgeMatchResult match({
  int candidateId = 1,
  String recordId = 'test-record-001',
  KnowledgeConstraintOutcome outcome = KnowledgeConstraintOutcome.passed,
}) {
  final constraint = KnowledgeConstraint.doubleRange(
    key: KnowledgeConstraintKey.geometryWidth,
    minimum: 0.1,
    maximum: 0.5,
  );
  final result = outcome == KnowledgeConstraintOutcome.unavailable
      ? ConstraintMatchResult.unavailable(
          constraint: constraint,
          reason: KnowledgeConstraintUnavailableReason.geometryUnavailable,
        )
      : ConstraintMatchResult.doubleObserved(
          constraint: constraint,
          observedValue: 0.25,
          outcome: outcome,
        );
  return KnowledgeMatchResult(
    candidateId: candidateId,
    recordId: recordId,
    constraintResults: [result],
  );
}
