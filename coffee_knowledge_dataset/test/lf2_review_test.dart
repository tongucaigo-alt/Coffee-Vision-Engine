import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/local_formation_evidence_review_server.dart';
import '../tool/local_formation_feasibility_evaluator.dart';
import '../tool/src/lf2_review.dart';

void main() {
  group('LF-2 review and evaluation', () {
    test('imports corrected LF-1 ground truth without LF-1 alignments', () {
      final observations = _observations();
      final groundTruth = const Lf2GroundTruthCodec().parse(
        source: _groundTruthSource(),
        observations: observations,
      );

      expect(groundTruth.sourceResearchId, 'lfr-001');
      expect(groundTruth.annotations, hasLength(11));
      expect(
        groundTruth.annotations
            .where(
              (value) => value.polarity == Lf2GroundTruthPolarity.negativeSpace,
            )
            .length,
        5,
      );
      expect(
        groundTruth.annotation('lf1-ann-008').polarity,
        Lf2GroundTruthPolarity.negativeSpace,
      );
    });

    test(
      'creates one explicit unrelated status per candidate and annotation',
      () {
        final observations = _observations();
        final groundTruth = _groundTruth(observations);
        final review = const Lf2AlignmentCodec().createDefault(
          observations: observations,
          groundTruth: groundTruth,
        );

        expect(review.alignments, hasLength(22));
        expect(
          review.alignments.every(
            (value) => value.status == Lf2AlignmentStatus.unrelated,
          ),
          isTrue,
        );
        expect(
          () => review.alignments.add(review.alignments.first),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'rejects missing alignment, polarity mismatch, and full-content match',
      () {
        final observations = _observations(fullContentResidue: true);
        final groundTruth = _groundTruth(observations);
        final defaults = const Lf2AlignmentCodec().createDefault(
          observations: observations,
          groundTruth: groundTruth,
        );
        final missing = defaults.toJson();
        (missing['alignments']! as List<Object?>).removeLast();
        expect(
          () => const Lf2AlignmentCodec().parse(
            source: jsonEncode(missing),
            observations: observations,
            groundTruth: groundTruth,
          ),
          throwsFormatException,
        );

        final mismatch = defaults.toJson();
        final mismatchItems = mismatch['alignments']! as List<Object?>;
        final negativeAnnotationResidueCandidate = mismatchItems
            .cast<Map<String, Object?>>()
            .firstWhere(
              (value) =>
                  value['annotationId'] == 'lf1-ann-006' &&
                  value['candidateId'] == 1,
            );
        negativeAnnotationResidueCandidate['status'] = 'aligned';
        expect(
          () => const Lf2AlignmentCodec().parse(
            source: jsonEncode(mismatch),
            observations: observations,
            groundTruth: groundTruth,
          ),
          throwsFormatException,
        );

        final fullContent = defaults.toJson();
        final fullItems = fullContent['alignments']! as List<Object?>;
        fullItems.cast<Map<String, Object?>>().firstWhere(
          (value) =>
              value['annotationId'] == 'lf1-ann-001' &&
              value['candidateId'] == 1,
        )['status'] = 'aligned';
        expect(
          () => const Lf2AlignmentCodec().parse(
            source: jsonEncode(fullContent),
            observations: observations,
            groundTruth: groundTruth,
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'requires separate residue and negative coverage and ignores mixed',
      () {
        final observations = _observations();
        final groundTruth = _groundTruth(observations);
        final review = _alignedReview(observations, groundTruth);
        final evaluation = const Lf2Evaluator().evaluate(
          observations: observations,
          groundTruth: groundTruth,
          review: review,
        );

        expect(evaluation.groundTruthSufficient, isTrue);
        expect(evaluation.includedPrimaryAnnotationCount, 10);
        expect(evaluation.mixedDiagnosticAnnotationCount, 1);
        expect(evaluation.profiles.single.residueCoverageRate, 1);
        expect(evaluation.profiles.single.negativeSpaceCoverageRate, 1);
        expect(evaluation.profiles.single.mixedDiagnosticCoverageRate, 0);
        expect(evaluation.profiles.single.mathematicallyEliminated, isFalse);
        expect(evaluation.profiles.single.passed, isTrue);
        expect(evaluation.productionProfileCandidateId, 'lf2-p00-r04-a0005');
      },
    );

    test(
      'fails when residue conservation or candidate budget is incomplete',
      () {
        final observations = _observations(
          conserved: false,
          candidateBudget: 1,
        );
        final groundTruth = _groundTruth(observations);
        final evaluation = const Lf2Evaluator().evaluate(
          observations: observations,
          groundTruth: groundTruth,
          review: _alignedReview(observations, groundTruth),
        );

        expect(evaluation.profiles.single.residuePixelsConserved, isFalse);
        expect(evaluation.profiles.single.candidateBudgetRate, 0.5);
        expect(evaluation.profiles.single.passed, isFalse);
        expect(evaluation.profiles.single.mathematicallyEliminated, isTrue);
        expect(evaluation.productionProfileCandidateId, isNull);
      },
    );

    test(
      'maps working candidates into source coordinates deterministically',
      () {
        const candidate = Lf2ReviewCandidate(
          candidateId: 1,
          polarity: Lf2GroundTruthPolarity.residue,
          left: 0.25,
          top: 0.2,
          right: 0.75,
          bottom: 0.8,
          pixelCount: 10,
          areaRatio: 0.1,
          supportIdentity: 'test#source#support#1',
        );
        const content = Lf2NormalizedRect(
          left: 0.25,
          top: 0,
          right: 0.75,
          bottom: 1,
        );

        final mapped = candidate.toJson(contentRect: content);
        expect(mapped['left'], 0);
        expect(mapped['right'], 1);
        expect(mapped['top'], 0.2);
        expect(mapped['bottom'], 0.8);
      },
    );

    test('writes review artifacts only outside the repository', () async {
      final observations = _observations();
      final groundTruth = _groundTruth(observations);
      final review = _alignedReview(observations, groundTruth);
      final evaluation = const Lf2Evaluator().evaluate(
        observations: observations,
        groundTruth: groundTruth,
        review: review,
      );
      final temporary = await Directory.systemTemp.createTemp(
        'atlas-lf2-review-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final output = '${temporary.path}${Platform.pathSeparator}lfr-002';
      await const Lf2ReviewWriter().write(
        outputDirectory: output,
        repositoryRoot: Directory.current.parent.path,
        review: review,
        evaluation: evaluation,
      );

      expect(
        File(
          '$output${Platform.pathSeparator}candidate_alignment_review.json',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$output${Platform.pathSeparator}profile_evaluation.json',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$output${Platform.pathSeparator}profile_evaluation.csv',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$output${Platform.pathSeparator}research_summary.md',
        ).existsSync(),
        isTrue,
      );
      await expectLater(
        const Lf2ReviewWriter().write(
          outputDirectory: Directory.current.parent.path,
          repositoryRoot: Directory.current.parent.path,
          review: review,
          evaluation: evaluation,
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
      'writes conclusive feasibility without fabricating review decisions',
      () async {
        final observations = _observations(candidateBudget: 0);
        final groundTruth = _groundTruth(observations);
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
        final temporary = await Directory.systemTemp.createTemp(
          'atlas-lf2-feasibility-',
        );
        addTearDown(() => temporary.delete(recursive: true));
        final output = '${temporary.path}${Platform.pathSeparator}lfr-002';
        await const Lf2ReviewWriter().writeFeasibility(
          outputDirectory: output,
          repositoryRoot: Directory.current.parent.path,
          evaluation: evaluation,
        );

        expect(
          evaluation.evaluationBasis,
          Lf2EvaluationBasis.deterministicUpperBound,
        );
        expect(evaluation.allProfilesEliminatedByUpperBound, isTrue);
        expect(
          File(
            '$output${Platform.pathSeparator}candidate_alignment_review.json',
          ).existsSync(),
          isFalse,
        );
        expect(
          File(
            '$output${Platform.pathSeparator}profile_evaluation.json',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('review server is loopback-only and defaults to port 8767', () {
      final options = Lf2ReviewServerOptions.parse(const [
        '--dataset',
        'dataset',
        '--manifest',
        'manifest',
        '--freeze',
        'freeze',
        '--observations',
        'observations',
        '--ground-truth',
        'ground-truth',
        '--output',
        'output',
        '--repository-root',
        'repository',
      ]);
      expect(options.host, '127.0.0.1');
      expect(options.port, 8767);
      expect(
        () => Lf2ReviewServerOptions.parse(const [
          '--dataset',
          'dataset',
          '--manifest',
          'manifest',
          '--freeze',
          'freeze',
          '--observations',
          'observations',
          '--ground-truth',
          'ground-truth',
          '--output',
          'output',
          '--repository-root',
          'repository',
          '--host',
          '0.0.0.0',
        ]),
        throwsFormatException,
      );
      final feasibility = Lf2FeasibilityOptions.parse(const [
        '--observations',
        'observations',
        '--ground-truth',
        'ground-truth',
        '--output',
        'output',
        '--repository-root',
        'repository',
      ]);
      expect(feasibility.outputDirectory, 'output');
    });

    test('review UI links candidate rows and canvas boxes bidirectionally', () {
      final source = File(
        'tool/local_formation_evidence_review_server.dart',
      ).readAsStringSync();

      expect(source, contains('selectedCandidateId'));
      expect(source, contains('hoveredCandidateId'));
      expect(source, contains('data-candidate-id'));
      expect(source, contains("canvas.addEventListener('mousemove'"));
      expect(source, contains("canvas.addEventListener('click'"));
      expect(source, contains('candidateAtCanvasPoint'));
      expect(source, contains('scrollIntoView'));
      expect(source, contains("classList.toggle('selected'"));
      expect(source, contains("classList.toggle('hovered'"));
      expect(source, contains('.candidate.selected'));
      expect(source, contains('.swatch.truth'));
    });

    test(
      'research sources use public Vision evidence without downstream engines',
      () {
        final sources = [
          'tool/src/lf2_morphology.dart',
          'tool/src/lf2_runner.dart',
          'tool/src/lf2_report.dart',
          'tool/src/lf2_review.dart',
          'tool/local_formation_evidence_runner.dart',
          'tool/local_formation_evidence_review_server.dart',
          'tool/local_formation_feasibility_evaluator.dart',
        ].map((path) => File(path).readAsStringSync()).join('\n');

        expect(sources, contains("package:coffee_vision/coffee_vision.dart"));
        expect(sources, isNot(contains('package:coffee_vision/src/')));
        expect(sources, isNot(contains('package:coffee_pattern/')));
        expect(sources, isNot(contains('PatternEngine')));
        expect(sources, isNot(contains('analyzePatterns')));
        expect(sources, isNot(contains('KnowledgeRecord')));
        expect(sources, isNot(contains('SymbolCandidate')));
        expect(sources, isNot(contains('confidence')));
        expect(sources, isNot(contains('ranking')));
      },
    );
  });
}

Lf2ObservationIndex _observations({
  bool conserved = true,
  int candidateBudget = 2,
  bool fullContentResidue = false,
}) {
  final sources = ['source-a', 'source-b'];
  return Lf2ObservationIndex.parse(
    jsonEncode({
      'schemaVersion': '1.0',
      'researchId': 'lfr-002',
      'sourceDatasetVersion': 'test-dataset',
      'sourceManifestChecksum': 'sha256:test',
      'workingResolution': 10,
      'repeatCount': 3,
      'profiles': [
        {
          'profileId': 'lf2-p00-r04-a0005',
          'closingRadius': 4,
          'minimumRegionRatio': 0.0005,
        },
      ],
      'profileSummaries': [
        {
          'profileId': 'lf2-p00-r04-a0005',
          'enabledImageCount': 2,
          'successfulImageCount': 2,
          'failedImageCount': 0,
          'deterministicImageCount': 2,
          'nonDeterministicImageCount': 0,
          'candidateBudgetImageCount': candidateBudget,
          'candidateBudgetRate': candidateBudget / 2,
          'conservedImageCount': conserved ? 2 : 1,
          'totalCandidateCount': 4,
        },
      ],
      'observations': [
        for (final source in sources)
          {
            'profileId': 'lf2-p00-r04-a0005',
            'sourceId': source,
            'surfaceType': 'cup',
            'analysisStatus': 'success',
            'determinismStatus': 'deterministic',
            'repeatsPerformed': 3,
            'mismatchedRepeatIndexes': <int>[],
            'failureCategory': null,
            'contentBounds': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.9,
              'bottom': 0.9,
            },
            'residueConservation': {
              'originalResiduePixelCount': 10,
              'assignedResiduePixelCount': 10,
              'emittedResiduePixelCount': 10,
              'suppressedResiduePixelCount': 0,
              'duplicateResidueAssignmentCount': 0,
              'conserved': conserved,
            },
            'candidates': [
              _candidate(
                1,
                'residue',
                fullContentResidue ? 0.1 : 0.15,
                fullContentResidue ? 0.1 : 0.15,
                fullContentResidue ? 0.9 : 0.45,
                fullContentResidue ? 0.9 : 0.45,
              ),
              _candidate(2, 'negativeSpace', 0.5, 0.5, 0.8, 0.8),
            ],
          },
      ],
    }),
  );
}

Map<String, Object> _candidate(
  int id,
  String polarity,
  double left,
  double top,
  double right,
  double bottom,
) => {
  'candidateId': id,
  'candidateIdentity': 'profile#source#$polarity#$id',
  'polarity': polarity,
  'supportIdentity': 'profile#source#support#$id',
  'minimumRowMajorPixelIndex': id,
  'left': left,
  'top': top,
  'right': right,
  'bottom': bottom,
  'centroidX': (left + right) / 2,
  'centroidY': (top + bottom) / 2,
  'pixelCount': 10,
  'areaRatio': 0.1,
  'residueContactSectorCount': polarity == 'negativeSpace' ? 2 : 0,
  'pixelFingerprint': '000000000000000$id',
};

Lf2GroundTruthSet _groundTruth(Lf2ObservationIndex observations) =>
    const Lf2GroundTruthCodec().parse(
      source: _groundTruthSource(),
      observations: observations,
    );

String _groundTruthSource() {
  final annotations = <Map<String, Object?>>[];
  for (var index = 1; index <= 11; index++) {
    final source = index.isOdd ? 'source-a' : 'source-b';
    final polarity = index <= 5
        ? 'residue'
        : index <= 10
        ? 'negativeSpace'
        : 'mixed';
    final negative = polarity == 'negativeSpace';
    annotations.add({
      'annotationId': 'lf1-ann-${index.toString().padLeft(3, '0')}',
      'sourceId': source,
      'left': negative ? 0.5 : 0.1,
      'top': negative ? 0.5 : 0.1,
      'right': negative ? 0.8 : 0.4,
      'bottom': negative ? 0.8 : 0.4,
      'polarity': index == 8 ? 'negativeSpace' : polarity,
      'reviewStatus': 'include',
      'formationGroupId': index <= 10 ? 'formation-group-001' : null,
      'notes': index == 8 ? 'negative-space observation' : '',
      'alignments': <Object?>[],
    });
  }
  return jsonEncode({
    'schemaVersion': '1.0',
    'researchId': 'lfr-001',
    'annotations': annotations,
  });
}

Lf2AlignmentReview _alignedReview(
  Lf2ObservationIndex observations,
  Lf2GroundTruthSet groundTruth,
) {
  final defaults = const Lf2AlignmentCodec().createDefault(
    observations: observations,
    groundTruth: groundTruth,
  );
  final root = defaults.toJson();
  for (final value
      in (root['alignments']! as List<Object?>).cast<Map<String, Object?>>()) {
    final annotation = groundTruth.annotation(value['annotationId']! as String);
    if (annotation.polarity == Lf2GroundTruthPolarity.residue &&
        value['candidateId'] == 1) {
      value['status'] = 'aligned';
    }
    if (annotation.polarity == Lf2GroundTruthPolarity.negativeSpace &&
        value['candidateId'] == 2) {
      value['status'] = 'aligned';
    }
  }
  return const Lf2AlignmentCodec().parse(
    source: jsonEncode(root),
    observations: observations,
    groundTruth: groundTruth,
  );
}
