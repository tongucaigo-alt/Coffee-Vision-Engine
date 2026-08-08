import 'dart:convert';
import 'dart:io';

enum Lf2GroundTruthPolarity { residue, negativeSpace, mixed }

enum Lf2GroundTruthStatus { include, uncertain, exclude }

enum Lf2AlignmentStatus { aligned, partial, unrelated }

enum Lf2EvaluationBasis { humanAlignmentReview, deterministicUpperBound }

final class Lf2ReviewCandidate {
  const Lf2ReviewCandidate({
    required this.candidateId,
    required this.polarity,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.pixelCount,
    required this.areaRatio,
    required this.supportIdentity,
  });

  final int candidateId;
  final Lf2GroundTruthPolarity polarity;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int pixelCount;
  final double areaRatio;
  final String supportIdentity;

  Map<String, Object> toJson({required Lf2NormalizedRect contentRect}) {
    final source = Lf2NormalizedRect(
      left: _mapToSource(left, contentRect.left, contentRect.right),
      top: _mapToSource(top, contentRect.top, contentRect.bottom),
      right: _mapToSource(right, contentRect.left, contentRect.right),
      bottom: _mapToSource(bottom, contentRect.top, contentRect.bottom),
    );
    return {
      'candidateId': candidateId,
      'polarity': polarity.name,
      'left': source.left,
      'top': source.top,
      'right': source.right,
      'bottom': source.bottom,
      'pixelCount': pixelCount,
      'areaRatio': areaRatio,
      'supportIdentity': supportIdentity,
    };
  }

  bool fillsContent(Lf2NormalizedRect contentRect) =>
      left <= contentRect.left &&
      top <= contentRect.top &&
      right >= contentRect.right &&
      bottom >= contentRect.bottom;
}

final class Lf2NormalizedRect {
  const Lf2NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

final class Lf2ReviewObservation {
  Lf2ReviewObservation({
    required this.profileId,
    required this.sourceId,
    required this.analysisStatus,
    required this.determinismStatus,
    required this.contentRect,
    required this.residuePixelsConserved,
    required Iterable<Lf2ReviewCandidate> candidates,
  }) : candidates = List<Lf2ReviewCandidate>.unmodifiable(candidates);

  final String profileId;
  final String sourceId;
  final String analysisStatus;
  final String determinismStatus;
  final Lf2NormalizedRect? contentRect;
  final bool residuePixelsConserved;
  final List<Lf2ReviewCandidate> candidates;
}

final class Lf2ReviewProfileSummary {
  const Lf2ReviewProfileSummary({
    required this.profileId,
    required this.enabledImageCount,
    required this.failedImageCount,
    required this.deterministicImageCount,
    required this.nonDeterministicImageCount,
    required this.candidateBudgetImageCount,
    required this.conservedImageCount,
  });

  final String profileId;
  final int enabledImageCount;
  final int failedImageCount;
  final int deterministicImageCount;
  final int nonDeterministicImageCount;
  final int candidateBudgetImageCount;
  final int conservedImageCount;

  double get candidateBudgetRate => enabledImageCount == 0
      ? 0.0
      : candidateBudgetImageCount / enabledImageCount;
}

final class Lf2ObservationIndex {
  Lf2ObservationIndex({
    required this.researchId,
    required Iterable<String> profileIds,
    required Iterable<Lf2ReviewProfileSummary> profileSummaries,
    required Iterable<Lf2ReviewObservation> observations,
  }) : profileIds = List<String>.unmodifiable(profileIds),
       profileSummaries = List<Lf2ReviewProfileSummary>.unmodifiable(
         profileSummaries,
       ),
       observations = List<Lf2ReviewObservation>.unmodifiable(observations) {
    _validate();
  }

  factory Lf2ObservationIndex.parse(String source) {
    final root = _decodeObject(source, 'LF-2 observation report');
    _exactFields(
      root,
      required: const {
        'schemaVersion',
        'researchId',
        'sourceDatasetVersion',
        'sourceManifestChecksum',
        'workingResolution',
        'repeatCount',
        'profiles',
        'profileSummaries',
        'observations',
      },
      field: 'root',
    );
    if (root['schemaVersion'] != '1.0') {
      throw const FormatException('Unsupported LF-2 report schema version.');
    }
    final profileIds = <String>[
      for (final value in _list(root['profiles'], 'profiles'))
        _identifier(_object(value, 'profiles[]')['profileId'], 'profileId'),
    ];
    final summaries = <Lf2ReviewProfileSummary>[
      for (final value in _list(root['profileSummaries'], 'profileSummaries'))
        _summary(_object(value, 'profileSummaries[]')),
    ];
    final observations = <Lf2ReviewObservation>[
      for (final value in _list(root['observations'], 'observations'))
        _observation(_object(value, 'observations[]')),
    ];
    return Lf2ObservationIndex(
      researchId: _identifier(root['researchId'], 'researchId'),
      profileIds: profileIds,
      profileSummaries: summaries,
      observations: observations,
    );
  }

  final String researchId;
  final List<String> profileIds;
  final List<Lf2ReviewProfileSummary> profileSummaries;
  final List<Lf2ReviewObservation> observations;

  Lf2ReviewObservation observation(String profileId, String sourceId) =>
      observations.singleWhere(
        (value) => value.profileId == profileId && value.sourceId == sourceId,
      );

  Lf2ReviewProfileSummary summary(String profileId) =>
      profileSummaries.singleWhere((value) => value.profileId == profileId);

  Lf2ReviewCandidate candidate(
    String profileId,
    String sourceId,
    int candidateId,
  ) => observation(
    profileId,
    sourceId,
  ).candidates.singleWhere((candidate) => candidate.candidateId == candidateId);

  bool containsSource(String sourceId) =>
      observations.any((value) => value.sourceId == sourceId);

  void _validate() {
    final canonicalProfiles = List<String>.of(profileIds)..sort();
    if (profileIds.isEmpty ||
        !_same(profileIds, canonicalProfiles) ||
        profileIds.toSet().length != profileIds.length) {
      throw const FormatException('LF-2 profile IDs must be canonical.');
    }
    if (profileSummaries.length != profileIds.length ||
        !_same(profileSummaries.map((value) => value.profileId), profileIds)) {
      throw const FormatException('LF-2 profile summaries are incomplete.');
    }
    final observationKeys = <String>{};
    for (final observation in observations) {
      final key = '${observation.profileId}\u0000${observation.sourceId}';
      if (!profileIds.contains(observation.profileId) ||
          !observationKeys.add(key)) {
        throw const FormatException('LF-2 observations are inconsistent.');
      }
      final ids = observation.candidates
          .map((candidate) => candidate.candidateId)
          .toList(growable: false);
      if (!_same(ids, [for (var id = 1; id <= ids.length; id++) id])) {
        throw const FormatException('LF-2 candidate IDs must be contiguous.');
      }
    }
  }

  static Lf2ReviewProfileSummary _summary(Map<String, Object?> value) {
    return Lf2ReviewProfileSummary(
      profileId: _identifier(value['profileId'], 'profileId'),
      enabledImageCount: _nonNegativeInt(
        value['enabledImageCount'],
        'enabledImageCount',
      ),
      failedImageCount: _nonNegativeInt(
        value['failedImageCount'],
        'failedImageCount',
      ),
      deterministicImageCount: _nonNegativeInt(
        value['deterministicImageCount'],
        'deterministicImageCount',
      ),
      nonDeterministicImageCount: _nonNegativeInt(
        value['nonDeterministicImageCount'],
        'nonDeterministicImageCount',
      ),
      candidateBudgetImageCount: _nonNegativeInt(
        value['candidateBudgetImageCount'],
        'candidateBudgetImageCount',
      ),
      conservedImageCount: _nonNegativeInt(
        value['conservedImageCount'],
        'conservedImageCount',
      ),
    );
  }

  static Lf2ReviewObservation _observation(Map<String, Object?> value) {
    final boundsValue = value['contentBounds'];
    final bounds = boundsValue == null
        ? null
        : _rect(_object(boundsValue, 'contentBounds'), 'contentBounds');
    final conservation = _object(
      value['residueConservation'],
      'residueConservation',
    );
    final candidates = <Lf2ReviewCandidate>[];
    for (final candidateValue in _list(value['candidates'], 'candidates')) {
      final candidate = _object(candidateValue, 'candidates[]');
      candidates.add(
        Lf2ReviewCandidate(
          candidateId: _positiveInt(candidate['candidateId'], 'candidateId'),
          polarity: _enumValue(
            Lf2GroundTruthPolarity.values.take(2).toList(),
            candidate['polarity'],
            'polarity',
          ),
          left: _coordinate(candidate['left'], 'left'),
          top: _coordinate(candidate['top'], 'top'),
          right: _coordinate(candidate['right'], 'right'),
          bottom: _coordinate(candidate['bottom'], 'bottom'),
          pixelCount: _positiveInt(candidate['pixelCount'], 'pixelCount'),
          areaRatio: _coordinate(candidate['areaRatio'], 'areaRatio'),
          supportIdentity: _identifier(
            candidate['supportIdentity'],
            'supportIdentity',
          ),
        ),
      );
    }
    return Lf2ReviewObservation(
      profileId: _identifier(value['profileId'], 'profileId'),
      sourceId: _identifier(value['sourceId'], 'sourceId'),
      analysisStatus: _string(value['analysisStatus'], 'analysisStatus'),
      determinismStatus: _string(
        value['determinismStatus'],
        'determinismStatus',
      ),
      contentRect: bounds,
      residuePixelsConserved: _boolean(conservation['conserved'], 'conserved'),
      candidates: candidates,
    );
  }
}

final class Lf2GroundTruthAnnotation {
  const Lf2GroundTruthAnnotation({
    required this.annotationId,
    required this.sourceId,
    required this.rect,
    required this.polarity,
    required this.reviewStatus,
    required this.formationGroupId,
    required this.notes,
  });

  final String annotationId;
  final String sourceId;
  final Lf2NormalizedRect rect;
  final Lf2GroundTruthPolarity polarity;
  final Lf2GroundTruthStatus reviewStatus;
  final String? formationGroupId;
  final String notes;

  Map<String, Object?> toJson() => {
    'annotationId': annotationId,
    'sourceId': sourceId,
    'left': rect.left,
    'top': rect.top,
    'right': rect.right,
    'bottom': rect.bottom,
    'polarity': polarity.name,
    'reviewStatus': reviewStatus.name,
    'formationGroupId': formationGroupId,
    'notes': notes,
  };
}

final class Lf2GroundTruthSet {
  Lf2GroundTruthSet({
    required this.sourceResearchId,
    required Iterable<Lf2GroundTruthAnnotation> annotations,
  }) : annotations = List<Lf2GroundTruthAnnotation>.unmodifiable(annotations);

  final String sourceResearchId;
  final List<Lf2GroundTruthAnnotation> annotations;

  Lf2GroundTruthAnnotation annotation(String id) =>
      annotations.singleWhere((value) => value.annotationId == id);
}

final class Lf2GroundTruthCodec {
  const Lf2GroundTruthCodec();

  Lf2GroundTruthSet parse({
    required String source,
    required Lf2ObservationIndex observations,
  }) {
    final root = _decodeObject(source, 'LF-1 ground truth');
    _exactFields(
      root,
      required: const {'schemaVersion', 'researchId', 'annotations'},
      field: 'root',
    );
    if (root['schemaVersion'] != '1.0') {
      throw const FormatException('Unsupported ground-truth schema version.');
    }
    final annotations = <Lf2GroundTruthAnnotation>[];
    for (final value in _list(root['annotations'], 'annotations')) {
      final object = _object(value, 'annotations[]');
      _exactFields(
        object,
        required: const {
          'annotationId',
          'sourceId',
          'left',
          'top',
          'right',
          'bottom',
          'polarity',
          'reviewStatus',
          'formationGroupId',
          'notes',
          'alignments',
        },
        field: 'annotations[]',
      );
      _list(object['alignments'], 'alignments');
      final sourceId = _identifier(object['sourceId'], 'sourceId');
      if (!observations.containsSource(sourceId)) {
        throw FormatException('Unknown LF-2 source: $sourceId.');
      }
      final rect = _rect(object, 'annotation');
      annotations.add(
        Lf2GroundTruthAnnotation(
          annotationId: _identifier(object['annotationId'], 'annotationId'),
          sourceId: sourceId,
          rect: rect,
          polarity: _enumValue(
            Lf2GroundTruthPolarity.values,
            object['polarity'],
            'polarity',
          ),
          reviewStatus: _enumValue(
            Lf2GroundTruthStatus.values,
            object['reviewStatus'],
            'reviewStatus',
          ),
          formationGroupId: object['formationGroupId'] == null
              ? null
              : _identifier(object['formationGroupId'], 'formationGroupId'),
          notes: _text(object['notes'], 'notes'),
        ),
      );
    }
    annotations.sort((first, second) {
      final source = first.sourceId.compareTo(second.sourceId);
      if (source != 0) return source;
      return first.annotationId.compareTo(second.annotationId);
    });
    if (annotations.map((value) => value.annotationId).toSet().length !=
        annotations.length) {
      throw const FormatException('Ground-truth IDs must be unique.');
    }
    return Lf2GroundTruthSet(
      sourceResearchId: _identifier(root['researchId'], 'researchId'),
      annotations: annotations,
    );
  }
}

final class Lf2CandidateAlignment {
  const Lf2CandidateAlignment({
    required this.annotationId,
    required this.profileId,
    required this.candidateId,
    required this.status,
  });

  final String annotationId;
  final String profileId;
  final int candidateId;
  final Lf2AlignmentStatus status;

  Map<String, Object> toJson() => {
    'annotationId': annotationId,
    'profileId': profileId,
    'candidateId': candidateId,
    'status': status.name,
  };
}

final class Lf2AlignmentReview {
  Lf2AlignmentReview({
    required this.researchId,
    required this.sourceGroundTruthResearchId,
    required Iterable<Lf2CandidateAlignment> alignments,
  }) : alignments = List<Lf2CandidateAlignment>.unmodifiable(alignments);

  final String researchId;
  final String sourceGroundTruthResearchId;
  final List<Lf2CandidateAlignment> alignments;

  Map<String, Object> toJson() => {
    'schemaVersion': '1.0',
    'researchId': researchId,
    'sourceGroundTruthResearchId': sourceGroundTruthResearchId,
    'alignments': alignments.map((value) => value.toJson()).toList(),
  };
}

final class Lf2AlignmentCodec {
  const Lf2AlignmentCodec();

  Lf2AlignmentReview createDefault({
    required Lf2ObservationIndex observations,
    required Lf2GroundTruthSet groundTruth,
  }) {
    return Lf2AlignmentReview(
      researchId: observations.researchId,
      sourceGroundTruthResearchId: groundTruth.sourceResearchId,
      alignments: _expectedAlignments(
        observations,
        groundTruth,
        status: Lf2AlignmentStatus.unrelated,
      ),
    );
  }

  Lf2AlignmentReview parse({
    required String source,
    required Lf2ObservationIndex observations,
    required Lf2GroundTruthSet groundTruth,
  }) {
    final root = _decodeObject(source, 'LF-2 alignment review');
    _exactFields(
      root,
      required: const {
        'schemaVersion',
        'researchId',
        'sourceGroundTruthResearchId',
        'alignments',
      },
      field: 'root',
    );
    if (root['schemaVersion'] != '1.0' ||
        root['researchId'] != observations.researchId ||
        root['sourceGroundTruthResearchId'] != groundTruth.sourceResearchId) {
      throw const FormatException('LF-2 alignment context is invalid.');
    }
    final alignments = <Lf2CandidateAlignment>[];
    for (final value in _list(root['alignments'], 'alignments')) {
      final object = _object(value, 'alignments[]');
      _exactFields(
        object,
        required: const {'annotationId', 'profileId', 'candidateId', 'status'},
        field: 'alignments[]',
      );
      alignments.add(
        Lf2CandidateAlignment(
          annotationId: _identifier(object['annotationId'], 'annotationId'),
          profileId: _identifier(object['profileId'], 'profileId'),
          candidateId: _positiveInt(object['candidateId'], 'candidateId'),
          status: _enumValue(
            Lf2AlignmentStatus.values,
            object['status'],
            'status',
          ),
        ),
      );
    }
    alignments.sort(_compareAlignment);
    final expected = _expectedAlignments(observations, groundTruth);
    if (alignments.length != expected.length) {
      throw const FormatException(
        'Every LF-2 candidate requires one explicit alignment.',
      );
    }
    for (var index = 0; index < alignments.length; index++) {
      final actual = alignments[index];
      final wanted = expected[index];
      if (actual.annotationId != wanted.annotationId ||
          actual.profileId != wanted.profileId ||
          actual.candidateId != wanted.candidateId) {
        throw const FormatException(
          'LF-2 alignments are duplicate, missing, or unknown.',
        );
      }
      _validateAlignment(actual, observations, groundTruth);
    }
    return Lf2AlignmentReview(
      researchId: observations.researchId,
      sourceGroundTruthResearchId: groundTruth.sourceResearchId,
      alignments: alignments,
    );
  }

  String encode(Lf2AlignmentReview value) =>
      '${const JsonEncoder.withIndent('  ').convert(value.toJson())}\n';

  static List<Lf2CandidateAlignment> _expectedAlignments(
    Lf2ObservationIndex observations,
    Lf2GroundTruthSet groundTruth, {
    Lf2AlignmentStatus status = Lf2AlignmentStatus.unrelated,
  }) {
    final values = <Lf2CandidateAlignment>[];
    for (final annotation in groundTruth.annotations) {
      for (final profileId in observations.profileIds) {
        for (final candidate
            in observations
                .observation(profileId, annotation.sourceId)
                .candidates) {
          values.add(
            Lf2CandidateAlignment(
              annotationId: annotation.annotationId,
              profileId: profileId,
              candidateId: candidate.candidateId,
              status: status,
            ),
          );
        }
      }
    }
    values.sort(_compareAlignment);
    return values;
  }

  static void _validateAlignment(
    Lf2CandidateAlignment alignment,
    Lf2ObservationIndex observations,
    Lf2GroundTruthSet groundTruth,
  ) {
    if (alignment.status == Lf2AlignmentStatus.unrelated) return;
    final annotation = groundTruth.annotation(alignment.annotationId);
    final observation = observations.observation(
      alignment.profileId,
      annotation.sourceId,
    );
    final candidate = observations.candidate(
      alignment.profileId,
      annotation.sourceId,
      alignment.candidateId,
    );
    if (annotation.polarity != Lf2GroundTruthPolarity.mixed &&
        annotation.polarity != candidate.polarity) {
      throw const FormatException(
        'Aligned or partial candidates must match annotation polarity.',
      );
    }
    if (observation.contentRect == null ||
        !_intersects(
          annotation.rect,
          _candidateSourceRect(candidate, observation.contentRect!),
        )) {
      throw const FormatException(
        'Aligned or partial candidates must intersect the annotation.',
      );
    }
    if (alignment.status == Lf2AlignmentStatus.aligned &&
        observation.contentRect != null &&
        candidate.fillsContent(observation.contentRect!)) {
      throw const FormatException(
        'A full-content LF-2 candidate cannot be aligned.',
      );
    }
  }

  static int _compareAlignment(
    Lf2CandidateAlignment first,
    Lf2CandidateAlignment second,
  ) {
    var comparison = first.annotationId.compareTo(second.annotationId);
    if (comparison != 0) return comparison;
    comparison = first.profileId.compareTo(second.profileId);
    if (comparison != 0) return comparison;
    return first.candidateId.compareTo(second.candidateId);
  }
}

final class Lf2ProfileEvaluation {
  const Lf2ProfileEvaluation({
    required this.profileId,
    required this.deterministicAndComplete,
    required this.residuePixelsConserved,
    required this.candidateBudgetRate,
    required this.annotationCoverageRate,
    required this.residueCoverageRate,
    required this.negativeSpaceCoverageRate,
    required this.formationConsistencyRate,
    required this.mixedDiagnosticCoverageRate,
    required this.maximumPossibleAnnotationCoverageRate,
    required this.maximumPossibleResidueCoverageRate,
    required this.maximumPossibleNegativeSpaceCoverageRate,
    required this.mathematicallyEliminated,
    required this.medianCandidateCount,
    required this.passed,
  });

  final String profileId;
  final bool deterministicAndComplete;
  final bool residuePixelsConserved;
  final double candidateBudgetRate;
  final double annotationCoverageRate;
  final double residueCoverageRate;
  final double negativeSpaceCoverageRate;
  final double formationConsistencyRate;
  final double mixedDiagnosticCoverageRate;
  final double maximumPossibleAnnotationCoverageRate;
  final double maximumPossibleResidueCoverageRate;
  final double maximumPossibleNegativeSpaceCoverageRate;
  final bool mathematicallyEliminated;
  final double medianCandidateCount;
  final bool passed;

  Map<String, Object> toJson() => {
    'profileId': profileId,
    'deterministicAndComplete': deterministicAndComplete,
    'residuePixelsConserved': residuePixelsConserved,
    'candidateBudgetRate': candidateBudgetRate,
    'annotationCoverageRate': annotationCoverageRate,
    'residueCoverageRate': residueCoverageRate,
    'negativeSpaceCoverageRate': negativeSpaceCoverageRate,
    'formationConsistencyRate': formationConsistencyRate,
    'mixedDiagnosticCoverageRate': mixedDiagnosticCoverageRate,
    'maximumPossibleAnnotationCoverageRate':
        maximumPossibleAnnotationCoverageRate,
    'maximumPossibleResidueCoverageRate': maximumPossibleResidueCoverageRate,
    'maximumPossibleNegativeSpaceCoverageRate':
        maximumPossibleNegativeSpaceCoverageRate,
    'mathematicallyEliminated': mathematicallyEliminated,
    'medianCandidateCount': medianCandidateCount,
    'passed': passed,
  };
}

final class Lf2EvaluationReport {
  Lf2EvaluationReport({
    required this.researchId,
    required this.groundTruthSufficient,
    required this.includedPrimaryAnnotationCount,
    required this.residueAnnotationCount,
    required this.negativeSpaceAnnotationCount,
    required this.mixedDiagnosticAnnotationCount,
    required this.eligibleFormationGroupCount,
    required Iterable<Lf2ProfileEvaluation> profiles,
    required this.productionProfileCandidateId,
    required this.allProfilesEliminatedByUpperBound,
    required this.evaluationBasis,
  }) : profiles = List<Lf2ProfileEvaluation>.unmodifiable(profiles);

  final String researchId;
  final bool groundTruthSufficient;
  final int includedPrimaryAnnotationCount;
  final int residueAnnotationCount;
  final int negativeSpaceAnnotationCount;
  final int mixedDiagnosticAnnotationCount;
  final int eligibleFormationGroupCount;
  final List<Lf2ProfileEvaluation> profiles;
  final String? productionProfileCandidateId;
  final bool allProfilesEliminatedByUpperBound;
  final Lf2EvaluationBasis evaluationBasis;

  Map<String, Object?> toJson() => {
    'schemaVersion': '1.0',
    'researchId': researchId,
    'groundTruthSufficient': groundTruthSufficient,
    'includedPrimaryAnnotationCount': includedPrimaryAnnotationCount,
    'residueAnnotationCount': residueAnnotationCount,
    'negativeSpaceAnnotationCount': negativeSpaceAnnotationCount,
    'mixedDiagnosticAnnotationCount': mixedDiagnosticAnnotationCount,
    'eligibleFormationGroupCount': eligibleFormationGroupCount,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
    'productionProfileCandidateId': productionProfileCandidateId,
    'allProfilesEliminatedByUpperBound': allProfilesEliminatedByUpperBound,
    'evaluationBasis': evaluationBasis.name,
  };
}

final class Lf2Evaluator {
  const Lf2Evaluator();

  Lf2EvaluationReport evaluate({
    required Lf2ObservationIndex observations,
    required Lf2GroundTruthSet groundTruth,
    required Lf2AlignmentReview review,
    bool alignmentReviewCompleted = true,
  }) {
    final included = groundTruth.annotations
        .where(
          (annotation) =>
              annotation.reviewStatus == Lf2GroundTruthStatus.include,
        )
        .toList(growable: false);
    final residue = included
        .where(
          (annotation) => annotation.polarity == Lf2GroundTruthPolarity.residue,
        )
        .toList(growable: false);
    final negative = included
        .where(
          (annotation) =>
              annotation.polarity == Lf2GroundTruthPolarity.negativeSpace,
        )
        .toList(growable: false);
    final mixed = included
        .where(
          (annotation) => annotation.polarity == Lf2GroundTruthPolarity.mixed,
        )
        .toList(growable: false);
    final primary = [...residue, ...negative];
    final groups = <String, List<Lf2GroundTruthAnnotation>>{};
    for (final annotation in primary) {
      final groupId = annotation.formationGroupId;
      if (groupId != null)
        groups.putIfAbsent(groupId, () => []).add(annotation);
    }
    groups.removeWhere(
      (_, annotations) =>
          annotations.map((value) => value.sourceId).toSet().length < 2,
    );

    final groundTruthSufficient = residue.length >= 5 && negative.length >= 5;
    final evaluations = <Lf2ProfileEvaluation>[];
    for (final profileId in observations.profileIds) {
      final summary = observations.summary(profileId);
      final deterministic =
          summary.failedImageCount == 0 &&
          summary.nonDeterministicImageCount == 0 &&
          summary.deterministicImageCount == summary.enabledImageCount;
      final conserved =
          summary.conservedImageCount == summary.enabledImageCount;
      final overallCoverage = _coverage(primary, profileId, review);
      final residueCoverage = _coverage(residue, profileId, review);
      final negativeCoverage = _coverage(negative, profileId, review);
      final maximumOverall = _maximumPossibleCoverage(
        primary,
        profileId,
        observations,
      );
      final maximumResidue = _maximumPossibleCoverage(
        residue,
        profileId,
        observations,
      );
      final maximumNegative = _maximumPossibleCoverage(
        negative,
        profileId,
        observations,
      );
      final consistency = groups.isEmpty
          ? 0.0
          : groups.values.where((group) {
                  final sources = group.map((value) => value.sourceId).toSet();
                  return sources.every(
                    (sourceId) => group
                        .where((value) => value.sourceId == sourceId)
                        .any(
                          (annotation) =>
                              _isAligned(annotation, profileId, review),
                        ),
                  );
                }).length /
                groups.length;
      final counts =
          observations.observations
              .where(
                (value) =>
                    value.profileId == profileId &&
                    value.analysisStatus == 'success',
              )
              .map((value) => value.candidates.length)
              .toList(growable: false)
            ..sort();
      final evaluation = Lf2ProfileEvaluation(
        profileId: profileId,
        deterministicAndComplete: deterministic,
        residuePixelsConserved: conserved,
        candidateBudgetRate: summary.candidateBudgetRate,
        annotationCoverageRate: overallCoverage,
        residueCoverageRate: residueCoverage,
        negativeSpaceCoverageRate: negativeCoverage,
        formationConsistencyRate: consistency,
        mixedDiagnosticCoverageRate: _coverage(mixed, profileId, review),
        maximumPossibleAnnotationCoverageRate: maximumOverall,
        maximumPossibleResidueCoverageRate: maximumResidue,
        maximumPossibleNegativeSpaceCoverageRate: maximumNegative,
        mathematicallyEliminated:
            !deterministic ||
            !conserved ||
            summary.candidateBudgetRate < 0.8 ||
            maximumOverall < 0.75 ||
            maximumResidue < 0.75 ||
            maximumNegative < 0.75,
        medianCandidateCount: _median(counts),
        passed:
            alignmentReviewCompleted &&
            groundTruthSufficient &&
            groups.isNotEmpty &&
            deterministic &&
            conserved &&
            summary.candidateBudgetRate >= 0.8 &&
            overallCoverage >= 0.75 &&
            residueCoverage >= 0.75 &&
            negativeCoverage >= 0.75 &&
            consistency >= 0.7,
      );
      evaluations.add(evaluation);
    }
    final passing = evaluations.where((value) => value.passed).toList()
      ..sort(_comparePassing);
    return Lf2EvaluationReport(
      researchId: observations.researchId,
      groundTruthSufficient: groundTruthSufficient,
      includedPrimaryAnnotationCount: primary.length,
      residueAnnotationCount: residue.length,
      negativeSpaceAnnotationCount: negative.length,
      mixedDiagnosticAnnotationCount: mixed.length,
      eligibleFormationGroupCount: groups.length,
      profiles: evaluations,
      productionProfileCandidateId: passing.isEmpty
          ? null
          : passing.first.profileId,
      allProfilesEliminatedByUpperBound: evaluations.every(
        (value) => value.mathematicallyEliminated,
      ),
      evaluationBasis: alignmentReviewCompleted
          ? Lf2EvaluationBasis.humanAlignmentReview
          : Lf2EvaluationBasis.deterministicUpperBound,
    );
  }

  static double _coverage(
    List<Lf2GroundTruthAnnotation> annotations,
    String profileId,
    Lf2AlignmentReview review,
  ) {
    if (annotations.isEmpty) return 0.0;
    return annotations
            .where((value) => _isAligned(value, profileId, review))
            .length /
        annotations.length;
  }

  static bool _isAligned(
    Lf2GroundTruthAnnotation annotation,
    String profileId,
    Lf2AlignmentReview review,
  ) => review.alignments.any(
    (alignment) =>
        alignment.annotationId == annotation.annotationId &&
        alignment.profileId == profileId &&
        alignment.status == Lf2AlignmentStatus.aligned,
  );

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

  static double _median(List<int> values) {
    if (values.isEmpty) return 0;
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle].toDouble()
        : (values[middle - 1] + values[middle]) / 2;
  }

  static int _comparePassing(
    Lf2ProfileEvaluation first,
    Lf2ProfileEvaluation second,
  ) {
    var comparison = second.annotationCoverageRate.compareTo(
      first.annotationCoverageRate,
    );
    if (comparison != 0) return comparison;
    comparison = second.formationConsistencyRate.compareTo(
      first.formationConsistencyRate,
    );
    if (comparison != 0) return comparison;
    comparison = second.candidateBudgetRate.compareTo(
      first.candidateBudgetRate,
    );
    if (comparison != 0) return comparison;
    comparison = first.medianCandidateCount.compareTo(
      second.medianCandidateCount,
    );
    if (comparison != 0) return comparison;
    return first.profileId.compareTo(second.profileId);
  }
}

final class Lf2ReviewWriter {
  const Lf2ReviewWriter();

  Future<void> write({
    required String outputDirectory,
    required String repositoryRoot,
    required Lf2AlignmentReview review,
    required Lf2EvaluationReport evaluation,
  }) async {
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    try {
      await Directory(outputDirectory).create(recursive: true);
      await File(
        _join(outputDirectory, 'candidate_alignment_review.json'),
      ).writeAsString(const Lf2AlignmentCodec().encode(review), flush: true);
      await File(
        _join(outputDirectory, 'profile_evaluation.json'),
      ).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(evaluation.toJson())}\n',
        flush: true,
      );
      await File(
        _join(outputDirectory, 'profile_evaluation.csv'),
      ).writeAsString(_evaluationCsv(evaluation), flush: true);
      await File(
        _join(outputDirectory, 'research_summary.md'),
      ).writeAsString(_summary(evaluation), flush: true);
    } on FileSystemException {
      throw const FileSystemException(
        'LF-2 review outputs could not be written.',
      );
    }
  }

  Future<void> writeFeasibility({
    required String outputDirectory,
    required String repositoryRoot,
    required Lf2EvaluationReport evaluation,
  }) async {
    if (evaluation.evaluationBasis !=
            Lf2EvaluationBasis.deterministicUpperBound ||
        !evaluation.allProfilesEliminatedByUpperBound) {
      throw ArgumentError.value(
        evaluation,
        'evaluation',
        'must conclusively eliminate all profiles by upper bound',
      );
    }
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    try {
      await Directory(outputDirectory).create(recursive: true);
      await File(
        _join(outputDirectory, 'profile_evaluation.json'),
      ).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(evaluation.toJson())}\n',
        flush: true,
      );
      await File(
        _join(outputDirectory, 'profile_evaluation.csv'),
      ).writeAsString(_evaluationCsv(evaluation), flush: true);
      await File(
        _join(outputDirectory, 'research_summary.md'),
      ).writeAsString(_summary(evaluation), flush: true);
    } on FileSystemException {
      throw const FileSystemException(
        'LF-2 feasibility outputs could not be written.',
      );
    }
  }

  static String _evaluationCsv(Lf2EvaluationReport report) {
    final rows = <String>[
      'profileId,deterministicAndComplete,residuePixelsConserved,'
          'candidateBudgetRate,annotationCoverageRate,residueCoverageRate,'
          'negativeSpaceCoverageRate,formationConsistencyRate,'
          'mixedDiagnosticCoverageRate,maximumPossibleAnnotationCoverageRate,'
          'maximumPossibleResidueCoverageRate,'
          'maximumPossibleNegativeSpaceCoverageRate,'
          'mathematicallyEliminated,medianCandidateCount,passed',
      for (final profile in report.profiles)
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
    ];
    return '${rows.join('\r\n')}\r\n';
  }

  static String _summary(Lf2EvaluationReport report) {
    final candidate = report.productionProfileCandidateId;
    final verdict = candidate == null
        ? 'NO PROFILE PASSED'
        : 'RESEARCH CANDIDATE: `$candidate`';
    return '''
# Atlas LF-2 Deterministic Local Formation Evidence Research

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

Mixed annotations are diagnostic only. Deterministic upper-bound evaluation
does not fabricate human alignment decisions. A selected profile is a research
candidate, not a frozen Vision change, semantic identity, or evidence binding.
''';
  }
}

Map<String, Object?> _decodeObject(String source, String name) {
  try {
    return _object(jsonDecode(source), 'root');
  } on FormatException {
    throw FormatException('$name is malformed.');
  }
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$field must be an object.');
  }
  return value;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List<Object?>) {
    throw FormatException('$field must be an array.');
  }
  return value;
}

void _exactFields(
  Map<String, Object?> value, {
  required Set<String> required,
  required String field,
}) {
  if (value.keys.toSet().difference(required).isNotEmpty ||
      required.difference(value.keys.toSet()).isNotEmpty) {
    throw FormatException('$field contains missing or unknown fields.');
  }
}

Lf2NormalizedRect _rect(Map<String, Object?> value, String field) {
  final rect = Lf2NormalizedRect(
    left: _coordinate(value['left'], '$field.left'),
    top: _coordinate(value['top'], '$field.top'),
    right: _coordinate(value['right'], '$field.right'),
    bottom: _coordinate(value['bottom'], '$field.bottom'),
  );
  if (rect.left >= rect.right || rect.top >= rect.bottom) {
    throw FormatException('$field must have positive area.');
  }
  return rect;
}

String _identifier(Object? value, String field) {
  final text = _string(value, field);
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._#-]*$').hasMatch(text)) {
    throw FormatException('$field must be an exact safe identifier.');
  }
  return text;
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$field must be a non-empty exact string.');
  }
  return value;
}

String _text(Object? value, String field) {
  if (value is! String ||
      value.trim() != value ||
      value.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
    throw FormatException('$field contains invalid text.');
  }
  return value;
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('$field must be a positive integer.');
  }
  return value;
}

int _nonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw FormatException('$field must be a non-negative integer.');
  }
  return value;
}

double _coordinate(Object? value, String field) {
  if (value is! num || !value.toDouble().isFinite || value < 0 || value > 1) {
    throw FormatException('$field must be a normalized finite number.');
  }
  return value.toDouble();
}

bool _boolean(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean.');
  return value;
}

T _enumValue<T extends Enum>(List<T> values, Object? value, String field) {
  final name = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  throw FormatException('$field contains an unsupported value.');
}

bool _same(Iterable<Object?> first, Iterable<Object?> second) {
  final firstValues = first.toList(growable: false);
  final secondValues = second.toList(growable: false);
  if (firstValues.length != secondValues.length) return false;
  for (var index = 0; index < firstValues.length; index++) {
    if (firstValues[index] != secondValues[index]) return false;
  }
  return true;
}

double _mapToSource(double value, double minimum, double maximum) {
  final mapped = (value - minimum) / (maximum - minimum);
  return mapped.clamp(0.0, 1.0);
}

void _rejectRepositoryOutput(String output, String repositoryRoot) {
  final outputPath = Directory(output).absolute.path.toLowerCase();
  final repositoryPath = Directory(repositoryRoot).absolute.path.toLowerCase();
  final prefix = repositoryPath.endsWith(Platform.pathSeparator)
      ? repositoryPath
      : '$repositoryPath${Platform.pathSeparator}';
  if (outputPath == repositoryPath || outputPath.startsWith(prefix)) {
    throw const FileSystemException(
      'LF-2 review output must remain outside the repository.',
    );
  }
}

String _join(String directory, String filename) =>
    [directory, filename].join(Platform.pathSeparator);

Lf2NormalizedRect _candidateSourceRect(
  Lf2ReviewCandidate candidate,
  Lf2NormalizedRect contentRect,
) {
  return Lf2NormalizedRect(
    left: _mapToSource(candidate.left, contentRect.left, contentRect.right),
    top: _mapToSource(candidate.top, contentRect.top, contentRect.bottom),
    right: _mapToSource(candidate.right, contentRect.left, contentRect.right),
    bottom: _mapToSource(candidate.bottom, contentRect.top, contentRect.bottom),
  );
}

bool _intersects(Lf2NormalizedRect first, Lf2NormalizedRect second) {
  return first.left < second.right &&
      first.right > second.left &&
      first.top < second.bottom &&
      first.bottom > second.top;
}
