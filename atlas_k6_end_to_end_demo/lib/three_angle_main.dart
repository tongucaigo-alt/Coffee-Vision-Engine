import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/capture/atlas_three_angle_capture_app.dart';
import 'src/integration/atlas_k6_surface_processor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final datasetSource = await rootBundle.loadString(
      'assets/kds-001/knowledge_dataset.json',
    );
    final dataset = const KnowledgeDatasetParser().parse(datasetSource);
    final symbolManifest = await rootBundle.load(
      'assets/test-symbol-dataset/manifest.json',
    );
    final symbolDefinition = await rootBundle.load(
      'assets/test-symbol-dataset/records/test-symbol-001.json',
    );
    final symbolDataset = const SymbolDatasetParser().parse(
      manifestBytes: _bytes(symbolManifest),
      recordDocuments: [_bytes(symbolDefinition)],
    );
    final knowledgeRelease = KnowledgeDatasetReleaseRef(
      releaseId: dataset.datasetVersion,
      checksum:
          'sha256:18b65abeca6971cc98153f0c5781bcdffecb2869fc4fabb205d004f9fb372895',
    );
    final processor = AtlasK6SurfaceProcessor(
      dataset: dataset,
      knowledgeRelease: knowledgeRelease,
      symbolDataset: symbolDataset,
    );
    runApp(
      AtlasThreeAngleCaptureApp(
        processSurface: ({required role, required path}) =>
            processor.process(path: path, surfaceType: VisionSurfaceType.cup),
      ),
    );
  } catch (_) {
    runApp(
      AtlasThreeAngleCaptureApp(
        processSurface: ({required role, required path}) async =>
            throw StateError('three-angle engine setup unavailable'),
        setupErrorMessage:
            'Motor verileri doğrulanamadı. Çekim başlatılamıyor.',
      ),
    );
  }
}

Uint8List _bytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
