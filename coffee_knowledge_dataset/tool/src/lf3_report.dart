import 'dart:convert';
import 'dart:io';

import 'k6a_models.dart';
import 'lf2_models.dart';
import 'lf3_models.dart';
import 'lf3_profiles.dart';

final class Lf3ReportWriteException implements Exception {
  const Lf3ReportWriteException(this.message);

  final String message;

  @override
  String toString() => 'Lf3ReportWriteException: $message';
}

final class Lf3ReportWriter {
  const Lf3ReportWriter();

  Future<List<String>> write({
    required Lf3ObservationReport report,
    required String outputDirectory,
    required String repositoryRoot,
  }) async {
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    final directory = Directory(outputDirectory);
    final paths = <String>[
      _join(outputDirectory, 'candidate_observations.json'),
      _join(outputDirectory, 'candidate_observations.csv'),
      _join(outputDirectory, 'evidence_observations.json'),
      _join(outputDirectory, 'evidence_observations.csv'),
    ];
    if (paths.any((path) => File(path).existsSync())) {
      throw const Lf3ReportWriteException(
        'LF-3 observation outputs already exist; research runs are immutable.',
      );
    }
    try {
      await directory.create(recursive: true);
      await File(
        paths[0],
      ).writeAsString(_encodeCandidateJson(report), flush: true);
      await File(
        paths[1],
      ).writeAsString(_encodeCandidateCsv(report), flush: true);
      await File(
        paths[2],
      ).writeAsString(_encodeEvidenceJson(report), flush: true);
      await File(
        paths[3],
      ).writeAsString(_encodeEvidenceCsv(report), flush: true);
    } on FileSystemException {
      throw const Lf3ReportWriteException(
        'LF-3 observation outputs could not be written.',
      );
    }
    return List<String>.unmodifiable(paths);
  }

  static String _encodeCandidateJson(Lf3ObservationReport report) {
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

  static Map<String, Object?> _profileJson(Lf3ProfileDefinition profile) => {
    'profileId': profile.id,
    'evidenceKind': profile.evidenceKind.name,
    'supportRequired': profile.supportRequired,
    'threshold': profile.threshold,
    'closingRadius': profile.closingRadius,
    'minimumRegionRatio': profile.minimumRegionRatio,
  };

  static Map<String, Object> _summaryJson(Lf3ProfileSummary summary) => {
    'profileId': summary.profileId,
    'enabledImageCount': summary.enabledImageCount,
    'successfulImageCount': summary.successfulImageCount,
    'failedImageCount': summary.failedImageCount,
    'deterministicImageCount': summary.deterministicImageCount,
    'nonDeterministicImageCount': summary.nonDeterministicImageCount,
    'candidateBudgetImageCount': summary.candidateBudgetImageCount,
    'candidateBudgetRate': summary.candidateBudgetRate,
    'conservedImageCount': summary.conservedImageCount,
    'supportAvailableImageCount': summary.supportAvailableImageCount,
    'totalCandidateCount': summary.totalCandidateCount,
  };

  static Map<String, Object?> _observationJson(
    Lf3ObservationReport report,
    Lf3ProfileObservation observation,
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

  static String _encodeCandidateCsv(Lf3ObservationReport report) {
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
        rows.add(_candidateRow(observation, null));
      } else {
        for (final candidate in observation.candidates) {
          rows.add(_candidateRow(observation, candidate));
        }
      }
    }
    return _encodeRows(rows);
  }

  static List<Object?> _candidateRow(
    Lf3ProfileObservation observation,
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

  static String _encodeEvidenceJson(Lf3ObservationReport report) {
    final root = <String, Object?>{
      'schemaVersion': '1.0',
      'researchId': report.researchId,
      'sourceDatasetVersion': report.sourceDatasetVersion,
      'sourceManifestChecksum': report.sourceManifestChecksum,
      'workingResolution': report.workingResolution,
      'repeatCount': report.repeatCount,
      'surfaceSummaries': _surfaceSummaries(report),
      'observations': report.observations
          .map(_evidenceJson)
          .toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
  }

  static Map<String, Object?> _evidenceJson(Lf3ProfileObservation observation) {
    final support = observation.support;
    return {
      'profileId': observation.profileId,
      'sourceId': observation.sourceId,
      'surfaceType': observation.surfaceType.name,
      'evidenceKind': observation.profile.evidenceKind.name,
      'threshold': observation.profile.threshold,
      'supportRequired': observation.profile.supportRequired,
      'supportAvailable': support != null,
      'support': support == null
          ? null
          : {
              'centerX': support.centerX,
              'centerY': support.centerY,
              'radiusX': support.radiusX,
              'radiusY': support.radiusY,
              'visibleSampleCount': support.visibleSampleCount,
              'edgeSampleCount': support.edgeSampleCount,
              'edgeContinuity': support.edgeContinuity,
              'meanBoundaryContrast': support.meanBoundaryContrast,
              'pixelCount': support.pixelCount,
            },
      'inputEvidencePixelCount': observation.inputEvidencePixelCount,
      'candidateCount': observation.candidates.length,
      'analysisStatus': observation.analysisStatus.name,
      'failureCategory': observation.failureCategory?.name,
    };
  }

  static List<Map<String, Object>> _surfaceSummaries(
    Lf3ObservationReport report,
  ) {
    final summaries = <Map<String, Object>>[];
    for (final profile in report.profiles) {
      for (final surface in K6aSurfaceType.values) {
        final observations = report.observations
            .where(
              (observation) =>
                  observation.profileId == profile.id &&
                  observation.surfaceType == surface,
            )
            .toList(growable: false);
        final successful = observations
            .where(
              (observation) =>
                  observation.analysisStatus == K6aAnalysisStatus.success,
            )
            .toList(growable: false);
        summaries.add({
          'profileId': profile.id,
          'surfaceType': surface.name,
          'imageCount': observations.length,
          'successfulImageCount': successful.length,
          'supportAvailableImageCount': observations
              .where((observation) => observation.support != null)
              .length,
          'candidateBudgetImageCount': successful
              .where(
                (observation) =>
                    observation.candidates.isNotEmpty &&
                    observation.candidates.length <= 12,
              )
              .length,
          'totalCandidateCount': successful.fold<int>(
            0,
            (total, observation) => total + observation.candidates.length,
          ),
        });
      }
    }
    return summaries;
  }

  static String _encodeEvidenceCsv(Lf3ObservationReport report) {
    final rows = <List<Object?>>[
      const [
        'profileId',
        'sourceId',
        'surfaceType',
        'evidenceKind',
        'threshold',
        'supportRequired',
        'supportAvailable',
        'supportCenterX',
        'supportCenterY',
        'supportRadiusX',
        'supportRadiusY',
        'supportVisibleSampleCount',
        'supportEdgeSampleCount',
        'supportEdgeContinuity',
        'supportMeanBoundaryContrast',
        'supportPixelCount',
        'inputEvidencePixelCount',
        'candidateCount',
        'analysisStatus',
        'failureCategory',
      ],
    ];
    for (final observation in report.observations) {
      final support = observation.support;
      rows.add([
        observation.profileId,
        observation.sourceId,
        observation.surfaceType.name,
        observation.profile.evidenceKind.name,
        observation.profile.threshold,
        observation.profile.supportRequired,
        support != null,
        support?.centerX,
        support?.centerY,
        support?.radiusX,
        support?.radiusY,
        support?.visibleSampleCount,
        support?.edgeSampleCount,
        support?.edgeContinuity,
        support?.meanBoundaryContrast,
        support?.pixelCount,
        observation.inputEvidencePixelCount,
        observation.candidates.length,
        observation.analysisStatus.name,
        observation.failureCategory?.name,
      ]);
    }
    return _encodeRows(rows);
  }

  static String _encodeRows(List<List<Object?>> rows) =>
      '${rows.map((row) => row.map(_escape).join(',')).join('\r\n')}\r\n';

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
      throw const Lf3ReportWriteException(
        'LF-3 research output must remain outside the repository.',
      );
    }
  }

  static String _join(String directory, String filename) =>
      [directory, filename].join(Platform.pathSeparator);
}
