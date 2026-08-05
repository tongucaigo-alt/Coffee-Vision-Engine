import 'dart:convert';
import 'dart:io';

import 'package:coffee_pattern/coffee_pattern.dart';

import 'lf1_models.dart';
import 'lf1_profiles.dart';

final class Lf1ReportWriteException implements Exception {
  const Lf1ReportWriteException(this.message);

  final String message;

  @override
  String toString() => 'Lf1ReportWriteException: $message';
}

final class Lf1ReportWriter {
  const Lf1ReportWriter();

  Future<List<String>> write({
    required Lf1ObservationReport report,
    required String outputDirectory,
    required String repositoryRoot,
  }) async {
    _rejectRepositoryOutput(outputDirectory, repositoryRoot);
    final directory = Directory(outputDirectory);
    final jsonPath = _join(outputDirectory, 'profile_observations.json');
    final csvPath = _join(outputDirectory, 'profile_observations.csv');
    final paths = [jsonPath, csvPath];
    if (paths.any((path) => File(path).existsSync())) {
      throw const Lf1ReportWriteException(
        'LF-1 observation outputs already exist; research runs are immutable.',
      );
    }

    try {
      await directory.create(recursive: true);
      await File(jsonPath).writeAsString(_encodeJson(report), flush: true);
      await File(csvPath).writeAsString(_encodeCsvReport(report), flush: true);
    } on FileSystemException {
      throw const Lf1ReportWriteException(
        'LF-1 observation outputs could not be written.',
      );
    }
    return List<String>.unmodifiable(paths);
  }

  static String _encodeJson(Lf1ObservationReport report) {
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
          .map(_observationJson)
          .toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
  }

  static Map<String, Object?> _profileJson(Lf1ProfileDefinition definition) {
    final profile = definition.profile;
    return {
      'profileId': definition.id,
      'maxCentroidDistance': profile.maxCentroidDistance,
      'maxBoundingBoxDistance': profile.maxBoundingBoxDistance,
      'requireBoundingBoxTouch': profile.requireBoundingBoxTouch,
      'maxOutgoingPerSource': profile.maxOutgoingPerSource,
    };
  }

  static Map<String, Object> _summaryJson(Lf1ProfileSummary summary) {
    return {
      'profileId': summary.profileId,
      'enabledImageCount': summary.enabledImageCount,
      'successfulImageCount': summary.successfulImageCount,
      'failedImageCount': summary.failedImageCount,
      'deterministicImageCount': summary.deterministicImageCount,
      'nonDeterministicImageCount': summary.nonDeterministicImageCount,
      'candidateBudgetImageCount': summary.candidateBudgetImageCount,
      'candidateBudgetRate': summary.candidateBudgetRate,
      'totalCandidateCount': summary.totalCandidateCount,
    };
  }

  static Map<String, Object?> _observationJson(
    Lf1ProfileObservation observation,
  ) {
    return {
      'profileId': observation.profileId,
      'sourceId': observation.sourceId,
      'surfaceType': observation.surfaceType.name,
      'analysisStatus': observation.analysisStatus.name,
      'determinismStatus': observation.determinismStatus.name,
      'repeatsPerformed': observation.repeatsPerformed,
      'mismatchedRepeatIndexes': observation.mismatchedRepeatIndexes,
      'failureCategory': observation.failureCategory?.name,
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
    Lf1CandidateObservation candidate,
  ) {
    final geometry = candidate.geometry;
    final topology = candidate.topology;
    return {
      'candidateId': candidate.candidateId,
      'candidateIdentity': '$profileId#$sourceId#${candidate.candidateId}',
      'evidence': candidate.evidence.map(_evidenceJson).toList(growable: false),
      'geometry': {
        'left': geometry.left,
        'top': geometry.top,
        'right': geometry.right,
        'bottom': geometry.bottom,
        'centroidX': geometry.centroidX,
        'centroidY': geometry.centroidY,
        'width': geometry.width,
        'height': geometry.height,
        'aspectRatio': geometry.aspectRatio,
        'touchesWorkingImageBorder': geometry.touchesWorkingImageBorder,
      },
      'topology': {
        'nodeCount': topology.nodeCount,
        'directedEdgeCount': topology.directedEdgeCount,
        'isIsolated': topology.isIsolated,
      },
    };
  }

  static Map<String, Object> _evidenceJson(PatternEvidence evidence) {
    return switch (evidence.kind) {
      PatternEvidenceKind.globalFeatures => {'kind': 'globalFeatures'},
      PatternEvidenceKind.regionFeature => {
        'kind': 'regionFeature',
        'regionId': evidence.regionId!.name,
      },
      PatternEvidenceKind.componentFeature => {
        'kind': 'componentFeature',
        'componentId': evidence.componentId!,
      },
      PatternEvidenceKind.spatialRelationFeature => {
        'kind': 'spatialRelationFeature',
        'sourceComponentId': evidence.sourceComponentId!,
        'targetComponentId': evidence.targetComponentId!,
      },
      PatternEvidenceKind.graphStatistics => {'kind': 'graphStatistics'},
      PatternEvidenceKind.connectedStructure => {
        'kind': 'connectedStructure',
        'structureId': evidence.structureId!,
      },
    };
  }

  static String _encodeCsvReport(Lf1ObservationReport report) {
    final rows = <List<Object?>>[
      const [
        'profileId',
        'sourceId',
        'surfaceType',
        'analysisStatus',
        'determinismStatus',
        'repeatsPerformed',
        'mismatchedRepeatIndexes',
        'failureCategory',
        'candidateId',
        'evidence',
        'geometryLeft',
        'geometryTop',
        'geometryRight',
        'geometryBottom',
        'geometryCentroidX',
        'geometryCentroidY',
        'geometryWidth',
        'geometryHeight',
        'geometryAspectRatio',
        'geometryTouchesWorkingImageBorder',
        'topologyNodeCount',
        'topologyDirectedEdgeCount',
        'topologyIsIsolated',
      ],
    ];
    for (final observation in report.observations) {
      if (observation.candidates.isEmpty) {
        rows.add(_observationRow(observation, null));
      } else {
        for (final candidate in observation.candidates) {
          rows.add(_observationRow(observation, candidate));
        }
      }
    }
    return _encodeCsv(rows);
  }

  static List<Object?> _observationRow(
    Lf1ProfileObservation observation,
    Lf1CandidateObservation? candidate,
  ) {
    final geometry = candidate?.geometry;
    final topology = candidate?.topology;
    return [
      observation.profileId,
      observation.sourceId,
      observation.surfaceType.name,
      observation.analysisStatus.name,
      observation.determinismStatus.name,
      observation.repeatsPerformed,
      observation.mismatchedRepeatIndexes.join(';'),
      observation.failureCategory?.name,
      candidate?.candidateId,
      candidate?.evidence.map(_evidenceIdentity).join(';'),
      geometry?.left,
      geometry?.top,
      geometry?.right,
      geometry?.bottom,
      geometry?.centroidX,
      geometry?.centroidY,
      geometry?.width,
      geometry?.height,
      geometry?.aspectRatio,
      geometry?.touchesWorkingImageBorder,
      topology?.nodeCount,
      topology?.directedEdgeCount,
      topology?.isIsolated,
    ];
  }

  static String _evidenceIdentity(PatternEvidence evidence) {
    return switch (evidence.kind) {
      PatternEvidenceKind.globalFeatures => 'globalFeatures',
      PatternEvidenceKind.regionFeature =>
        'regionFeature:${evidence.regionId!.name}',
      PatternEvidenceKind.componentFeature =>
        'componentFeature:${evidence.componentId}',
      PatternEvidenceKind.spatialRelationFeature =>
        'spatialRelationFeature:${evidence.sourceComponentId}'
            '>${evidence.targetComponentId}',
      PatternEvidenceKind.graphStatistics => 'graphStatistics',
      PatternEvidenceKind.connectedStructure =>
        'connectedStructure:${evidence.structureId}',
    };
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
      throw const Lf1ReportWriteException(
        'LF-1 research output must remain outside the repository.',
      );
    }
  }

  static String _encodeCsv(List<List<Object?>> rows) {
    return '${rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n')}'
        '\r\n';
  }

  static String _escapeCsv(Object? value) {
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

  static String _join(String directory, String filename) {
    return [directory, filename].join(Platform.pathSeparator);
  }
}
