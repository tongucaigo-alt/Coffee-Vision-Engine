import 'dart:io';

import 'src/validation_runner.dart';

const validationUsage =
    'Usage: dart run tool/validation/validation_runner.dart '
    '--dataset <dataset-root> --manifest <manifest-path> '
    '--output <report-directory> [--repeat <positive-integer>]';

final class ValidationCliArguments {
  const ValidationCliArguments({
    required this.datasetPath,
    required this.manifestPath,
    required this.outputPath,
    required this.repeatCount,
  });

  final String datasetPath;
  final String manifestPath;
  final String outputPath;
  final int repeatCount;
}

ValidationCliArguments parseValidationCliArguments(List<String> arguments) {
  const supported = {'--dataset', '--manifest', '--output', '--repeat'};
  final values = <String, String>{};
  var index = 0;
  while (index < arguments.length) {
    final flag = arguments[index];
    if (!supported.contains(flag)) {
      throw FormatException('Unknown argument: $flag');
    }
    if (values.containsKey(flag)) {
      throw FormatException('Duplicate argument: $flag');
    }
    if (index + 1 >= arguments.length ||
        arguments[index + 1].startsWith('--')) {
      throw FormatException('Missing value for $flag.');
    }
    values[flag] = arguments[index + 1];
    index += 2;
  }

  for (final requiredFlag in const ['--dataset', '--manifest', '--output']) {
    final value = values[requiredFlag];
    if (value == null || value.trim().isEmpty) {
      throw FormatException('Missing required argument: $requiredFlag');
    }
  }
  final repeatText = values['--repeat'] ?? '3';
  final repeatCount = int.tryParse(repeatText);
  if (repeatCount == null || repeatCount <= 0) {
    throw const FormatException('--repeat must be a positive integer.');
  }
  return ValidationCliArguments(
    datasetPath: values['--dataset']!,
    manifestPath: values['--manifest']!,
    outputPath: values['--output']!,
    repeatCount: repeatCount,
  );
}

Future<void> main(List<String> arguments) async {
  final ValidationCliArguments parsed;
  try {
    parsed = parseValidationCliArguments(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(validationUsage);
    exitCode = 2;
    return;
  }

  final String packageVersion;
  try {
    packageVersion = await _readPackageVersion();
  } on Object {
    stderr.writeln('Package version could not be read.');
    exitCode = 2;
    return;
  }

  final outcome = await ValidationRunner().run(
    datasetRoot: Directory(parsed.datasetPath),
    manifestFile: File(parsed.manifestPath),
    outputDirectory: Directory(parsed.outputPath),
    repeatCount: parsed.repeatCount,
    packageVersion: packageVersion,
  );
  if (outcome.reportWriteError != null) {
    stderr.writeln(outcome.reportWriteError!.message);
  } else {
    stdout.writeln(
      'Validation completed: '
      '${outcome.report.overallSummary.successfulAnalysisCount} successful, '
      '${outcome.report.overallSummary.failedAnalysisCount} failed, '
      '${outcome.report.overallSummary.nonDeterministicCount} '
      'non-deterministic.',
    );
  }
  exitCode = outcome.exitCode;
}

Future<String> _readPackageVersion() async {
  final script = File.fromUri(Platform.script);
  final packageRoot = script.parent.parent.parent;
  final pubspec = await File(
    '${packageRoot.path}${Platform.pathSeparator}pubspec.yaml',
  ).readAsLines();
  for (final line in pubspec) {
    final match = RegExp(r'^version:\s*([^\s#]+)').firstMatch(line);
    if (match != null) return match.group(1)!;
  }
  throw const FormatException('pubspec.yaml does not declare a version.');
}
