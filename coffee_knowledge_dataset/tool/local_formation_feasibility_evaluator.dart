import 'dart:io';

import 'src/lf2_review.dart';

Future<void> main(List<String> arguments) async {
  final options = Lf2FeasibilityOptions.parse(arguments);
  final observations = Lf2ObservationIndex.parse(
    await File(options.observationsPath).readAsString(),
  );
  final groundTruth = const Lf2GroundTruthCodec().parse(
    source: await File(options.groundTruthPath).readAsString(),
    observations: observations,
  );
  final review = const Lf2AlignmentCodec().createDefault(
    observations: observations,
    groundTruth: groundTruth,
  );
  final evaluation = const Lf2Evaluator().evaluate(
    observations: observations,
    groundTruth: groundTruth,
    review: review,
    alignmentReviewCompleted: false,
  );
  await const Lf2ReviewWriter().writeFeasibility(
    outputDirectory: options.outputDirectory,
    repositoryRoot: options.repositoryRoot,
    evaluation: evaluation,
  );
  stdout.writeln(
    evaluation.allProfilesEliminatedByUpperBound
        ? 'LF-2 feasibility: all profiles eliminated.'
        : 'LF-2 feasibility: human review required.',
  );
}

final class Lf2FeasibilityOptions {
  const Lf2FeasibilityOptions({
    required this.observationsPath,
    required this.groundTruthPath,
    required this.outputDirectory,
    required this.repositoryRoot,
  });

  factory Lf2FeasibilityOptions.parse(List<String> arguments) {
    const flags = {
      '--observations',
      '--ground-truth',
      '--output',
      '--repository-root',
    };
    if (arguments.length.isOdd) {
      throw const FormatException('LF-2 feasibility flags require values.');
    }
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final flag = arguments[index];
      if (!flags.contains(flag) || values.containsKey(flag)) {
        throw FormatException('Invalid LF-2 feasibility flag: $flag.');
      }
      final value = arguments[index + 1];
      if (value.isEmpty) {
        throw FormatException('Missing LF-2 feasibility value: $flag.');
      }
      values[flag] = value;
    }
    if (!values.keys.toSet().containsAll(flags)) {
      throw const FormatException('Missing LF-2 feasibility flag.');
    }
    return Lf2FeasibilityOptions(
      observationsPath: values['--observations']!,
      groundTruthPath: values['--ground-truth']!,
      outputDirectory: values['--output']!,
      repositoryRoot: values['--repository-root']!,
    );
  }

  final String observationsPath;
  final String groundTruthPath;
  final String outputDirectory;
  final String repositoryRoot;
}
