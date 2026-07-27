import 'dart:convert';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;

import '../../tool/validation/src/content_checksum.dart';
import '../../tool/validation/src/validation_models.dart';

Uint8List createPngBytes({
  int width = 8,
  int height = 8,
  bool withResidue = false,
}) {
  final source = _image(width, height, withResidue: withResidue);
  return Uint8List.fromList(image.encodePng(source));
}

Uint8List createJpegBytes({
  int width = 8,
  int height = 8,
  bool withResidue = false,
}) {
  final source = _image(width, height, withResidue: withResidue);
  return Uint8List.fromList(image.encodeJpg(source, quality: 100));
}

Future<VisionPipelineResult> createPipelineResult({
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
  String sourceId = 'sample-001',
  bool withResidue = true,
  VisionEdgeSelectionProfile edgeSelectionProfile =
      const VisionEdgeSelectionProfile(),
}) {
  const engine = CoffeeVisionEngine(config: VisionConfig(workingResolution: 8));
  return engine.analyzeDetailed(
    VisionImageInput(
      imageBytes: createPngBytes(withResidue: withResidue),
      surfaceType: surfaceType,
      sourceId: sourceId,
    ),
    edgeSelectionProfile: edgeSelectionProfile,
  );
}

ValidationDatasetEntry createEntry({
  String sourceId = 'sample-001',
  String relativePath = 'sample.png',
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
  VisionImageFormat format = VisionImageFormat.png,
  bool enabled = true,
  Uint8List? bytes,
}) {
  final content = bytes ?? createPngBytes();
  return ValidationDatasetEntry(
    sourceId: sourceId,
    relativePath: relativePath,
    surfaceType: surfaceType,
    format: format,
    ownership: 'synthetic-test-fixture',
    consent: 'test-use-only',
    enabled: enabled,
    contentChecksum: computeContentChecksum(content),
  );
}

Map<String, Object?> entryJson(ValidationDatasetEntry entry) => entry.toJson();

String manifestJson(Iterable<ValidationDatasetEntry> entries) {
  return jsonEncode(<String, Object?>{
    'schemaVersion': '1.0',
    'entries': entries.map(entryJson).toList(),
  });
}

ValidationImageMetrics createMetrics({
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
  String sourceId = 'sample-001',
}) {
  return ValidationImageMetrics(
    surfaceType: surfaceType,
    sourceId: sourceId,
    workingImageWidth: 8,
    workingImageHeight: 8,
    workingResiduePixelCount: 3,
    workingContentResidueAreaRatio: 3 / 64,
    componentCount: 2,
    relationCount: 2,
    selectedEdgeCount: 2,
    graphNodeCount: 2,
    graphEdgeCount: 2,
    structureCount: 1,
    largestStructureSize: 2,
    isolatedStructureCount: 0,
  );
}

ValidationImageRecord createSuccessRecord({
  ValidationDatasetEntry? entry,
  ValidationImageMetrics? metrics,
}) {
  final resolvedEntry = entry ?? createEntry();
  return ValidationImageRecord(
    entry: resolvedEntry,
    analysisStatus: ValidationAnalysisStatus.success,
    determinismStatus: ValidationDeterminismStatus.deterministic,
    repeatsPerformed: 3,
    metrics:
        metrics ??
        createMetrics(
          surfaceType: resolvedEntry.surfaceType,
          sourceId: resolvedEntry.sourceId,
        ),
  );
}

image.Image _image(int width, int height, {required bool withResidue}) {
  final result = image.Image(width: width, height: height, numChannels: 4);
  for (final pixel in result) {
    pixel.setRgba(255, 255, 255, 255);
  }
  if (withResidue && width >= 2 && height >= 2) {
    result.setPixelRgba(0, 0, 0, 0, 0, 255);
    result.setPixelRgba(0, 1, 0, 0, 0, 255);
    result.setPixelRgba(width - 1, height - 1, 0, 0, 0, 255);
  }
  return result;
}
