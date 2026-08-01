import 'dart:io';

import 'src/k6a_dataset.dart';
import 'src/k6a_report.dart';
import 'src/k6a_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runK6aCli(arguments, output: stdout, errors: stderr);
}

Future<int> runK6aCli(
  List<String> arguments, {
  required StringSink output,
  required StringSink errors,
  K6aObservationRunner? runner,
  K6aReportWriter writer = const K6aReportWriter(),
}) async {
  final K6aCliOptions options;
  try {
    options = K6aCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errors.writeln(error.message);
    return 2;
  }

  final effectiveRunner =
      runner ??
      K6aObservationRunner(
        progressListener: (completed, total, observation) {
          output.writeln(
            '[$completed/$total] ${observation.sourceId}: '
            '${observation.analysisStatus.name}, '
            '${observation.determinismStatus.name}',
          );
        },
      );

  try {
    final report = await effectiveRunner.run(
      datasetRoot: options.datasetRoot,
      manifestPath: options.manifestPath,
      freezePath: options.freezePath,
      repeatCount: options.repeatCount,
      researchId: options.researchId,
    );
    final paths = await writer.write(
      report: report,
      outputDirectory: options.outputDirectory,
    );
    output.writeln(
      'K6A ${report.researchId}: '
      '${report.summary.successfulEntries}/'
      '${report.summary.enabledEntries} successful, '
      '${report.summary.deterministicEntries}/'
      '${report.summary.enabledEntries} deterministic, '
      '${report.summary.candidateCount} candidates.',
    );
    for (final path in paths) {
      output.writeln(path);
    }
    return report.succeeded ? 0 : 1;
  } on K6aDatasetException catch (error) {
    errors.writeln(error.message);
    return 2;
  } on K6aReportWriteException catch (error) {
    errors.writeln(error.message);
    return 3;
  } on ArgumentError catch (error) {
    errors.writeln(error.message);
    return 2;
  } on Object {
    errors.writeln('K6A observation run failed.');
    return 1;
  }
}

final class K6aCliOptions {
  const K6aCliOptions({
    required this.datasetRoot,
    required this.manifestPath,
    required this.freezePath,
    required this.outputDirectory,
    required this.repeatCount,
    required this.researchId,
  });

  factory K6aCliOptions.parse(List<String> arguments) {
    const valueFlags = {
      '--dataset',
      '--manifest',
      '--freeze',
      '--output',
      '--repeat',
      '--research-id',
    };
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final flag = arguments[index];
      if (!valueFlags.contains(flag)) {
        throw FormatException('Unknown K6A flag: $flag.');
      }
      if (values.containsKey(flag)) {
        throw FormatException('Duplicate K6A flag: $flag.');
      }
      if (index + 1 >= arguments.length || arguments[index + 1].isEmpty) {
        throw FormatException('Missing value for K6A flag: $flag.');
      }
      values[flag] = arguments[index + 1];
    }
    for (final requiredFlag in const {
      '--dataset',
      '--manifest',
      '--freeze',
      '--output',
    }) {
      if (!values.containsKey(requiredFlag)) {
        throw FormatException('Missing required K6A flag: $requiredFlag.');
      }
    }
    final repeatCount = values.containsKey('--repeat')
        ? int.tryParse(values['--repeat']!)
        : 3;
    if (repeatCount == null || repeatCount <= 0) {
      throw const FormatException('--repeat must be a positive integer.');
    }
    final researchId = values['--research-id'] ?? 'kdr-001';
    if (researchId.isEmpty || researchId.trim() != researchId) {
      throw const FormatException(
        '--research-id must be non-empty with no surrounding whitespace.',
      );
    }
    return K6aCliOptions(
      datasetRoot: values['--dataset']!,
      manifestPath: values['--manifest']!,
      freezePath: values['--freeze']!,
      outputDirectory: values['--output']!,
      repeatCount: repeatCount,
      researchId: researchId,
    );
  }

  final String datasetRoot;
  final String manifestPath;
  final String freezePath;
  final String outputDirectory;
  final int repeatCount;
  final String researchId;
}
