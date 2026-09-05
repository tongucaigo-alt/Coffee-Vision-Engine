import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';

import '../capture/atlas_three_angle_capture_models.dart';
import '../integration/atlas_k6_result.dart';
import '../integration/atlas_k6_surface_processor.dart';

enum AtlasThreeAngleDiagnosticScenario { mixedOutcomes, technicalRetry }

final class AtlasThreeAngleDiagnosticFixture {
  AtlasThreeAngleDiagnosticFixture(this.scenario);

  final AtlasThreeAngleDiagnosticScenario scenario;
  var _rightAttempts = 0;

  String get label => switch (scenario) {
    AtlasThreeAngleDiagnosticScenario.mixedOutcomes =>
      'MIXED OUTCOMES · SENTETİK SONUÇLAR',
    AtlasThreeAngleDiagnosticScenario.technicalRetry =>
      'TECHNICAL ERROR + RETRY · SENTETİK SONUÇLAR',
  };

  Future<AtlasK6SurfaceResult> process({
    required AtlasCupCaptureRole role,
    required String path,
  }) async {
    if (scenario == AtlasThreeAngleDiagnosticScenario.technicalRetry &&
        role == AtlasCupCaptureRole.handleRight &&
        _rightAttempts++ == 0) {
      throw AtlasSurfaceProcessingException(
        stage: AtlasSurfaceProcessingStage.pattern,
        cause: StateError('test-only injected failure'),
      );
    }
    return switch ((scenario, role)) {
      (
        AtlasThreeAngleDiagnosticScenario.mixedOutcomes,
        AtlasCupCaptureRole.top,
      ) =>
        _noMatch(),
      (
        AtlasThreeAngleDiagnosticScenario.mixedOutcomes,
        AtlasCupCaptureRole.handleRight,
      ) =>
        _insufficient(),
      (
        AtlasThreeAngleDiagnosticScenario.mixedOutcomes,
        AtlasCupCaptureRole.handleLeft,
      ) =>
        _withSymbol(),
      (
        AtlasThreeAngleDiagnosticScenario.technicalRetry,
        AtlasCupCaptureRole.handleRight,
      ) =>
        _withSymbol(),
      _ => _noMatch(),
    };
  }

  static AtlasK6SurfaceResult _noMatch() {
    final features = _features();
    return AtlasK6SurfaceResult(
      featureSet: features,
      patternResult: PatternAnalysisResult(
        surfaceType: PatternSurfaceType.cup,
        candidates: const [],
      ),
      candidateResults: const [],
      symbolCandidates: const [],
      processingDuration: Duration.zero,
    );
  }

  static AtlasK6SurfaceResult _insufficient() {
    final features = _features();
    final candidate = PatternCandidate.withGeometryAndTopology(
      id: 1,
      evidence: [PatternEvidence.connectedStructure(1)],
      geometry: PatternGeometry(
        left: 0.1,
        top: 0.1,
        right: 0.9,
        bottom: 0.9,
        centroidX: 0.5,
        centroidY: 0.5,
      ),
      topology: PatternTopology(nodeCount: 1, directedEdgeCount: 0),
    );
    final pattern = PatternAnalysisResult(
      surfaceType: PatternSurfaceType.cup,
      candidates: [candidate],
    );
    final matches = const KnowledgeRecordCollectionMatcher().match(
      candidate: candidate,
      records: [
        KnowledgeRecord(
          id: 'test-diagnostic-physical-pattern-001',
          constraints: [
            KnowledgeConstraint.doubleRange(
              key: KnowledgeConstraintKey.geometryCentroidX,
              minimum: 0.49,
              maximum: 0.51,
            ),
          ],
        ),
      ],
    );
    return AtlasK6SurfaceResult(
      featureSet: features,
      patternResult: pattern,
      candidateResults: [
        AtlasK6CandidateResult(candidate: candidate, matches: matches),
      ],
      symbolCandidates: const [],
      processingDuration: Duration.zero,
    );
  }

  static AtlasK6SurfaceResult _withSymbol() {
    final base = _insufficient();
    final knowledgeMatch = base.candidateResults.single.matches.single;
    final profile = CanonicalJsonProfileRef(
      profileId: 'atlas-canonical-json',
      revision: 1,
      checksum:
          'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7',
    );
    final symbolRef = SymbolRevisionRef(
      symbolId: 'test-diagnostic-symbol-001',
      revision: 1,
      checksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000001',
    );
    final definition = SymbolDefinition(
      symbolRef: symbolRef,
      canonicalJsonProfileRef: profile,
      preferredNames: [
        SourcedLocalizedText(
          language: 'en',
          value: 'Test Diagnostic Symbol',
          sourceRefs: [
            SourceRef(sourceId: 'test-diagnostic-source-001', revision: 1),
          ],
        ),
      ],
      neutralDefinitions: [
        SourcedLocalizedText(
          language: 'en',
          value: 'Synthetic diagnostic-only symbol definition.',
          sourceRefs: [
            SourceRef(sourceId: 'test-diagnostic-source-001', revision: 1),
          ],
        ),
      ],
    );
    final binding = SymbolEvidenceBinding(
      bindingId: 'test-diagnostic-binding-001',
      revision: 1,
      canonicalJsonProfileRef: profile,
      symbolRef: symbolRef,
      knowledgeTargetRef: KnowledgeTargetRef(
        knowledgeRelease: KnowledgeDatasetReleaseRef(
          releaseId: 'test-diagnostic-kds-001',
          checksum:
              'sha256:0000000000000000000000000000000000000000000000000000000000000002',
        ),
        knowledgeRecordId: 'test-diagnostic-physical-pattern-001',
      ),
      evidenceAssessmentRefs: [
        EvidenceAssessmentRef(
          assessmentId: 'test-diagnostic-assessment-001',
          revision: 1,
          assessmentType: EvidenceAssessmentType.holdoutValidation,
          checksum:
              'sha256:0000000000000000000000000000000000000000000000000000000000000003',
        ),
      ],
    );
    final symbol = SymbolCandidate(
      patternCandidateId: 1,
      definition: definition,
      supports: [
        SymbolCandidateSupport(
          binding: binding,
          knowledgeMatch: knowledgeMatch,
        ),
      ],
    );
    return AtlasK6SurfaceResult(
      featureSet: base.featureSet,
      patternResult: base.patternResult,
      candidateResults: base.candidateResults,
      symbolCandidates: [symbol],
      processingDuration: Duration.zero,
    );
  }

  static VisionFeatureSet _features() => VisionFeatureSet(
    surfaceType: VisionSurfaceType.cup,
    imageProvenance: VisionFeatureImageProvenance(
      sourceFormat: VisionImageFormat.jpeg,
      sourceWidth: 100,
      sourceHeight: 100,
      workingFormat: VisionImageFormat.png,
      workingWidth: 512,
      workingHeight: 512,
      workingResolution: 512,
      contentRect: VisionRect(left: 0, top: 0, right: 1, bottom: 1),
    ),
  );
}
