import 'dart:convert';
import 'dart:io';

import 'validation_models.dart';

final class ValidationReportEncoder {
  const ValidationReportEncoder();

  String encodeJson(ValidationReport report) {
    return '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n';
  }

  String encodeCsv(ValidationReport report) {
    const headers = <String>[
      'sourceId',
      'relativePath',
      'surfaceType',
      'format',
      'enabled',
      'analysisStatus',
      'determinismStatus',
      'repeatsPerformed',
      'mismatchedRepeatIndexes',
      'workingImageWidth',
      'workingImageHeight',
      'workingResiduePixelCount',
      'workingContentResidueAreaRatio',
      'componentCount',
      'relationCount',
      'selectedEdgeCount',
      'graphNodeCount',
      'graphEdgeCount',
      'structureCount',
      'largestStructureSize',
      'isolatedStructureCount',
      'errorCategory',
      'errorMessage',
    ];
    final rows = <List<Object?>>[
      headers,
      for (final record in report.records)
        <Object?>[
          record.entry.sourceId,
          record.entry.relativePath,
          record.entry.surfaceType.name,
          record.entry.format.name,
          record.entry.enabled,
          record.analysisStatus.name,
          record.determinismStatus.name,
          record.repeatsPerformed,
          record.mismatchedRepeatIndexes.join('|'),
          record.metrics?.workingImageWidth,
          record.metrics?.workingImageHeight,
          record.metrics?.workingResiduePixelCount,
          record.metrics?.workingContentResidueAreaRatio,
          record.metrics?.componentCount,
          record.metrics?.relationCount,
          record.metrics?.selectedEdgeCount,
          record.metrics?.graphNodeCount,
          record.metrics?.graphEdgeCount,
          record.metrics?.structureCount,
          record.metrics?.largestStructureSize,
          record.metrics?.isolatedStructureCount,
          record.error?.category.name,
          record.error?.message,
        ],
    ];
    return '${rows.map(_encodeRow).join('\r\n')}\r\n';
  }

  String _encodeRow(List<Object?> values) {
    return values.map((value) => _escape(value?.toString() ?? '')).join(',');
  }

  String _escape(String value) {
    if (!value.contains(',') &&
        !value.contains('"') &&
        !value.contains('\r') &&
        !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}

Future<void> writeValidationReport(
  ValidationReport report,
  Directory outputDirectory,
) async {
  await outputDirectory.create(recursive: true);
  const encoder = ValidationReportEncoder();
  await File(
    '${outputDirectory.path}${Platform.pathSeparator}validation_report.json',
  ).writeAsString(encoder.encodeJson(report), flush: true);
  await File(
    '${outputDirectory.path}${Platform.pathSeparator}validation_summary.csv',
  ).writeAsString(encoder.encodeCsv(report), flush: true);
}
