import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/lf2_review.dart';
import '../tool/src/lf3_review.dart';

void main() {
  group('LF-3 feasibility review', () {
    test('eliminates impossible profiles without fabricated alignment', () {
      final bundle = const Lf3FeasibilityEvaluator().evaluate(
        observationSource: _observationReport(withCandidates: false),
        groundTruthSource: _groundTruth(),
      );

      expect(bundle.evaluation.evaluationBasis.name, 'deterministicUpperBound');
      expect(bundle.evaluation.residueAnnotationCount, 5);
      expect(bundle.evaluation.negativeSpaceAnnotationCount, 5);
      expect(bundle.evaluation.mixedDiagnosticAnnotationCount, 1);
      expect(bundle.evaluation.allProfilesEliminatedByUpperBound, isTrue);
      expect(bundle.requiresHumanReview, isFalse);
      expect(
        bundle.evaluation.profiles.single.maximumPossibleAnnotationCoverageRate,
        0,
      );
    });

    test(
      'keeps mixed annotations diagnostic and reports surfaces separately',
      () {
        final bundle = const Lf3FeasibilityEvaluator().evaluate(
          observationSource: _observationReport(withCandidates: true),
          groundTruthSource: _groundTruth(),
        );

        expect(bundle.evaluation.includedPrimaryAnnotationCount, 10);
        expect(bundle.evaluation.mixedDiagnosticAnnotationCount, 1);
        expect(bundle.surfaceUpperBounds, hasLength(2));
        final cup = bundle.surfaceUpperBounds.singleWhere(
          (value) => value.surfaceType == 'cup',
        );
        final saucer = bundle.surfaceUpperBounds.singleWhere(
          (value) => value.surfaceType == 'saucer',
        );
        expect(cup.residueAnnotationCount, 5);
        expect(cup.negativeSpaceAnnotationCount, 0);
        expect(cup.maximumPossibleResidueCoverageRate, 1);
        expect(saucer.residueAnnotationCount, 0);
        expect(saucer.negativeSpaceAnnotationCount, 5);
        expect(saucer.maximumPossibleNegativeSpaceCoverageRate, 1);
        expect(bundle.requiresHumanReview, isTrue);
        expect(
          bundle.review.alignments.every(
            (value) => value.status.name == 'unrelated',
          ),
          isTrue,
        );
      },
    );

    test(
      'writes immutable feasibility artifacts outside the repository',
      () async {
        final root = await Directory.systemTemp.createTemp('atlas-lf3-review-');
        addTearDown(() => root.delete(recursive: true));
        final bundle = const Lf3FeasibilityEvaluator().evaluate(
          observationSource: _observationReport(withCandidates: false),
          groundTruthSource: _groundTruth(),
        );

        final paths = await const Lf3EvaluationWriter().write(
          outputDirectory: root.path,
          repositoryRoot: Directory.current.parent.path,
          bundle: bundle,
        );

        expect(paths, hasLength(3));
        expect(
          await File(paths[0]).readAsString(),
          contains('surfaceUpperBounds'),
        );
        expect(await File(paths[2]).readAsString(), contains('LF-3'));
        expect(
          File(
            '${root.path}${Platform.pathSeparator}candidate_alignment_review.json',
          ).existsSync(),
          isFalse,
        );
        await expectLater(
          const Lf3EvaluationWriter().write(
            outputDirectory: root.path,
            repositoryRoot: Directory.current.parent.path,
            bundle: bundle,
          ),
          throwsA(isA<FileSystemException>()),
        );
      },
    );

    test(
      'creates a neutral review file only when upper bound survives',
      () async {
        final root = await Directory.systemTemp.createTemp('atlas-lf3-review-');
        addTearDown(() => root.delete(recursive: true));
        final bundle = const Lf3FeasibilityEvaluator().evaluate(
          observationSource: _observationReport(withCandidates: true),
          groundTruthSource: _groundTruth(),
        );

        final paths = await const Lf3EvaluationWriter().write(
          outputDirectory: root.path,
          repositoryRoot: Directory.current.parent.path,
          bundle: bundle,
        );

        expect(paths, hasLength(4));
        final review = jsonDecode(await File(paths.last).readAsString());
        final alignments = (review as Map<String, Object?>)['alignments']!;
        expect(
          (alignments as List<Object?>).every(
            (value) => (value as Map<String, Object?>)['status'] == 'unrelated',
          ),
          isTrue,
        );
      },
    );

    test(
      'completed human review can replace only evaluation artifacts',
      () async {
        final root = await Directory.systemTemp.createTemp('atlas-lf3-final-');
        addTearDown(() => root.delete(recursive: true));
        final observations = _observationReport(withCandidates: true);
        final groundTruth = _groundTruth();
        final feasibility = const Lf3FeasibilityEvaluator().evaluate(
          observationSource: observations,
          groundTruthSource: groundTruth,
        );
        await const Lf3EvaluationWriter().write(
          outputDirectory: root.path,
          repositoryRoot: Directory.current.parent.path,
          bundle: feasibility,
        );
        final completed = const Lf3FeasibilityEvaluator().evaluate(
          observationSource: observations,
          groundTruthSource: groundTruth,
          alignmentReviewSource: const Lf2AlignmentCodec().encode(
            feasibility.review,
          ),
        );

        final paths = await const Lf3EvaluationWriter().write(
          outputDirectory: root.path,
          repositoryRoot: Directory.current.parent.path,
          bundle: completed,
          replaceEvaluationArtifacts: true,
        );

        expect(completed.alignmentReviewCompleted, isTrue);
        expect(completed.requiresHumanReview, isFalse);
        expect(paths, hasLength(3));
        expect(
          await File(paths[2]).readAsString(),
          contains('NO PROFILE PASSED HUMAN ALIGNMENT REVIEW'),
        );
        expect(
          File(
            '${root.path}${Platform.pathSeparator}candidate_alignment_review.json',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'LF-3 remains research-only and does not import downstream layers',
      () {
        final root = Directory.current.path;
        final sources = <String>[
          for (final path in [
            'tool/src/lf3_profiles.dart',
            'tool/src/lf3_models.dart',
            'tool/src/lf3_evidence.dart',
            'tool/src/lf3_runner.dart',
            'tool/src/lf3_report.dart',
            'tool/src/lf3_review.dart',
            'tool/local_formation_lf3_runner.dart',
            'tool/local_formation_lf3_feasibility_evaluator.dart',
            'tool/local_formation_lf3_review_server.dart',
          ])
            File('$root${Platform.pathSeparator}$path').readAsStringSync(),
        ].join('\n');

        expect(sources, isNot(contains('package:coffee_pattern/')));
        expect(sources, isNot(contains('package:coffee_knowledge/')));
        expect(sources, isNot(contains('package:coffee_symbol/')));
        expect(sources, isNot(contains('PatternEngine')));
        expect(sources, isNot(contains('KnowledgeRecord')));
        expect(sources, isNot(contains('SymbolDefinition')));
        expect(sources.toLowerCase(), isNot(contains('confidence')));
        expect(sources.toLowerCase(), isNot(contains('ranking')));
        expect(sources.toLowerCase(), isNot(contains('machine learning')));
        expect(sources, isNot(contains('package:coffee_vision/src/')));
      },
    );
  });
}

String _observationReport({required bool withCandidates}) {
  final observations = <Map<String, Object?>>[];
  for (final entry in const [('cup-001', 'cup'), ('saucer-001', 'saucer')]) {
    observations.add({
      'profileId': 'lf3-p00',
      'sourceId': entry.$1,
      'surfaceType': entry.$2,
      'analysisStatus': 'success',
      'determinismStatus': 'deterministic',
      'repeatsPerformed': 3,
      'mismatchedRepeatIndexes': <int>[],
      'failureCategory': null,
      'contentBounds': {'left': 0.0, 'top': 0.0, 'right': 1.0, 'bottom': 1.0},
      'residueConservation': {
        'originalResiduePixelCount': withCandidates ? 2 : 0,
        'assignedResiduePixelCount': withCandidates ? 2 : 0,
        'emittedResiduePixelCount': withCandidates ? 2 : 0,
        'suppressedResiduePixelCount': 0,
        'duplicateResidueAssignmentCount': 0,
        'conserved': true,
      },
      'candidates': withCandidates
          ? [
              _candidate(1, 'residue', 0.1, 0.1, 0.4, 0.4),
              _candidate(2, 'negativeSpace', 0.6, 0.6, 0.9, 0.9),
            ]
          : <Object>[],
    });
  }
  return jsonEncode({
    'schemaVersion': '1.0',
    'researchId': 'lfr-003',
    'sourceDatasetVersion': 'test',
    'sourceManifestChecksum': 'sha256:test',
    'workingResolution': 512,
    'repeatCount': 3,
    'profiles': [
      {'profileId': 'lf3-p00', 'closingRadius': 4, 'minimumRegionRatio': 0.002},
    ],
    'profileSummaries': [
      {
        'profileId': 'lf3-p00',
        'enabledImageCount': 2,
        'successfulImageCount': 2,
        'failedImageCount': 0,
        'deterministicImageCount': 2,
        'nonDeterministicImageCount': 0,
        'candidateBudgetImageCount': withCandidates ? 2 : 0,
        'candidateBudgetRate': withCandidates ? 1.0 : 0.0,
        'conservedImageCount': 2,
        'totalCandidateCount': withCandidates ? 4 : 0,
      },
    ],
    'observations': observations,
  });
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
  'polarity': polarity,
  'supportIdentity': 'lf3-p00#test#support#1',
  'left': left,
  'top': top,
  'right': right,
  'bottom': bottom,
  'pixelCount': 10,
  'areaRatio': 0.01,
};

String _groundTruth() {
  final annotations = <Map<String, Object?>>[];
  for (var index = 0; index < 5; index++) {
    annotations.add(
      _annotation('residue-$index', 'cup-001', 'residue', 0.12, 0.12, 0.3, 0.3),
    );
    annotations.add(
      _annotation(
        'negative-$index',
        'saucer-001',
        'negativeSpace',
        0.65,
        0.65,
        0.85,
        0.85,
      ),
    );
  }
  annotations.add(
    _annotation('mixed-0', 'cup-001', 'mixed', 0.45, 0.45, 0.55, 0.55),
  );
  return jsonEncode({
    'schemaVersion': '1.0',
    'researchId': 'lfr-001',
    'annotations': annotations,
  });
}

Map<String, Object?> _annotation(
  String id,
  String sourceId,
  String polarity,
  double left,
  double top,
  double right,
  double bottom,
) => {
  'annotationId': id,
  'sourceId': sourceId,
  'left': left,
  'top': top,
  'right': right,
  'bottom': bottom,
  'polarity': polarity,
  'reviewStatus': 'include',
  'formationGroupId': null,
  'notes': '',
  'alignments': <Object>[],
};
