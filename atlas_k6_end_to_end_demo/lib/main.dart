import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/atlas_k6_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(
    AtlasK6EndToEndApp(
      dataset: dataset,
      knowledgeRelease: knowledgeRelease,
      symbolDataset: symbolDataset,
    ),
  );
}

Uint8List _bytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
