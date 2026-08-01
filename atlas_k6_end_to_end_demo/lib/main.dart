import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/atlas_k6_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final datasetSource = await rootBundle.loadString(
    'assets/kds-001/knowledge_dataset.json',
  );
  final dataset = const KnowledgeDatasetParser().parse(datasetSource);
  runApp(AtlasK6EndToEndApp(dataset: dataset));
}
