import 'dart:io';

import 'src/k6a_dataset.dart';
import 'src/lf1_report.dart';
import 'src/lf1_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runLf1Cli(arguments, output: stdout, errors: stderr);
}

Future<int> runLf1Cli(
  List<String> arguments, {
  required StringSink output,
  required StringSink errors,
  Lf1ProfileRunner? runner,
  Lf1ReportWriter writer = const Lf1ReportWriter(),
}) async {
  final Lf1CliOptions options;
  try {
    options = Lf1CliOptions.parse(arguments);
  } on FormatException catch (error) {
    errors.writeln(error.message);
    return 2;
  }

  final effectiveRunner =
      runner ??
      Lf1ProfileRunner(
        progressListener: (completed, total, observation) {
          output.writeln(
            '[$completed/$total] ${observation.profileId} '
            '${observation.sourceId}: ${observation.analysisStatus.name}, '
            '${observation.determinismStatus.name}, '
            '${observation.candidates.length} candidates',
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
      repositoryRoot: options.repositoryRoot,
    );
    output.writeln(
      'LF-1 ${report.researchId}: ${report.observations.length} '
      'profile-image observations, status '
      '${report.succeeded ? 'PASS' : 'REVIEW REQUIRED'}.',
    );
    for (final path in paths) {
      output.writeln(path);
    }
    return report.succeeded ? 0 : 1;
  } on K6aDatasetException catch (error) {
    errors.writeln(error.message);
    return 2;
  } on Lf1ReportWriteException catch (error) {
    errors.writeln(error.message);
    return 3;
  } on ArgumentError catch (error) {
    errors.writeln(error.message);
    return 2;
  } on Object {
    errors.writeln('LF-1 profile research failed.');
    return 1;
  }
}

final class Lf1CliOptions {
  const Lf1CliOptions({
    required this.datasetRoot,
    required this.manifestPath,
    required this.freezePath,
    required this.outputDirectory,
    required this.repositoryRoot,
    required this.repeatCount,
    required this.researchId,
  });

  factory Lf1CliOptions.parse(List<String> arguments) {
    const flags = {
      '--dataset',
      '--manifest',
      '--freeze',
      '--output',
      '--repository-root',
      '--repeat',
      '--research-id',
    };
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final flag = arguments[index];
      if (!flags.contains(flag)) {
        throw FormatException('Unknown LF-1 flag: $flag.');
      }
      if (values.containsKey(flag)) {
        throw FormatException('Duplicate LF-1 flag: $flag.');
      }
      if (index + 1 >= arguments.length || arguments[index + 1].isEmpty) {
        throw FormatException('Missing value for LF-1 flag: $flag.');
      }
      values[flag] = arguments[index + 1];
    }
    for (final flag in const {
      '--dataset',
      '--manifest',
      '--freeze',
      '--output',
      '--repository-root',
    }) {
      if (!values.containsKey(flag)) {
        throw FormatException('Missing required LF-1 flag: $flag.');
      }
    }
    final repeat = values.containsKey('--repeat')
        ? int.tryParse(values['--repeat']!)
        : 3;
    if (repeat == null || repeat <= 0) {
      throw const FormatException('--repeat must be a positive integer.');
    }
    final researchId = values['--research-id'] ?? 'lfr-001';
    if (researchId.isEmpty || researchId.trim() != researchId) {
      throw const FormatException(
        '--research-id must be non-empty with no surrounding whitespace.',
      );
    }
    return Lf1CliOptions(
      datasetRoot: values['--dataset']!,
      manifestPath: values['--manifest']!,
      freezePath: values['--freeze']!,
      outputDirectory: values['--output']!,
      repositoryRoot: values['--repository-root']!,
      repeatCount: repeat,
      researchId: researchId,
    );
  }

  final String datasetRoot;
  final String manifestPath;
  final String freezePath;
  final String outputDirectory;
  final String repositoryRoot;
  final int repeatCount;
  final String researchId;
}
