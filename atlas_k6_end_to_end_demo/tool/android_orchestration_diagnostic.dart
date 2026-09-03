import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_controller.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_result.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/material.dart';

const _scenarioValue = String.fromEnvironment(
  'ATLAS_M4_SCENARIO',
  defaultValue: 'disabled',
);
const _profileChecksum =
    'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scenario = _DiagnosticScenario.parse(_scenarioValue);
  if (scenario == null) {
    runApp(const _DiagnosticDisabledApp());
    return;
  }

  final evidence = await _runDiagnostic(scenario);
  final encoded = jsonEncode(evidence);
  developer.log(encoded, name: 'ATLAS_M4_DIAGNOSTIC');
  // ignore: avoid_print
  print('ATLAS_M4_DIAGNOSTIC $encoded');
  runApp(_DiagnosticEvidenceApp(evidence: evidence));
}

enum _DiagnosticScenario {
  insufficientSymbolEvidence('test-m4-insufficient-symbol-evidence-001'),
  symbolCandidatesAvailable('test-m4-symbol-candidates-001');

  const _DiagnosticScenario(this.fixtureId);

  final String fixtureId;

  static _DiagnosticScenario? parse(String value) => switch (value) {
    'insufficient-symbol-evidence' => insufficientSymbolEvidence,
    'symbol-candidates' => symbolCandidatesAvailable,
    _ => null,
  };
}

Future<Map<String, Object?>> _runDiagnostic(
  _DiagnosticScenario scenario,
) async {
  final includeBinding =
      scenario == _DiagnosticScenario.symbolCandidatesAvailable;
  final controller = AtlasK6Controller(
    dataset: _createDataset(),
    knowledgeRelease: _createKnowledgeRelease(),
    symbolDataset: _createSymbolDataset(includeBinding: includeBinding),
    readFile: (_) async => Uint8List.fromList(const [1, 2, 3]),
    analyzeFeatures: (input) async => _createFeatureSet(input.surfaceType),
    analyzePatterns: (featureSet) async => _createPatternResult(featureSet),
  );

  await controller.startCapture(() async => _createCapture());
  final state = controller.state;
  final result = state.result;
  final evidence = <String, Object?>{
    'fixtureId': scenario.fixtureId,
    'testOnly': true,
    'defaultProductionEntrypointModified': false,
    'injectionStage':
        'AtlasK6Controller capture/read/Vision/Pattern constructor seams; '
        'real KnowledgeRecordCollectionMatcher and SymbolCandidateResolver used',
    'expectedOutcome': switch (scenario) {
      _DiagnosticScenario.insufficientSymbolEvidence =>
        AtlasK6AggregateOutcome.insufficientSymbolEvidence.name,
      _DiagnosticScenario.symbolCandidatesAvailable =>
        AtlasK6AggregateOutcome.symbolCandidatesAvailable.name,
    },
    'actualOutcome': state.aggregateOutcome?.name,
    'phase': state.phase.name,
    'error': state.errorMessage,
    'knowledgeMatchCount': result?.matchedRecordCount,
    'symbolCandidateCount': result?.symbolCandidateCount,
    'surfaces': result == null
        ? const <Object?>[]
        : [
            _surfaceEvidence('cup', result.cupResult),
            _surfaceEvidence('saucer', result.saucerResult),
          ],
  };
  await controller.close();
  return evidence;
}

Map<String, Object?> _surfaceEvidence(
  String surface,
  AtlasK6SurfaceResult result,
) {
  return {
    'surface': surface,
    'patternCandidateCount': result.patternResult.candidates.length,
    'knowledgeMatchCount': result.matchedRecordCount,
    'symbolCandidateCount': result.symbolCandidateCount,
    'knowledgeMatches': [
      for (final candidate in result.candidateResults)
        for (final match in candidate.matches)
          {
            'candidateId': match.candidateId,
            'recordId': match.recordId,
            'matched': match.matched,
          },
    ],
    'symbolCandidates': [
      for (final candidate in result.symbolCandidates)
        {
          'patternCandidateId': candidate.patternCandidateId,
          'symbolId': candidate.symbolId,
          'symbolRevision': candidate.symbolRevision,
          'supportCount': candidate.supports.length,
          'bindingIds': [
            for (final support in candidate.supports) support.binding.bindingId,
          ],
          'knowledgeRecordIds': [
            for (final support in candidate.supports)
              support.knowledgeMatch.recordId,
          ],
        },
    ],
  };
}

KnowledgeDatasetReleaseRef _createKnowledgeRelease() {
  return KnowledgeDatasetReleaseRef(
    releaseId: 'kds-001',
    checksum:
        'sha256:18b65abeca6971cc98153f0c5781bcdffecb2869fc4fabb205d004f9fb372895',
  );
}

KnowledgeDatasetSnapshot _createDataset() {
  return KnowledgeDatasetSnapshot(
    schemaVersion: '1.0',
    datasetVersion: 'kds-001',
    totalRecordCount: 1,
    activeRecords: [
      KnowledgeRecord(
        id: 'physical-pattern-001',
        constraints: [
          KnowledgeConstraint.doubleRange(
            key: KnowledgeConstraintKey.geometryCentroidX,
            minimum: 0.49,
            maximum: 0.54,
          ),
          KnowledgeConstraint.doubleRange(
            key: KnowledgeConstraintKey.geometryCentroidY,
            minimum: 0.47,
            maximum: 0.52,
          ),
          KnowledgeConstraint.integerRange(
            key: KnowledgeConstraintKey.topologyNodeCount,
            minimum: 60,
            maximum: 64,
          ),
        ],
      ),
    ],
  );
}

SymbolDatasetSnapshot _createSymbolDataset({required bool includeBinding}) {
  final knowledgeRelease = _createKnowledgeRelease();
  final profile = CanonicalJsonProfileRef(
    profileId: 'atlas-canonical-json',
    revision: 1,
    checksum: _profileChecksum,
  );
  final symbolRef = SymbolRevisionRef(
    symbolId: 'test-symbol-001',
    revision: 1,
    checksum:
        'sha256:0101010101010101010101010101010101010101010101010101010101010101',
  );
  final definition = SymbolDefinition(
    symbolRef: symbolRef,
    canonicalJsonProfileRef: profile,
    preferredNames: [
      SourcedLocalizedText(
        language: 'en',
        value: 'Test Symbol 1',
        sourceRefs: [SourceRef(sourceId: 'test-source-001', revision: 1)],
      ),
    ],
    neutralDefinitions: [
      SourcedLocalizedText(
        language: 'en',
        value: 'Synthetic definition for Android orchestration diagnostics.',
        sourceRefs: [SourceRef(sourceId: 'test-source-001', revision: 1)],
      ),
    ],
  );
  final binding = SymbolEvidenceBinding(
    bindingId: 'test-binding-001',
    revision: 1,
    canonicalJsonProfileRef: profile,
    symbolRef: symbolRef,
    knowledgeTargetRef: KnowledgeTargetRef(
      knowledgeRelease: knowledgeRelease,
      knowledgeRecordId: 'physical-pattern-001',
    ),
    evidenceAssessmentRefs: [
      EvidenceAssessmentRef(
        assessmentId: 'test-assessment-001',
        revision: 1,
        assessmentType: EvidenceAssessmentType.holdoutValidation,
        checksum:
            'sha256:0202020202020202020202020202020202020202020202020202020202020202',
      ),
    ],
  );
  final bindings = includeBinding ? [binding] : <SymbolEvidenceBinding>[];
  final records = <SymbolReleaseRecordRef>[
    SymbolReleaseRecordRef(
      recordType: SymbolDatasetRecordType.symbolDefinition,
      recordId: definition.symbolId,
      revision: definition.revision,
      checksum: definition.symbolRef.checksum,
    ),
    if (includeBinding)
      SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolEvidenceBinding,
        recordId: binding.bindingId,
        revision: binding.revision,
        checksum:
            'sha256:0303030303030303030303030303030303030303030303030303030303030303',
      ),
  ];
  final manifest = SymbolReleaseManifest.v2(
    schemaVersion: '2.0',
    releaseId: includeBinding
        ? 'test-symbol-release-binding-001'
        : 'test-symbol-release-definition-only-001',
    createdAtUtc: '2026-09-01T00:00:00Z',
    canonicalJsonProfileRef: profile,
    governanceSnapshotRef: GovernanceSnapshotRef(
      snapshotId: 'test-governance-001',
      checksum:
          'sha256:0404040404040404040404040404040404040404040404040404040404040404',
    ),
    records: records,
    sourceCatalogReleaseRef: SourceCatalogReleaseRef(
      releaseId: 'test-source-release-001',
      checksum:
          'sha256:0505050505050505050505050505050505050505050505050505050505050505',
    ),
    symbolAdmissionPolicyRef: SymbolAdmissionPolicyRef(
      policyId: 'test-symbol-policy-001',
      revision: 1,
      checksum:
          'sha256:0606060606060606060606060606060606060606060606060606060606060606',
    ),
    evidenceAdmissionPolicyRef: includeBinding
        ? EvidenceAdmissionPolicyRef(
            policyId: 'test-evidence-policy-001',
            revision: 1,
            checksum:
                'sha256:0707070707070707070707070707070707070707070707070707070707070707',
          )
        : null,
    evidenceAssessmentRegistryReleaseRef: includeBinding
        ? EvidenceAssessmentRegistryReleaseRef(
            releaseId: 'test-assessment-release-001',
            checksum:
                'sha256:0808080808080808080808080808080808080808080808080808080808080808',
          )
        : null,
    knowledgeDatasetReleaseRefs: includeBinding ? [knowledgeRelease] : const [],
    manifestChecksum:
        'sha256:0909090909090909090909090909090909090909090909090909090909090909',
  );
  return SymbolDatasetSnapshot(
    manifest: manifest,
    definitions: [definition],
    bindings: bindings,
  );
}

CoffeeCameraCaptureResult _createCapture() {
  return CoffeeCameraCaptureResult(
    cup: _capture('test-cup-crop.jpg'),
    saucer: _capture('test-saucer-crop.jpg'),
  );
}

CameraCaptureResult _capture(String path) {
  return CameraCaptureResult(
    filePath: path,
    cropRect: const Rect.fromLTWH(0, 0, 10, 10),
    widthPixels: 100,
    heightPixels: 100,
    fileSizeBytes: 10,
    croppedWidthPixels: 80,
    croppedHeightPixels: 80,
    croppedFileSizeBytes: 8,
    capturedAt: DateTime.utc(2026, 9, 1),
    qualityScore: 80,
    coffeePresenceScore: 0.8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}

VisionFeatureSet _createFeatureSet(VisionSurfaceType surfaceType) {
  return VisionFeatureSet(
    surfaceType: surfaceType,
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

PatternAnalysisResult _createPatternResult(VisionFeatureSet featureSet) {
  return PatternAnalysisResult(
    surfaceType: switch (featureSet.surfaceType) {
      VisionSurfaceType.cup => PatternSurfaceType.cup,
      VisionSurfaceType.saucer => PatternSurfaceType.saucer,
    },
    candidates: [
      PatternCandidate.withGeometryAndTopology(
        id: 1,
        evidence: [PatternEvidence.connectedStructure(1)],
        geometry: PatternGeometry(
          left: 0.1,
          top: 0.1,
          right: 0.9,
          bottom: 0.9,
          centroidX: 0.51,
          centroidY: 0.50,
        ),
        topology: PatternTopology(nodeCount: 62, directedEdgeCount: 0),
      ),
    ],
  );
}

final class _DiagnosticEvidenceApp extends StatelessWidget {
  const _DiagnosticEvidenceApp({required this.evidence});

  final Map<String, Object?> evidence;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(evidence);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Atlas M4 Diagnostic — TEST ONLY')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(pretty),
        ),
      ),
    );
  }
}

final class _DiagnosticDisabledApp extends StatelessWidget {
  const _DiagnosticDisabledApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'ATLAS M4 DIAGNOSTIC DISABLED\n'
            'This test-only entrypoint requires an explicit scenario.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
