import 'dart:io';

import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runKnowledgeDatasetValidator(
    arguments,
    output: stdout,
    errors: stderr,
  );
}

Future<int> runKnowledgeDatasetValidator(
  List<String> arguments, {
  required StringSink output,
  required StringSink errors,
}) async {
  if (arguments.length != 1 || arguments.single.isEmpty) {
    errors.writeln(
      'Usage: dart run tool/knowledge_dataset_validator.dart <dataset>',
    );
    return 2;
  }

  final String source;
  try {
    source = await File(arguments.single).readAsString();
  } on FileSystemException {
    errors.writeln('Knowledge dataset could not be read.');
    return 2;
  }

  try {
    final snapshot = const KnowledgeDatasetParser().parse(source);
    output.writeln(
      'VALID ${snapshot.datasetVersion}: '
      '${snapshot.activeRecords.length} active, '
      '${snapshot.disabledRecordCount} disabled.',
    );
    return 0;
  } on KnowledgeDatasetException catch (error) {
    errors.writeln(error.message);
    return 1;
  }
}
