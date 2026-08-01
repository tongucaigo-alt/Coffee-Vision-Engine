import 'dart:convert';
import 'dart:io';

import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:crypto/crypto.dart';

import 'k6a_models.dart';

final class K6aReportWriteException implements Exception {
  const K6aReportWriteException(this.message);

  final String message;

  @override
  String toString() => 'K6aReportWriteException: $message';
}

final class K6aReportWriter {
  const K6aReportWriter();

  Future<List<String>> write({
    required K6aObservationReport report,
    required String outputDirectory,
  }) async {
    final directory = Directory(outputDirectory);
    final jsonPath = _join(outputDirectory, 'pattern_observations.json');
    final csvPath = _join(outputDirectory, 'pattern_observations.csv');
    final cohortPath = _join(outputDirectory, 'cohort_review.csv');
    final authoringPath = _join(outputDirectory, 'record_authoring_review.csv');
    final summaryPath = _join(outputDirectory, 'research_summary.md');
    final paths = [jsonPath, csvPath, cohortPath, authoringPath, summaryPath];
    if (paths.any((path) => File(path).existsSync())) {
      throw const K6aReportWriteException(
        'K6A output files already exist; existing research is immutable.',
      );
    }

    final jsonSource = _encodeJson(report);
    final csvSource = _encodeObservationCsv(report);
    final cohortSource = _encodeCohortCsv(report);
    const authoringSource =
        'cohortId,knowledgeRecordId,selectedConstraintKeys,'
        'approvalStatus,notes\r\n';
    final summarySource = _encodeSummary(
      report: report,
      jsonChecksum: _checksum(jsonSource),
      csvChecksum: _checksum(csvSource),
      cohortChecksum: _checksum(cohortSource),
      authoringChecksum: _checksum(authoringSource),
    );

    try {
      await directory.create(recursive: true);
      await File(jsonPath).writeAsString(jsonSource, flush: true);
      await File(csvPath).writeAsString(csvSource, flush: true);
      await File(cohortPath).writeAsString(cohortSource, flush: true);
      await File(authoringPath).writeAsString(authoringSource, flush: true);
      await File(summaryPath).writeAsString(summarySource, flush: true);
    } on FileSystemException {
      throw const K6aReportWriteException(
        'K6A research outputs could not be written.',
      );
    }
    return List<String>.unmodifiable(paths);
  }

  static String _encodeJson(K6aObservationReport report) {
    final root = <String, Object?>{
      'schemaVersion': '1.0',
      'researchId': report.researchId,
      'sourceDatasetVersion': report.sourceDatasetVersion,
      'sourceManifestChecksum': report.sourceManifestChecksum,
      'repeatCount': report.repeatCount,
      'summary': _summaryJson(report.summary),
      'records': report.records.map(_recordJson).toList(growable: false),
    };
    return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
  }

  static Map<String, Object> _summaryJson(K6aObservationSummary summary) {
    return {
      'totalEntries': summary.totalEntries,
      'enabledEntries': summary.enabledEntries,
      'disabledEntries': summary.disabledEntries,
      'successfulEntries': summary.successfulEntries,
      'failedEntries': summary.failedEntries,
      'deterministicEntries': summary.deterministicEntries,
      'nonDeterministicEntries': summary.nonDeterministicEntries,
      'cupEntries': summary.cupEntries,
      'saucerEntries': summary.saucerEntries,
      'candidateCount': summary.candidateCount,
      'cupCandidateCount': summary.cupCandidateCount,
      'saucerCandidateCount': summary.saucerCandidateCount,
    };
  }

  static Map<String, Object?> _recordJson(K6aImageObservation record) {
    return {
      'sourceId': record.sourceId,
      'surfaceType': record.surfaceType.name,
      'analysisStatus': record.analysisStatus.name,
      'determinismStatus': record.determinismStatus.name,
      'repeatsPerformed': record.repeatsPerformed,
      'mismatchedRepeatIndexes': record.mismatchedRepeatIndexes,
      'candidates': record.candidates
          .map(_candidateJson)
          .toList(growable: false),
      'errorCategory': record.failureCategory?.name,
    };
  }

  static Map<String, Object> _candidateJson(K6aCandidateObservation candidate) {
    final geometry = candidate.geometry;
    final topology = candidate.topology;
    return {
      'candidateId': candidate.candidateId,
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

  static String _encodeObservationCsv(K6aObservationReport report) {
    const header = [
      'sourceId',
      'surfaceType',
      'analysisStatus',
      'determinismStatus',
      'repeatsPerformed',
      'mismatchedRepeatIndexes',
      'errorCategory',
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
    ];
    final rows = <List<Object?>>[header];
    for (final record in report.records) {
      if (record.candidates.isEmpty) {
        rows.add(_observationRow(record, null));
      } else {
        for (final candidate in record.candidates) {
          rows.add(_observationRow(record, candidate));
        }
      }
    }
    return _encodeCsv(rows);
  }

  static List<Object?> _observationRow(
    K6aImageObservation record,
    K6aCandidateObservation? candidate,
  ) {
    final geometry = candidate?.geometry;
    final topology = candidate?.topology;
    return [
      record.sourceId,
      record.surfaceType.name,
      record.analysisStatus.name,
      record.determinismStatus.name,
      record.repeatsPerformed,
      record.mismatchedRepeatIndexes.join(';'),
      record.failureCategory?.name,
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

  static String _encodeCohortCsv(K6aObservationReport report) {
    final rows = <List<Object?>>[
      const [
        'observationId',
        'sourceId',
        'candidateId',
        'surfaceType',
        'captureGroupId',
        'cohortId',
        'reviewStatus',
        'notes',
      ],
    ];
    for (final record in report.records) {
      for (final candidate in record.candidates) {
        rows.add([
          '${record.sourceId}#${candidate.candidateId}',
          record.sourceId,
          candidate.candidateId,
          record.surfaceType.name,
          '',
          '',
          '',
          '',
        ]);
      }
    }
    return _encodeCsv(rows);
  }

  static String _encodeSummary({
    required K6aObservationReport report,
    required String jsonChecksum,
    required String csvChecksum,
    required String cohortChecksum,
    required String authoringChecksum,
  }) {
    final summary = report.summary;
    final status = report.succeeded ? 'PASS' : 'REVIEW REQUIRED';
    return '''
# Atlas K6A Physical Observation Research

- Research ID: `${report.researchId}`
- Source dataset: `${report.sourceDatasetVersion}`
- Source manifest SHA-256: `${report.sourceManifestChecksum}`
- Repeat count: `${report.repeatCount}`
- Run status: `$status`

## Coverage

| Item | Count |
|---|---:|
| Manifest entries | ${summary.totalEntries} |
| Enabled images | ${summary.enabledEntries} |
| Disabled images | ${summary.disabledEntries} |
| Successful images | ${summary.successfulEntries} |
| Failed images | ${summary.failedEntries} |
| Deterministic images | ${summary.deterministicEntries} |
| Non-deterministic images | ${summary.nonDeterministicEntries} |
| Cup images | ${summary.cupEntries} |
| Saucer images | ${summary.saucerEntries} |
| Total Pattern candidates | ${summary.candidateCount} |
| Cup Pattern candidates | ${summary.cupCandidateCount} |
| Saucer Pattern candidates | ${summary.saucerCandidateCount} |

## Artefact Integrity

- `pattern_observations.json`: `$jsonChecksum`
- `pattern_observations.csv`: `$csvChecksum`
- `cohort_review.csv`: `$cohortChecksum`
- `record_authoring_review.csv`: `$authoringChecksum`

## Scope

- Measurements come only from public `VisionFeatureSet` and `PatternAnalysisResult` contracts.
- No cohort has been approved.
- No `KnowledgeRecord` has been authored.
- No `kds-001` dataset or freeze has been created.
- Image files and M5B baseline artefacts were not modified.
''';
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

  static String _checksum(String source) {
    return 'sha256:${sha256.convert(utf8.encode(source))}';
  }

  static String _join(String directory, String filename) {
    return [directory, filename].join(Platform.pathSeparator);
  }
}
