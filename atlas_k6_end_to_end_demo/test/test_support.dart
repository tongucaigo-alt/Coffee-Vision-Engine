import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';

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

PatternAnalysisResult createPatternResult(VisionFeatureSet featureSet) {
  final candidate = PatternCandidate.withGeometryAndTopology(
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
