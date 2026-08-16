import 'dart:convert';
import 'dart:io';

import 'lf2_review.dart';

final class Lf3SurfaceUpperBound {
  const Lf3SurfaceUpperBound({
    required this.profileId,
    required this.surfaceType,
    required this.primaryAnnotationCount,
    required this.residueAnnotationCount,
    required this.negativeSpaceAnnotationCount,
    required this.maximumPossibleAnnotationCoverageRate,
    required this.maximumPossibleResidueCoverageRate,
    required this.maximumPossibleNegativeSpaceCoverageRate,
    required this.annotationCoverageRate,
    required this.residueCoverageRate,
    required this.negativeSpaceCoverageRate,
  });

  final String profileId;
  final String surfaceType;
  final int primaryAnnotationCount;
  final int residueAnnotationCount;
  final int negativeSpaceAnnotationCount;
  final double maximumPossibleAnnotationCoverageRate;
  final double maximumPossibleResidueCoverageRate;
  final double maximumPossibleNegativeSpaceCoverageRate;
  final double annotationCoverageRate;
  final double residueCoverageRate;
  final double negativeSpaceCoverageRate;

  Map<String, Object> toJson() => {
    'profileId': profileId,
    'surfaceType': surfaceType,
    'primaryAnnotationCount': primaryAnnotationCount,
    'residueAnnotationCount': residueAnnotationCount,
    'negativeSpaceAnnotationCount': negativeSpaceAnnotationCount,
    'maximumPossibleAnnotationCoverageRate':
        maximumPossibleAnnotationCoverageRate,
    'maximumPossibleResidueCoverageRate': maximumPossibleResidueCoverageRate,
    'maximumPossibleNegativeSpaceCoverageRate':
        maximumPossibleNegativeSpaceCoverageRate,
    'annotationCoverageRate': annotationCoverageRate,
    'residueCoverageRate': residueCoverageRate,
    'negativeSpaceCoverageRate': negativeSpaceCoverageRate,
  };
}

final class Lf3EvaluationBundle {
  Lf3EvaluationBundle({
    required this.evaluation,
    required this.review,
    required this.alignmentReviewCompleted,
    required Iterable<Lf3SurfaceUpperBound> surfaceUpperBounds,
  }) : surfaceUpperBounds = List<Lf3SurfaceUpperBound>.unmodifiable(
         surfaceUpperBounds,
       );

  final Lf2EvaluationReport evaluation;
  final Lf2AlignmentReview review;
  final bool alignmentReviewCompleted;
  final List<Lf3SurfaceUpperBound> surfaceUpperBounds;

  bool get requiresHumanReview =>
      !alignmentReviewCompleted &&
      !evaluation.allProfilesEliminatedByUpperBound;
}

final class Lf3FeasibilityEvaluator {
  const Lf3FeasibilityEvaluator();

  Lf3EvaluationBundle evaluate({
    required String observationSource,
    required String groundTruthSource,
    String? alignmentReviewSource,
  }) {
    final observations = Lf2ObservationIndex.parse(observationSource);
    final groundTruth = const Lf2GroundTruthCodec().parse(
      source: groundTruthSource,
      observations: observations,
    );
    final review = alignmentReviewSource == null
        ? const Lf2AlignmentCodec().createDefault(
            observations: observations,
            groundTruth: groundTruth,
          )
        : const Lf2AlignmentCodec().parse(
            source: alignmentReviewSource,
            observations: observations,
            groundTruth: groundTruth,
          );
    final alignmentReviewCompleted = alignmentReviewSource != null;
    final evaluation = const Lf2Evaluator().evaluate(
      observations: observations,
      groundTruth: groundTruth,
      review: review,
      alignmentReviewCompleted: alignmentReviewCompleted,
    );
    return Lf3EvaluationBundle(
      evaluation: evaluation,
      review: review,
      alignmentReviewCompleted: alignmentReviewCompleted,
      surfaceUpperBounds: _surfaceUpperBounds(
        observationSource: observationSource,
        observations: observations,
        groundTruth: groundTruth,
        review: review,
        alignmentReviewCompleted: alignmentReviewCompleted,
      ),
    );
  }

  static List<Lf3SurfaceUpperBound> _surfaceUpperBounds({
    required String observationSource,
    required Lf2ObservationIndex observations,
    required Lf2GroundTruthSet groundTruth,
    required Lf2AlignmentReview review,
    required bool alignmentReviewCompleted,
  }) {
    final root = jsonDecode(observationSource);
    if (root is! Map<String, Object?>) {
      throw const FormatException('LF-3 observation report is malformed.');
    }
    final values = root['observations'];
    if (values is! List<Object?>) {
      throw const FormatException('LF-3 observations must be an array.');
    }
    final surfaceBySource = <String, String>{};
    for (final value in values) {
      if (value is! Map<String, Object?>) {
        throw const FormatException('LF-3 observation must be an object.');
      }
      final sourceId = value['sourceId'];
      final surfaceType = value['surfaceType'];
      if (sourceId is! String ||
          surfaceType is! String ||
          (surfaceType != 'cup' && surfaceType != 'saucer')) {
        throw const FormatException('LF-3 surface evidence is invalid.');
      }
      final previous = surfaceBySource[sourceId];
      if (previous != null && previous != surfaceType) {
        throw FormatException('LF-3 source surface changed: $sourceId.');
      }
      surfaceBySource[sourceId] = surfaceType;
    }

    final included = groundTruth.annotations
        .where(
          (annotation) =>
              annotation.reviewStatus == Lf2GroundTruthStatus.include &&
              annotation.polarity != Lf2GroundTruthPolarity.mixed,
        )
        .toList(growable: false);
    final result = <Lf3SurfaceUpperBound>[];
    for (final profileId in observations.profileIds) {
      for (final surfaceType in const ['cup', 'saucer']) {
        final primary = included
            .where(
              (annotation) =>
                  surfaceBySource[annotation.sourceId] == surfaceType,
            )
            .toList(growable: false);
        final residue = primary
            .where(
              (annotation) =>
                  annotation.polarity == Lf2GroundTruthPolarity.residue,
            )
            .toList(growable: false);
        final negative = primary
            .where(
              (annotation) =>
                  annotation.polarity == Lf2GroundTruthPolarity.negativeSpace,
            )
            .toList(growable: false);
        result.add(
          Lf3SurfaceUpperBound(
            profileId: profileId,
            surfaceType: surfaceType,
            primaryAnnotationCount: primary.length,
            residueAnnotationCount: residue.length,
            negativeSpaceAnnotationCount: negative.length,
            maximumPossibleAnnotationCoverageRate: _maximumPossibleCoverage(
              primary,
              profileId,
              observations,
            ),
            maximumPossibleResidueCoverageRate: _maximumPossibleCoverage(
              residue,
              profileId,
              observations,
            ),
            maximumPossibleNegativeSpaceCoverageRate: _maximumPossibleCoverage(
              negative,
              profileId,
              observations,
            ),
            annotationCoverageRate: alignmentReviewCompleted
                ? _coverage(primary, profileId, review)
                : 0.0,
            residueCoverageRate: alignmentReviewCompleted
                ? _coverage(residue, profileId, review)
                : 0.0,
            negativeSpaceCoverageRate: alignmentReviewCompleted
                ? _coverage(negative, profileId, review)
                : 0.0,
          ),
        );
      }
    }
    return result;
  }

  static double _maximumPossibleCoverage(
    List<Lf2GroundTruthAnnotation> annotations,
    String profileId,
    Lf2ObservationIndex observations,
  ) {
    if (annotations.isEmpty) return 0.0;
    var possible = 0;
    for (final annotation in annotations) {
      final observation = observations.observation(
        profileId,
        annotation.sourceId,
      );
      final contentRect = observation.contentRect;
      if (contentRect == null) continue;
      if (observation.candidates.any((candidate) {
        if (candidate.polarity != annotation.polarity ||
            candidate.fillsContent(contentRect)) {
          return false;
        }
        return _intersects(
          annotation.rect,
          _candidateSourceRect(candidate, contentRect),
        );
      })) {
        possible++;
      }
    }
    return possible / annotations.length;
  }

  static double _coverage(
    List<Lf2GroundTruthAnnotation> annotations,
    String profileId,
    Lf2AlignmentReview review,
  ) {
    if (annotations.isEmpty) return 0.0;
    return annotations
            .where(
              (annotation) => review.alignments.any(
                (alignment) =>
                    alignment.annotationId == annotation.annotationId &&
                    alignment.profileId == profileId &&
                    alignment.status == Lf2AlignmentStatus.aligned,
              ),
            )
            .length /
        annotations.length;
  }

  static Lf2NormalizedRect _candidateSourceRect(
    Lf2ReviewCandidate candidate,
    Lf2NormalizedRect contentRect,
  ) => Lf2NormalizedRect(
    left: _mapToSource(candidate.left, contentRect.left, contentRect.right),
    top: _mapToSource(candidate.top, contentRect.top, contentRect.bottom),
    right: _mapToSource(candidate.right, contentRect.left, contentRect.right),
    bottom: _mapToSource(candidate.bottom, contentRect.top, contentRect.bottom),
  );

  static double _mapToSource(double value, double minimum, double maximum) =>
      ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0);

  static bool _intersects(Lf2NormalizedRect first, Lf2NormalizedRect second) =>
      first.left < second.right &&
      first.right > second.left &&
      first.top < second.bottom &&
      first.bottom > second.top;
}

final class Lf3EvaluationWriter {
  const Lf3EvaluationWriter();

  Future<List<String>> write({
    required String outputDirectory,
    required String repositoryRoot,
    required Lf3EvaluationBundle bundle,
    bool replaceEvaluationArtifacts = false,
  }) async {
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    final paths = <String>[
      _join(outputDirectory, 'profile_evaluation.json'),
      _join(outputDirectory, 'profile_evaluation.csv'),
      _join(outputDirectory, 'research_summary.md'),
      if (bundle.requiresHumanReview)
        _join(outputDirectory, 'candidate_alignment_review.json'),
    ];
    if (replaceEvaluationArtifacts && !bundle.alignmentReviewCompleted) {
      throw ArgumentError.value(
        bundle,
        'bundle',
        'replacement requires a completed human alignment review',
      );
    }
    if ((!replaceEvaluationArtifacts &&
            paths.take(3).any((path) => File(path).existsSync())) ||
        (bundle.requiresHumanReview && File(paths.last).existsSync())) {
      throw const FileSystemException(
        'LF-3 evaluation outputs already exist; research is immutable.',
      );
    }
    try {
      await Directory(outputDirectory).create(recursive: true);
      final evaluationJson = Map<String, Object?>.of(bundle.evaluation.toJson())
        ..['surfaceUpperBounds'] = bundle.surfaceUpperBounds
            .map((value) => value.toJson())
            .toList(growable: false);
      await File(paths[0]).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(evaluationJson)}\n',
        flush: true,
      );
      await File(paths[1]).writeAsString(_evaluationCsv(bundle), flush: true);
      await File(paths[2]).writeAsString(_summary(bundle), flush: true);
      if (bundle.requiresHumanReview) {
        await File(paths[3]).writeAsString(
          const Lf2AlignmentCodec().encode(bundle.review),
          flush: true,
        );
      }
    } on FileSystemException {
      throw const FileSystemException(
        'LF-3 evaluation outputs could not be written.',
      );
    }
    return List<String>.unmodifiable(paths);
  }

  static String _evaluationCsv(Lf3EvaluationBundle bundle) {
    final rows = <String>[
      'profileId,deterministicAndComplete,residuePixelsConserved,'
          'candidateBudgetRate,annotationCoverageRate,residueCoverageRate,'
          'negativeSpaceCoverageRate,formationConsistencyRate,'
          'mixedDiagnosticCoverageRate,maximumPossibleAnnotationCoverageRate,'
          'maximumPossibleResidueCoverageRate,'
          'maximumPossibleNegativeSpaceCoverageRate,'
          'mathematicallyEliminated,medianCandidateCount,passed',
      for (final profile in bundle.evaluation.profiles)
        '${profile.profileId},${profile.deterministicAndComplete},'
            '${profile.residuePixelsConserved},${profile.candidateBudgetRate},'
            '${profile.annotationCoverageRate},${profile.residueCoverageRate},'
            '${profile.negativeSpaceCoverageRate},'
            '${profile.formationConsistencyRate},'
            '${profile.mixedDiagnosticCoverageRate},'
            '${profile.maximumPossibleAnnotationCoverageRate},'
            '${profile.maximumPossibleResidueCoverageRate},'
            '${profile.maximumPossibleNegativeSpaceCoverageRate},'
            '${profile.mathematicallyEliminated},'
            '${profile.medianCandidateCount},${profile.passed}',
      '',
      'profileId,surfaceType,primaryAnnotationCount,residueAnnotationCount,'
          'negativeSpaceAnnotationCount,maximumPossibleAnnotationCoverageRate,'
          'maximumPossibleResidueCoverageRate,'
          'maximumPossibleNegativeSpaceCoverageRate,annotationCoverageRate,'
          'residueCoverageRate,negativeSpaceCoverageRate',
      for (final value in bundle.surfaceUpperBounds)
        '${value.profileId},${value.surfaceType},'
            '${value.primaryAnnotationCount},${value.residueAnnotationCount},'
            '${value.negativeSpaceAnnotationCount},'
            '${value.maximumPossibleAnnotationCoverageRate},'
            '${value.maximumPossibleResidueCoverageRate},'
            '${value.maximumPossibleNegativeSpaceCoverageRate},'
            '${value.annotationCoverageRate},${value.residueCoverageRate},'
            '${value.negativeSpaceCoverageRate}',
    ];
    return '${rows.join('\r\n')}\r\n';
  }

  static String _summary(Lf3EvaluationBundle bundle) {
    final report = bundle.evaluation;
    final verdict = bundle.alignmentReviewCompleted
        ? report.productionProfileCandidateId == null
              ? 'NO PROFILE PASSED HUMAN ALIGNMENT REVIEW'
              : 'RESEARCH CANDIDATE: `${report.productionProfileCandidateId}`'
        : report.allProfilesEliminatedByUpperBound
        ? 'ALL PROFILES ELIMINATED BY DETERMINISTIC UPPER BOUND'
        : 'HUMAN ALIGNMENT REVIEW REQUIRED';
    return '''
# Atlas LF-3 Vision-Native Local Formation Evidence Research

- Research ID: `${report.researchId}`
- Ground truth sufficient: `${report.groundTruthSufficient}`
- Included primary annotations: `${report.includedPrimaryAnnotationCount}`
- Residue annotations: `${report.residueAnnotationCount}`
- Negative-space annotations: `${report.negativeSpaceAnnotationCount}`
- Mixed diagnostic annotations: `${report.mixedDiagnosticAnnotationCount}`
- Eligible formation groups: `${report.eligibleFormationGroupCount}`
- Evaluation basis: `${report.evaluationBasis.name}`
- All profiles eliminated by deterministic upper bound: `${report.allProfilesEliminatedByUpperBound}`
- Result: $verdict

Mixed annotations are diagnostic only. The deterministic upper-bound stage
does not fabricate human alignment decisions. Cup and saucer upper bounds and
completed human-review coverage are reported separately in the evaluation
JSON and CSV. A surviving profile is only a research candidate; it is not a
frozen Vision change, semantic identity, production profile, or evidence
binding.
''';
  }

  static void _rejectRepositoryOutput(String output, String repositoryRoot) {
    final outputPath = Directory(output).absolute.path.toLowerCase();
    final repositoryPath = Directory(
      repositoryRoot,
    ).absolute.path.toLowerCase();
    final prefix = repositoryPath.endsWith(Platform.pathSeparator)
        ? repositoryPath
        : '$repositoryPath${Platform.pathSeparator}';
    if (outputPath == repositoryPath || outputPath.startsWith(prefix)) {
      throw const FileSystemException(
        'LF-3 research output must remain outside the repository.',
      );
    }
  }

  static String _join(String directory, String filename) =>
      [directory, filename].join(Platform.pathSeparator);
}
