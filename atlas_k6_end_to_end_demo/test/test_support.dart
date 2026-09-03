import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:coffee_vision/coffee_vision.dart';

const _profileChecksum =
    'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7';

KnowledgeDatasetReleaseRef createKnowledgeRelease({
  String releaseId = 'kds-001',
  String checksum =
      'sha256:18b65abeca6971cc98153f0c5781bcdffecb2869fc4fabb205d004f9fb372895',
}) => KnowledgeDatasetReleaseRef(releaseId: releaseId, checksum: checksum);

SymbolDatasetSnapshot createSymbolDataset({
  bool includeBindings = false,
  int symbolCount = 1,
  KnowledgeDatasetReleaseRef? knowledgeRelease,
  String knowledgeRecordId = 'physical-pattern-001',
}) {
  final release = knowledgeRelease ?? createKnowledgeRelease();
  final profile = CanonicalJsonProfileRef(
    profileId: 'atlas-canonical-json',
    revision: 1,
    checksum: _profileChecksum,
  );
  final definitions = List<SymbolDefinition>.generate(symbolCount, (index) {
    final number = index + 1;
    final symbolId = 'test-symbol-${number.toString().padLeft(3, '0')}';
    final symbolRef = SymbolRevisionRef(
      symbolId: symbolId,
      revision: 1,
      checksum: _checksum(number),
    );
    final source = SourceRef(
      sourceId: 'test-source-${number.toString().padLeft(3, '0')}',
      revision: 1,
    );
    return SymbolDefinition(
      symbolRef: symbolRef,
      canonicalJsonProfileRef: profile,
      preferredNames: [
        SourcedLocalizedText(
          language: 'en',
          value: 'Test Symbol $number',
          sourceRefs: [source],
        ),
      ],
      neutralDefinitions: [
        SourcedLocalizedText(
          language: 'en',
          value: 'Synthetic definition $number for integration testing.',
          sourceRefs: [source],
        ),
      ],
    );
  });
  final bindings = includeBindings
      ? List<SymbolEvidenceBinding>.generate(definitions.length, (index) {
          final number = index + 1;
          return SymbolEvidenceBinding(
            bindingId: 'test-binding-${number.toString().padLeft(3, '0')}',
            revision: 1,
            canonicalJsonProfileRef: profile,
            symbolRef: definitions[index].symbolRef,
            knowledgeTargetRef: KnowledgeTargetRef(
              knowledgeRelease: release,
              knowledgeRecordId: knowledgeRecordId,
            ),
            evidenceAssessmentRefs: [
              EvidenceAssessmentRef(
                assessmentId:
                    'test-assessment-${number.toString().padLeft(3, '0')}',
                revision: 1,
                assessmentType: EvidenceAssessmentType.holdoutValidation,
                checksum: _checksum(20 + number),
              ),
            ],
          );
        })
      : <SymbolEvidenceBinding>[];
  final records = <SymbolReleaseRecordRef>[
    for (final definition in definitions)
      SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolDefinition,
        recordId: definition.symbolId,
        revision: definition.revision,
        checksum: definition.symbolRef.checksum,
      ),
    for (var index = 0; index < bindings.length; index++)
      SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolEvidenceBinding,
        recordId: bindings[index].bindingId,
        revision: bindings[index].revision,
        checksum: _checksum(40 + index),
      ),
  ];
  final manifest = SymbolReleaseManifest.v2(
    schemaVersion: '2.0',
    releaseId: 'test-symbol-release-001',
    createdAtUtc: '2026-08-22T00:00:00Z',
    canonicalJsonProfileRef: profile,
    governanceSnapshotRef: GovernanceSnapshotRef(
      snapshotId: 'test-governance-001',
      checksum: _checksum(50),
    ),
    records: records,
    sourceCatalogReleaseRef: SourceCatalogReleaseRef(
      releaseId: 'test-source-release-001',
      checksum: _checksum(51),
    ),
    symbolAdmissionPolicyRef: SymbolAdmissionPolicyRef(
      policyId: 'test-symbol-policy-001',
      revision: 1,
      checksum: _checksum(52),
    ),
    evidenceAdmissionPolicyRef: includeBindings
        ? EvidenceAdmissionPolicyRef(
            policyId: 'test-evidence-policy-001',
            revision: 1,
            checksum: _checksum(53),
          )
        : null,
    evidenceAssessmentRegistryReleaseRef: includeBindings
        ? EvidenceAssessmentRegistryReleaseRef(
            releaseId: 'test-assessment-release-001',
            checksum: _checksum(54),
          )
        : null,
    knowledgeDatasetReleaseRefs: includeBindings ? [release] : const [],
    manifestChecksum: _checksum(55),
  );
  return SymbolDatasetSnapshot(
    manifest: manifest,
    definitions: definitions,
    bindings: bindings,
  );
}

String _checksum(int value) =>
    'sha256:${value.toRadixString(16).padLeft(64, '0')}';

KnowledgeDatasetSnapshot createDataset() {
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

CoffeeCameraCaptureResult createCapture() {
  return CoffeeCameraCaptureResult(
    cup: _capture(filePath: 'cup-original.jpg', croppedCupPath: 'cup-crop.jpg'),
    saucer: _capture(
      filePath: 'saucer-original.jpg',
      croppedSaucerPath: 'saucer-crop.jpg',
    ),
  );
}

CameraCaptureResult _capture({
  required String filePath,
  String? croppedCupPath,
  String? croppedSaucerPath,
}) {
  return CameraCaptureResult(
    filePath: filePath,
    croppedCupPath: croppedCupPath,
    croppedSaucerPath: croppedSaucerPath,
    cropRect: const Rect.fromLTWH(0, 0, 10, 10),
    widthPixels: 100,
    heightPixels: 100,
    fileSizeBytes: 10,
    croppedWidthPixels: 80,
    croppedHeightPixels: 80,
    croppedFileSizeBytes: 8,
    capturedAt: DateTime.utc(2026, 8, 1),
    qualityScore: 80,
    coffeePresenceScore: 0.8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}

VisionFeatureSet createFeatureSet(VisionSurfaceType surfaceType) {
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

PatternAnalysisResult createPatternResult(
  VisionFeatureSet featureSet, {
  double centroidX = 0.51,
  double centroidY = 0.50,
  int nodeCount = 62,
}) {
  final candidate = PatternCandidate.withGeometryAndTopology(
    id: 1,
    evidence: [PatternEvidence.connectedStructure(1)],
    geometry: PatternGeometry(
      left: 0.1,
      top: 0.1,
      right: 0.9,
      bottom: 0.9,
      centroidX: centroidX,
      centroidY: centroidY,
    ),
    topology: PatternTopology(nodeCount: nodeCount, directedEdgeCount: 0),
  );
  return PatternAnalysisResult(
    surfaceType: switch (featureSet.surfaceType) {
      VisionSurfaceType.cup => PatternSurfaceType.cup,
      VisionSurfaceType.saucer => PatternSurfaceType.saucer,
    },
    candidates: [candidate],
  );
}

Future<Uint8List> fakeRead(String path) async => Uint8List.fromList([1, 2, 3]);
