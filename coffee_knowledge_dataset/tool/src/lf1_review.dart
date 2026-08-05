import 'dart:convert';
import 'dart:io';

enum Lf1Polarity { residue, negativeSpace, mixed }

enum Lf1ReviewStatus { include, uncertain, exclude }

enum Lf1AlignmentStatus { aligned, partial, unrelated }

final class Lf1ReviewCandidate {
  const Lf1ReviewCandidate({
    required this.candidateId,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.nodeCount,
    required this.directedEdgeCount,
  });

  final int candidateId;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int nodeCount;
  final int directedEdgeCount;

  Map<String, Object> toJson() => {
    'candidateId': candidateId,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'nodeCount': nodeCount,
    'directedEdgeCount': directedEdgeCount,
  };
}

final class Lf1ReviewObservation {
  Lf1ReviewObservation({
    required this.profileId,
    required this.sourceId,
    required this.analysisStatus,
    required this.determinismStatus,
    required Iterable<Lf1ReviewCandidate> candidates,
  }) : candidates = List<Lf1ReviewCandidate>.unmodifiable(candidates);

  final String profileId;
  final String sourceId;
  final String analysisStatus;
  final String determinismStatus;
  final List<Lf1ReviewCandidate> candidates;
}

final class Lf1ReviewProfileSummary {
  const Lf1ReviewProfileSummary({
    required this.profileId,
    required this.enabledImageCount,
    required this.failedImageCount,
    required this.deterministicImageCount,
    required this.nonDeterministicImageCount,
    required this.candidateBudgetImageCount,
    required this.totalCandidateCount,
  });

  final String profileId;
  final int enabledImageCount;
  final int failedImageCount;
  final int deterministicImageCount;
  final int nonDeterministicImageCount;
  final int candidateBudgetImageCount;
  final int totalCandidateCount;

  double get candidateBudgetRate => enabledImageCount == 0
      ? 0.0
      : candidateBudgetImageCount / enabledImageCount;
}

final class Lf1ObservationIndex {
  Lf1ObservationIndex({
    required this.researchId,
    required Iterable<String> profileIds,
    required Iterable<Lf1ReviewProfileSummary> profileSummaries,
    required Iterable<Lf1ReviewObservation> observations,
  }) : profileIds = List<String>.unmodifiable(profileIds),
       profileSummaries = List<Lf1ReviewProfileSummary>.unmodifiable(
         profileSummaries,
       ),
       observations = List<Lf1ReviewObservation>.unmodifiable(observations) {
    _validate();
  }

  factory Lf1ObservationIndex.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('LF-1 observation report is malformed.');
    }
    final root = _object(decoded, 'root');
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
      throw const FormatException('Unsupported LF-1 report schema version.');
    }

    final profileIds = <String>[];
    for (final value in _list(root['profiles'], 'profiles')) {
      final profile = _object(value, 'profiles[]');
      final id = _identifier(profile['profileId'], 'profiles[].profileId');
      profileIds.add(id);
    }

    final summaries = <Lf1ReviewProfileSummary>[];
    for (final value in _list(root['profileSummaries'], 'profileSummaries')) {
      final summary = _object(value, 'profileSummaries[]');
      summaries.add(
        Lf1ReviewProfileSummary(
          profileId: _identifier(
            summary['profileId'],
            'profileSummaries[].profileId',
          ),
          enabledImageCount: _nonNegativeInt(
            summary['enabledImageCount'],
            'enabledImageCount',
          ),
          failedImageCount: _nonNegativeInt(
            summary['failedImageCount'],
            'failedImageCount',
          ),
          deterministicImageCount: _nonNegativeInt(
            summary['deterministicImageCount'],
            'deterministicImageCount',
          ),
          nonDeterministicImageCount: _nonNegativeInt(
            summary['nonDeterministicImageCount'],
            'nonDeterministicImageCount',
          ),
          candidateBudgetImageCount: _nonNegativeInt(
            summary['candidateBudgetImageCount'],
            'candidateBudgetImageCount',
          ),
          totalCandidateCount: _nonNegativeInt(
            summary['totalCandidateCount'],
            'totalCandidateCount',
          ),
        ),
      );
    }

    final observations = <Lf1ReviewObservation>[];
    for (final value in _list(root['observations'], 'observations')) {
      final observation = _object(value, 'observations[]');
      final candidates = <Lf1ReviewCandidate>[];
      for (final candidateValue in _list(
        observation['candidates'],
        'observations[].candidates',
      )) {
        final candidate = _object(candidateValue, 'candidates[]');
        final geometry = _object(candidate['geometry'], 'candidate.geometry');
        final topology = _object(candidate['topology'], 'candidate.topology');
        final left = _coordinate(geometry['left'], 'geometry.left');
        final top = _coordinate(geometry['top'], 'geometry.top');
        final right = _coordinate(geometry['right'], 'geometry.right');
        final bottom = _coordinate(geometry['bottom'], 'geometry.bottom');
        if (left >= right || top >= bottom) {
          throw const FormatException(
            'Candidate geometry must have positive area.',
          );
        }
        candidates.add(
          Lf1ReviewCandidate(
            candidateId: _positiveInt(candidate['candidateId'], 'candidateId'),
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            nodeCount: _positiveInt(topology['nodeCount'], 'nodeCount'),
            directedEdgeCount: _nonNegativeInt(
              topology['directedEdgeCount'],
              'directedEdgeCount',
            ),
          ),
        );
      }
      observations.add(
        Lf1ReviewObservation(
          profileId: _identifier(
            observation['profileId'],
            'observation.profileId',
          ),
          sourceId: _identifier(
            observation['sourceId'],
            'observation.sourceId',
          ),
          analysisStatus: _string(
            observation['analysisStatus'],
            'analysisStatus',
          ),
          determinismStatus: _string(
            observation['determinismStatus'],
            'determinismStatus',
          ),
          candidates: candidates,
        ),
      );
    }

    return Lf1ObservationIndex(
      researchId: _identifier(root['researchId'], 'researchId'),
      profileIds: profileIds,
      profileSummaries: summaries,
      observations: observations,
    );
  }

  final String researchId;
  final List<String> profileIds;
  final List<Lf1ReviewProfileSummary> profileSummaries;
  final List<Lf1ReviewObservation> observations;

  Lf1ReviewObservation observation(String profileId, String sourceId) {
    return observations.singleWhere(
      (value) => value.profileId == profileId && value.sourceId == sourceId,
    );
  }

  Lf1ReviewProfileSummary summary(String profileId) {
    return profileSummaries.singleWhere(
      (value) => value.profileId == profileId,
    );
  }

  bool containsCandidate(String profileId, String sourceId, int candidateId) {
    return observation(
      profileId,
      sourceId,
    ).candidates.any((candidate) => candidate.candidateId == candidateId);
  }

  void _validate() {
    if (profileIds.isEmpty) {
      throw const FormatException('LF-1 report must contain profiles.');
    }
    final canonicalProfiles = List<String>.of(profileIds)..sort();
    if (!_same(profileIds, canonicalProfiles) ||
        profileIds.toSet().length != profileIds.length) {
      throw const FormatException('LF-1 profile IDs must be canonical.');
    }
    if (profileSummaries.length != profileIds.length ||
        !_same(profileSummaries.map((value) => value.profileId), profileIds)) {
      throw const FormatException('LF-1 profile summaries are incomplete.');
    }
    final keys = <String>{};
    for (final observation in observations) {
      if (!profileIds.contains(observation.profileId) ||
          !keys.add('${observation.profileId}\u0000${observation.sourceId}')) {
        throw const FormatException('LF-1 observations are inconsistent.');
      }
      final candidateIds = observation.candidates
          .map((candidate) => candidate.candidateId)
          .toList(growable: false);
      final canonical = List<int>.of(candidateIds)..sort();
      if (!_same(candidateIds, canonical) ||
          candidateIds.toSet().length != candidateIds.length) {
        throw const FormatException('Candidate IDs must be canonical.');
      }
    }
  }
}

final class Lf1CandidateAlignment {
  const Lf1CandidateAlignment({
    required this.profileId,
    required this.candidateId,
    required this.status,
  });

  final String profileId;
  final int candidateId;
  final Lf1AlignmentStatus status;

  Map<String, Object> toJson() => {
    'profileId': profileId,
    'candidateId': candidateId,
    'status': status.name,
  };
}

final class Lf1Annotation {
  Lf1Annotation({
    required this.annotationId,
    required this.sourceId,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.polarity,
    required this.reviewStatus,
    this.formationGroupId,
    this.notes = '',
    required Iterable<Lf1CandidateAlignment> alignments,
  }) : alignments = List<Lf1CandidateAlignment>.unmodifiable(alignments);

  final String annotationId;
  final String sourceId;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final Lf1Polarity polarity;
  final Lf1ReviewStatus reviewStatus;
  final String? formationGroupId;
  final String notes;
  final List<Lf1CandidateAlignment> alignments;

  Map<String, Object?> toJson() => {
    'annotationId': annotationId,
    'sourceId': sourceId,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'polarity': polarity.name,
    'reviewStatus': reviewStatus.name,
    'formationGroupId': formationGroupId,
    'notes': notes,
    'alignments': alignments.map((value) => value.toJson()).toList(),
  };
}

final class Lf1AnnotationSet {
  Lf1AnnotationSet({
    required this.researchId,
    required Iterable<Lf1Annotation> annotations,
  }) : annotations = List<Lf1Annotation>.unmodifiable(annotations);

  final String researchId;
  final List<Lf1Annotation> annotations;

  Map<String, Object> toJson() => {
    'schemaVersion': '1.0',
    'researchId': researchId,
    'annotations': annotations.map((value) => value.toJson()).toList(),
  };
}

final class Lf1AnnotationCodec {
  const Lf1AnnotationCodec();

  Lf1AnnotationSet parse({
    required String source,
    required Lf1ObservationIndex observations,
    required Set<String> panelSourceIds,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('LF-1 annotations are malformed.');
    }
    final root = _object(decoded, 'root');
    _exactFields(
      root,
      required: const {'schemaVersion', 'researchId', 'annotations'},
      field: 'root',
    );
    if (root['schemaVersion'] != '1.0' ||
        root['researchId'] != observations.researchId) {
      throw const FormatException('LF-1 annotation context is invalid.');
    }

    final annotations = <Lf1Annotation>[];
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
      final sourceId = _identifier(object['sourceId'], 'sourceId');
      if (!panelSourceIds.contains(sourceId)) {
        throw FormatException('Unknown LF-1 panel source: $sourceId.');
      }
      final left = _coordinate(object['left'], 'left');
      final top = _coordinate(object['top'], 'top');
      final right = _coordinate(object['right'], 'right');
      final bottom = _coordinate(object['bottom'], 'bottom');
      if (left >= right || top >= bottom) {
        throw const FormatException(
          'Annotation boxes must have positive area.',
        );
      }

      final alignments = <Lf1CandidateAlignment>[];
      for (final alignmentValue in _list(object['alignments'], 'alignments')) {
        final alignment = _object(alignmentValue, 'alignments[]');
        _exactFields(
          alignment,
          required: const {'profileId', 'candidateId', 'status'},
          field: 'alignments[]',
        );
        final profileId = _identifier(alignment['profileId'], 'profileId');
        final candidateId = _positiveInt(
          alignment['candidateId'],
          'candidateId',
        );
        if (!observations.containsCandidate(profileId, sourceId, candidateId)) {
          throw const FormatException(
            'Alignment must reference an existing LF-1 candidate.',
          );
        }
        alignments.add(
          Lf1CandidateAlignment(
            profileId: profileId,
            candidateId: candidateId,
            status: _enumValue(
              Lf1AlignmentStatus.values,
              alignment['status'],
              'status',
            ),
          ),
        );
      }
      alignments.sort((first, second) {
        final profile = first.profileId.compareTo(second.profileId);
        if (profile != 0) return profile;
        return first.candidateId.compareTo(second.candidateId);
      });
      final alignmentKeys = <String>{};
      for (final alignment in alignments) {
        if (!alignmentKeys.add(
          '${alignment.profileId}\u0000${alignment.candidateId}',
        )) {
          throw const FormatException('Duplicate candidate alignment.');
        }
      }
      final expectedAlignmentKeys = <String>{
        for (final profileId in observations.profileIds)
          for (final candidate
              in observations.observation(profileId, sourceId).candidates)
            '$profileId\u0000${candidate.candidateId}',
      };
      if (alignmentKeys.length != expectedAlignmentKeys.length ||
          !alignmentKeys.containsAll(expectedAlignmentKeys)) {
        throw const FormatException(
          'Every candidate must have one explicit alignment status.',
        );
      }

      final formationGroupId = object['formationGroupId'] == null
          ? null
          : _identifier(object['formationGroupId'], 'formationGroupId');
      annotations.add(
        Lf1Annotation(
          annotationId: _identifier(object['annotationId'], 'annotationId'),
          sourceId: sourceId,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          polarity: _enumValue(
            Lf1Polarity.values,
            object['polarity'],
            'polarity',
          ),
          reviewStatus: _enumValue(
            Lf1ReviewStatus.values,
            object['reviewStatus'],
            'reviewStatus',
          ),
          formationGroupId: formationGroupId,
          notes: _text(object['notes'], 'notes'),
          alignments: alignments,
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
      throw const FormatException('Annotation IDs must be unique.');
    }
    return Lf1AnnotationSet(
      researchId: observations.researchId,
      annotations: annotations,
    );
  }

  String encode(Lf1AnnotationSet value) {
    return '${const JsonEncoder.withIndent('  ').convert(value.toJson())}\n';
  }
}

final class Lf1ProfileEvaluation {
  const Lf1ProfileEvaluation({
    required this.profileId,
    required this.deterministicAndComplete,
    required this.candidateBudgetRate,
    required this.annotationCoverageRate,
    required this.residueCoverageRate,
    required this.negativeSpaceCoverageRate,
    required this.formationConsistencyRate,
    required this.medianCandidateCount,
    required this.passed,
  });

  final String profileId;
  final bool deterministicAndComplete;
  final double candidateBudgetRate;
  final double annotationCoverageRate;
  final double residueCoverageRate;
  final double negativeSpaceCoverageRate;
  final double formationConsistencyRate;
  final double medianCandidateCount;
  final bool passed;

  Map<String, Object> toJson() => {
    'profileId': profileId,
    'deterministicAndComplete': deterministicAndComplete,
    'candidateBudgetRate': candidateBudgetRate,
    'annotationCoverageRate': annotationCoverageRate,
    'residueCoverageRate': residueCoverageRate,
    'negativeSpaceCoverageRate': negativeSpaceCoverageRate,
    'formationConsistencyRate': formationConsistencyRate,
    'medianCandidateCount': medianCandidateCount,
    'passed': passed,
  };
}

final class Lf1EvaluationReport {
  Lf1EvaluationReport({
    required this.researchId,
    required this.groundTruthSufficient,
    required this.includedAnnotationCount,
    required this.residueAnnotationCount,
    required this.negativeSpaceAnnotationCount,
    required this.eligibleFormationGroupCount,
    required Iterable<Lf1ProfileEvaluation> profiles,
    required this.productionProfileCandidateId,
  }) : profiles = List<Lf1ProfileEvaluation>.unmodifiable(profiles);

  final String researchId;
  final bool groundTruthSufficient;
  final int includedAnnotationCount;
  final int residueAnnotationCount;
  final int negativeSpaceAnnotationCount;
  final int eligibleFormationGroupCount;
  final List<Lf1ProfileEvaluation> profiles;
  final String? productionProfileCandidateId;

  Map<String, Object?> toJson() => {
    'schemaVersion': '1.0',
    'researchId': researchId,
    'groundTruthSufficient': groundTruthSufficient,
    'includedAnnotationCount': includedAnnotationCount,
    'residueAnnotationCount': residueAnnotationCount,
    'negativeSpaceAnnotationCount': negativeSpaceAnnotationCount,
    'eligibleFormationGroupCount': eligibleFormationGroupCount,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
    'productionProfileCandidateId': productionProfileCandidateId,
  };
}

final class Lf1Evaluator {
  const Lf1Evaluator();

  Lf1EvaluationReport evaluate({
    required Lf1ObservationIndex observations,
    required Lf1AnnotationSet annotationSet,
  }) {
    final included = annotationSet.annotations
        .where(
          (annotation) => annotation.reviewStatus == Lf1ReviewStatus.include,
        )
        .toList(growable: false);
    final residue = included
        .where((annotation) => annotation.polarity == Lf1Polarity.residue)
        .toList(growable: false);
    final negative = included
        .where((annotation) => annotation.polarity == Lf1Polarity.negativeSpace)
        .toList(growable: false);
    final formationGroups = <String, List<Lf1Annotation>>{};
    for (final annotation in included) {
      final groupId = annotation.formationGroupId;
      if (groupId != null) {
        formationGroups.putIfAbsent(groupId, () => []).add(annotation);
      }
    }
    formationGroups.removeWhere(
      (_, annotations) =>
          annotations.map((annotation) => annotation.sourceId).toSet().length <
          2,
    );

    final groundTruthSufficient = residue.length >= 5 && negative.length >= 5;
    final evaluations = <Lf1ProfileEvaluation>[];
    for (final profileId in observations.profileIds) {
      final summary = observations.summary(profileId);
      final deterministic =
          summary.failedImageCount == 0 &&
          summary.nonDeterministicImageCount == 0 &&
          summary.deterministicImageCount == summary.enabledImageCount;
      final annotationCoverage = _coverage(included, profileId);
      final residueCoverage = _coverage(residue, profileId);
      final negativeCoverage = _coverage(negative, profileId);
      final consistency = formationGroups.isEmpty
          ? 0.0
          : formationGroups.values
                    .where(
                      (group) => group
                          .map((annotation) => annotation.sourceId)
                          .toSet()
                          .every(
                            (sourceId) => group
                                .where(
                                  (annotation) =>
                                      annotation.sourceId == sourceId,
                                )
                                .any(
                                  (annotation) =>
                                      _isAligned(annotation, profileId),
                                ),
                          ),
                    )
                    .length /
                formationGroups.length;
      final candidateCounts =
          observations.observations
              .where(
                (observation) =>
                    observation.profileId == profileId &&
                    observation.analysisStatus == 'success',
              )
              .map((observation) => observation.candidates.length)
              .toList(growable: false)
            ..sort();
      final median = _median(candidateCounts);
      evaluations.add(
        Lf1ProfileEvaluation(
          profileId: profileId,
          deterministicAndComplete: deterministic,
          candidateBudgetRate: summary.candidateBudgetRate,
          annotationCoverageRate: annotationCoverage,
          residueCoverageRate: residueCoverage,
          negativeSpaceCoverageRate: negativeCoverage,
          formationConsistencyRate: consistency,
          medianCandidateCount: median,
          passed:
              groundTruthSufficient &&
              formationGroups.isNotEmpty &&
              deterministic &&
              summary.candidateBudgetRate >= 0.8 &&
              annotationCoverage >= 0.75 &&
              consistency >= 0.7,
        ),
      );
    }
    final passing = evaluations.where((profile) => profile.passed).toList()
      ..sort(_comparePassingProfiles);
    return Lf1EvaluationReport(
      researchId: observations.researchId,
      groundTruthSufficient: groundTruthSufficient,
      includedAnnotationCount: included.length,
      residueAnnotationCount: residue.length,
      negativeSpaceAnnotationCount: negative.length,
      eligibleFormationGroupCount: formationGroups.length,
      profiles: evaluations,
      productionProfileCandidateId: passing.isEmpty
          ? null
          : passing.first.profileId,
    );
  }

  static double _coverage(List<Lf1Annotation> values, String profileId) {
    if (values.isEmpty) return 0.0;
    return values.where((value) => _isAligned(value, profileId)).length /
        values.length;
  }

  static bool _isAligned(Lf1Annotation annotation, String profileId) {
    return annotation.alignments.any(
      (alignment) =>
          alignment.profileId == profileId &&
          alignment.status == Lf1AlignmentStatus.aligned,
    );
  }

  static double _median(List<int> values) {
    if (values.isEmpty) return 0.0;
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle].toDouble()
        : (values[middle - 1] + values[middle]) / 2.0;
  }

  static int _comparePassingProfiles(
    Lf1ProfileEvaluation first,
    Lf1ProfileEvaluation second,
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

final class Lf1ReviewWriter {
  const Lf1ReviewWriter();

  Future<void> write({
    required String outputDirectory,
    required String repositoryRoot,
    required Lf1AnnotationSet annotations,
    required Lf1EvaluationReport evaluation,
  }) async {
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    final codec = const Lf1AnnotationCodec();
    final evaluationJson =
        '${const JsonEncoder.withIndent('  ').convert(evaluation.toJson())}\n';
    final evaluationCsv = _evaluationCsv(evaluation);
    final summary = _summary(evaluation);
    try {
      await Directory(outputDirectory).create(recursive: true);
      await File(
        _join(outputDirectory, 'local_formation_annotations.json'),
      ).writeAsString(codec.encode(annotations), flush: true);
      await File(
        _join(outputDirectory, 'profile_evaluation.json'),
      ).writeAsString(evaluationJson, flush: true);
      await File(
        _join(outputDirectory, 'profile_evaluation.csv'),
      ).writeAsString(evaluationCsv, flush: true);
      await File(
        _join(outputDirectory, 'research_summary.md'),
      ).writeAsString(summary, flush: true);
    } on FileSystemException {
      throw const FileSystemException(
        'LF-1 review outputs could not be written.',
      );
    }
  }

  static String _evaluationCsv(Lf1EvaluationReport report) {
    final rows = <String>[
      'profileId,deterministicAndComplete,candidateBudgetRate,'
          'annotationCoverageRate,residueCoverageRate,'
          'negativeSpaceCoverageRate,formationConsistencyRate,'
          'medianCandidateCount,passed',
      for (final profile in report.profiles)
        '${profile.profileId},${profile.deterministicAndComplete},'
            '${profile.candidateBudgetRate},${profile.annotationCoverageRate},'
            '${profile.residueCoverageRate},'
            '${profile.negativeSpaceCoverageRate},'
            '${profile.formationConsistencyRate},'
            '${profile.medianCandidateCount},${profile.passed}',
    ];
    return '${rows.join('\r\n')}\r\n';
  }

  static String _summary(Lf1EvaluationReport report) {
    final candidate = report.productionProfileCandidateId;
    final verdict = candidate == null
        ? 'NO PROFILE PASSED'
        : 'RESEARCH CANDIDATE: `$candidate`';
    return '''
# Atlas LF-1 Local Formation Profile Research

- Research ID: `${report.researchId}`
- Ground truth sufficient: `${report.groundTruthSufficient}`
- Included annotations: `${report.includedAnnotationCount}`
- Residue annotations: `${report.residueAnnotationCount}`
- Negative-space annotations: `${report.negativeSpaceAnnotationCount}`
- Eligible formation groups: `${report.eligibleFormationGroupCount}`
- Result: $verdict

The selected profile, if any, is a research candidate only. It is not frozen
and does not create semantic identity or evidence binding.
''';
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
  Map<String, Object?> object, {
  required Set<String> required,
  required String field,
}) {
  if (object.keys.toSet().difference(required).isNotEmpty ||
      required.difference(object.keys.toSet()).isNotEmpty) {
    throw FormatException('$field contains missing or unknown fields.');
  }
}

String _identifier(Object? value, String field) {
  final text = _string(value, field);
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(text)) {
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

T _enumValue<T extends Enum>(List<T> values, Object? value, String field) {
  final name = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  throw FormatException('$field contains an unsupported value.');
}

bool _same(Iterable<Object?> first, Iterable<Object?> second) {
  final firstList = first.toList(growable: false);
  final secondList = second.toList(growable: false);
  if (firstList.length != secondList.length) return false;
  for (var index = 0; index < firstList.length; index++) {
    if (firstList[index] != secondList[index]) return false;
  }
  return true;
}

void _rejectRepositoryOutput(String output, String repositoryRoot) {
  final outputPath = Directory(output).absolute.path.toLowerCase();
  final repositoryPath = Directory(repositoryRoot).absolute.path.toLowerCase();
  final prefix = repositoryPath.endsWith(Platform.pathSeparator)
      ? repositoryPath
      : '$repositoryPath${Platform.pathSeparator}';
  if (outputPath == repositoryPath || outputPath.startsWith(prefix)) {
    throw const FileSystemException(
      'LF-1 review output must remain outside the repository.',
    );
  }
}

String _join(String directory, String filename) {
  return [directory, filename].join(Platform.pathSeparator);
}
