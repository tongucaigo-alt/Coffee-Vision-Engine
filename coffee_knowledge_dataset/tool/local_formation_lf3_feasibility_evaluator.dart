import 'dart:io';

import 'src/lf3_review.dart';

Future<void> main(List<String> arguments) async {
  final options = Lf3FeasibilityOptions.parse(arguments);
  final bundle = const Lf3FeasibilityEvaluator().evaluate(
    observationSource: await File(options.observationsPath).readAsString(),
    groundTruthSource: await File(options.groundTruthPath).readAsString(),
    alignmentReviewSource: options.alignmentReviewPath == null
        ? null
        : await File(options.alignmentReviewPath!).readAsString(),
  );
  final paths = await const Lf3EvaluationWriter().write(
    outputDirectory: options.outputDirectory,
    repositoryRoot: options.repositoryRoot,
    bundle: bundle,
    replaceEvaluationArtifacts: options.replaceEvaluationArtifacts,
  );
  stdout.writeln(
    bundle.alignmentReviewCompleted
        ? 'LF-3 human review: '
              '${bundle.evaluation.productionProfileCandidateId ?? 'no profile passed'}.'
        : bundle.requiresHumanReview
        ? 'LF-3 feasibility: human review required.'
        : 'LF-3 feasibility: all profiles eliminated.',
  );
  for (final path in paths) {
    stdout.writeln(path);
  }
}

final class Lf3FeasibilityOptions {
  const Lf3FeasibilityOptions({
    required this.observationsPath,
    required this.groundTruthPath,
    required this.outputDirectory,
    required this.repositoryRoot,
    required this.alignmentReviewPath,
    required this.replaceEvaluationArtifacts,
  });

  factory Lf3FeasibilityOptions.parse(List<String> arguments) {
    const flags = {
      '--observations',
      '--ground-truth',
      '--output',
      '--repository-root',
      '--alignment-review',
      '--replace-evaluation',
    };
    if (arguments.length.isOdd) {
      throw const FormatException('LF-3 feasibility flags require values.');
    }
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final flag = arguments[index];
      if (!flags.contains(flag) || values.containsKey(flag)) {
        throw FormatException('Invalid LF-3 feasibility flag: $flag.');
      }
      final value = arguments[index + 1];
      if (value.isEmpty) {
        throw FormatException('Missing LF-3 feasibility value: $flag.');
      }
      values[flag] = value;
    }
    if (!values.keys.toSet().containsAll(const {
      '--observations',
      '--ground-truth',
      '--output',
      '--repository-root',
    })) {
      throw const FormatException('Missing LF-3 feasibility flag.');
    }
    final replaceValue = values['--replace-evaluation'] ?? 'false';
    if (replaceValue != 'true' && replaceValue != 'false') {
      throw const FormatException(
        '--replace-evaluation must be true or false.',
      );
    }
    if (replaceValue == 'true' && !values.containsKey('--alignment-review')) {
      throw const FormatException(
        '--replace-evaluation requires --alignment-review.',
      );
    }
    return Lf3FeasibilityOptions(
      observationsPath: values['--observations']!,
      groundTruthPath: values['--ground-truth']!,
      outputDirectory: values['--output']!,
      repositoryRoot: values['--repository-root']!,
      alignmentReviewPath: values['--alignment-review'],
      replaceEvaluationArtifacts: replaceValue == 'true',
    );
  }

  final String observationsPath;
  final String groundTruthPath;
  final String outputDirectory;
  final String repositoryRoot;
  final String? alignmentReviewPath;
  final bool replaceEvaluationArtifacts;
}
