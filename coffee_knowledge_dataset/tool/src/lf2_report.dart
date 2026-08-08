import 'dart:convert';
import 'dart:io';

import 'lf2_models.dart';
import 'lf2_profiles.dart';

final class Lf2ReportWriteException implements Exception {
  const Lf2ReportWriteException(this.message);

  final String message;

  @override
  String toString() => 'Lf2ReportWriteException: $message';
}

final class Lf2ReportWriter {
  const Lf2ReportWriter();

  Future<List<String>> write({
    required Lf2ObservationReport report,
    required String outputDirectory,
    required String repositoryRoot,
  }) async {
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    final directory = Directory(outputDirectory);
    final jsonPath = _join(outputDirectory, 'candidate_observations.json');
    final csvPath = _join(outputDirectory, 'candidate_observations.csv');
    final paths = [jsonPath, csvPath];
    if (paths.any((path) => File(path).existsSync())) {
      throw const Lf2ReportWriteException(
        'LF-2 observation outputs already exist; research runs are immutable.',
      );
    }
    try {
      await directory.create(recursive: true);
      await File(jsonPath).writeAsString(_encodeJson(report), flush: true);
      await File(csvPath).writeAsString(_encodeCsv(report), flush: true);
    } on FileSystemException {
      throw const Lf2ReportWriteException(
        'LF-2 observation outputs could not be written.',
      );
    }
    return List<String>.unmodifiable(paths);
  }

  static String _encodeJson(Lf2ObservationReport report) {
    final root = <String, Object?>{
      'schemaVersion': '1.0',
      'researchId': report.researchId,
      'sourceDatasetVersion': report.sourceDatasetVersion,
      'sourceManifestChecksum': report.sourceManifestChecksum,
      'workingResolution': report.workingResolution,
      'repeatCount': report.repeatCount,
      'profiles': report.profiles.map(_profileJson).toList(growable: false),
      'profileSummaries': report.profileSummaries
          .map(_summaryJson)
          .toList(growable: false),
      'observations': report.observations
          .map((observation) => _observationJson(report, observation))
          .toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
  }

  static Map<String, Object> _profileJson(Lf2ProfileDefinition profile) => {
    'profileId': profile.id,
    'closingRadius': profile.closingRadius,
    'minimumRegionRatio': profile.minimumRegionRatio,
  };

  static Map<String, Object> _summaryJson(Lf2ProfileSummary summary) => {
    'profileId': summary.profileId,
    'enabledImageCount': summary.enabledImageCount,
    'successfulImageCount': summary.successfulImageCount,
    'failedImageCount': summary.failedImageCount,
    'deterministicImageCount': summary.deterministicImageCount,
    'nonDeterministicImageCount': summary.nonDeterministicImageCount,
    'candidateBudgetImageCount': summary.candidateBudgetImageCount,
    'candidateBudgetRate': summary.candidateBudgetRate,
    'conservedImageCount': summary.conservedImageCount,
    'totalCandidateCount': summary.totalCandidateCount,
  };

  static Map<String, Object?> _observationJson(
    Lf2ObservationReport report,
    Lf2ProfileObservation observation,
  ) {
    final bounds = observation.contentBounds;
    return {
      'profileId': observation.profileId,
      'sourceId': observation.sourceId,
      'surfaceType': observation.surfaceType.name,
      'analysisStatus': observation.analysisStatus.name,
      'determinismStatus': observation.determinismStatus.name,
      'repeatsPerformed': observation.repeatsPerformed,
      'mismatchedRepeatIndexes': observation.mismatchedRepeatIndexes,
      'failureCategory': observation.failureCategory?.name,
      'contentBounds': bounds == null
          ? null
          : {
              'left': bounds.left / report.workingResolution,
              'top': bounds.top / report.workingResolution,
              'right': bounds.right / report.workingResolution,
              'bottom': bounds.bottom / report.workingResolution,
            },
      'residueConservation': {
        'originalResiduePixelCount': observation.originalResiduePixelCount,
        'assignedResiduePixelCount': observation.assignedResiduePixelCount,
        'emittedResiduePixelCount': observation.emittedResiduePixelCount,
        'suppressedResiduePixelCount': observation.suppressedResiduePixelCount,
        'duplicateResidueAssignmentCount':
            observation.duplicateResidueAssignmentCount,
        'conserved': observation.residuePixelsConserved,
      },
      'candidates': observation.candidates
          .map(
            (candidate) => _candidateJson(
              observation.profileId,
              observation.sourceId,
              candidate,
            ),
          )
          .toList(growable: false),
    };
  }

  static Map<String, Object> _candidateJson(
    String profileId,
    String sourceId,
    Lf2CandidateObservation candidate,
  ) => {
    'candidateId': candidate.candidateId,
    'candidateIdentity':
        '$profileId#$sourceId#${candidate.polarity.name}#'
        '${candidate.candidateId}',
    'polarity': candidate.polarity.name,
    'supportIdentity': candidate.supportIdentity,
    'minimumRowMajorPixelIndex': candidate.minimumRowMajorPixelIndex,
    'left': candidate.left,
    'top': candidate.top,
    'right': candidate.right,
    'bottom': candidate.bottom,
    'centroidX': candidate.centroidX,
    'centroidY': candidate.centroidY,
    'pixelCount': candidate.pixelCount,
    'areaRatio': candidate.areaRatio,
    'residueContactSectorCount': candidate.residueContactSectorCount,
    'pixelFingerprint': candidate.pixelFingerprint,
  };

  static String _encodeCsv(Lf2ObservationReport report) {
    final rows = <List<Object?>>[
      const [
        'profileId',
        'sourceId',
        'surfaceType',
        'analysisStatus',
        'determinismStatus',
        'repeatsPerformed',
        'failureCategory',
        'residuePixelsConserved',
        'candidateId',
        'candidateIdentity',
        'polarity',
        'supportIdentity',
        'minimumRowMajorPixelIndex',
        'left',
        'top',
        'right',
        'bottom',
        'centroidX',
        'centroidY',
        'pixelCount',
        'areaRatio',
        'residueContactSectorCount',
        'pixelFingerprint',
      ],
    ];
    for (final observation in report.observations) {
      if (observation.candidates.isEmpty) {
        rows.add(_row(observation, null));
      } else {
        for (final candidate in observation.candidates) {
          rows.add(_row(observation, candidate));
        }
      }
    }
    return '${rows.map((row) => row.map(_escape).join(',')).join('\r\n')}\r\n';
  }

  static List<Object?> _row(
    Lf2ProfileObservation observation,
    Lf2CandidateObservation? candidate,
  ) => [
    observation.profileId,
    observation.sourceId,
    observation.surfaceType.name,
    observation.analysisStatus.name,
    observation.determinismStatus.name,
    observation.repeatsPerformed,
    observation.failureCategory?.name,
    observation.residuePixelsConserved,
    candidate?.candidateId,
    candidate == null
        ? null
        : '${observation.profileId}#${observation.sourceId}#'
              '${candidate.polarity.name}#${candidate.candidateId}',
    candidate?.polarity.name,
    candidate?.supportIdentity,
    candidate?.minimumRowMajorPixelIndex,
    candidate?.left,
    candidate?.top,
    candidate?.right,
    candidate?.bottom,
    candidate?.centroidX,
    candidate?.centroidY,
    candidate?.pixelCount,
    candidate?.areaRatio,
    candidate?.residueContactSectorCount,
    candidate?.pixelFingerprint,
  ];

  static String _escape(Object? value) {
    if (value == null) return '';
    final text = value.toString();
    if (!text.contains(',') &&
        !text.contains('"') &&
        !text.contains('\r') &&
        !text.contains('\n')) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
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
      throw const Lf2ReportWriteException(
        'LF-2 research output must remain outside the repository.',
      );
    }
  }

  static String _join(String directory, String filename) =>
      [directory, filename].join(Platform.pathSeparator);
}
