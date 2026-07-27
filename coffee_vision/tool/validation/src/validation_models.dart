import 'package:coffee_vision/coffee_vision.dart';

enum ValidationAnalysisStatus { success, failed, skippedDisabled }

enum ValidationDeterminismStatus { deterministic, nonDeterministic, notRun }

enum ValidationErrorCategory {
  fileNotFound,
  fileReadFailure,
  checksumMismatch,
  manifestInvalid,
  unsupportedImage,
  corruptedImage,
  pipelineFailure,
  nonDeterministicResult,
  reportWriteFailure,
}

final class ValidationDatasetEntry {
  const ValidationDatasetEntry({
    required this.sourceId,
    required this.relativePath,
    required this.surfaceType,
    required this.format,
    required this.ownership,
    required this.consent,
    required this.enabled,
    required this.contentChecksum,
  });

  final String sourceId;
  final String relativePath;
  final VisionSurfaceType surfaceType;
  final VisionImageFormat format;
  final String ownership;
  final String consent;
  final bool enabled;
  final String contentChecksum;

  Map<String, Object?> toJson() => <String, Object?>{
    'sourceId': sourceId,
    'relativePath': relativePath,
    'surfaceType': surfaceType.name,
    'format': format.name,
    'ownership': ownership,
    'consent': consent,
    'enabled': enabled,
    'contentChecksum': contentChecksum,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidationDatasetEntry &&
            other.sourceId == sourceId &&
            other.relativePath == relativePath &&
            other.surfaceType == surfaceType &&
            other.format == format &&
            other.ownership == ownership &&
            other.consent == consent &&
            other.enabled == enabled &&
            other.contentChecksum == contentChecksum;
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    relativePath,
    surfaceType,
    format,
    ownership,
    consent,
    enabled,
    contentChecksum,
  );
}

final class ValidationImageMetrics {
  ValidationImageMetrics({
    required this.surfaceType,
    required this.sourceId,
    required this.workingImageWidth,
    required this.workingImageHeight,
    required this.workingResiduePixelCount,
    required this.workingContentResidueAreaRatio,
    required this.componentCount,
    required this.relationCount,
    required this.selectedEdgeCount,
    required this.graphNodeCount,
    required this.graphEdgeCount,
    required this.structureCount,
    required this.largestStructureSize,
    required this.isolatedStructureCount,
  }) {
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    _requirePositive(workingImageWidth, 'workingImageWidth');
    _requirePositive(workingImageHeight, 'workingImageHeight');
    _requireNonNegative(workingResiduePixelCount, 'workingResiduePixelCount');
    if (!workingContentResidueAreaRatio.isFinite ||
        workingContentResidueAreaRatio < 0.0 ||
        workingContentResidueAreaRatio > 1.0) {
      throw ArgumentError.value(
        workingContentResidueAreaRatio,
        'workingContentResidueAreaRatio',
        'must be finite and between 0.0 and 1.0',
      );
    }
    _requireNonNegative(componentCount, 'componentCount');
    _requireNonNegative(relationCount, 'relationCount');
    _requireNonNegative(selectedEdgeCount, 'selectedEdgeCount');
    _requireNonNegative(graphNodeCount, 'graphNodeCount');
    _requireNonNegative(graphEdgeCount, 'graphEdgeCount');
    _requireNonNegative(structureCount, 'structureCount');
    _requireNonNegative(largestStructureSize, 'largestStructureSize');
    _requireNonNegative(isolatedStructureCount, 'isolatedStructureCount');
  }

  final VisionSurfaceType surfaceType;
  final String sourceId;
  final int workingImageWidth;
  final int workingImageHeight;
  final int workingResiduePixelCount;
  final double workingContentResidueAreaRatio;
  final int componentCount;
  final int relationCount;
  final int selectedEdgeCount;
  final int graphNodeCount;
  final int graphEdgeCount;
  final int structureCount;
  final int largestStructureSize;
  final int isolatedStructureCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'surfaceType': surfaceType.name,
    'sourceId': sourceId,
    'workingImageWidth': workingImageWidth,
    'workingImageHeight': workingImageHeight,
    'workingResiduePixelCount': workingResiduePixelCount,
    'workingContentResidueAreaRatio': workingContentResidueAreaRatio,
    'componentCount': componentCount,
    'relationCount': relationCount,
    'selectedEdgeCount': selectedEdgeCount,
    'graphNodeCount': graphNodeCount,
    'graphEdgeCount': graphEdgeCount,
    'structureCount': structureCount,
    'largestStructureSize': largestStructureSize,
    'isolatedStructureCount': isolatedStructureCount,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidationImageMetrics &&
            other.surfaceType == surfaceType &&
            other.sourceId == sourceId &&
            other.workingImageWidth == workingImageWidth &&
            other.workingImageHeight == workingImageHeight &&
            other.workingResiduePixelCount == workingResiduePixelCount &&
            other.workingContentResidueAreaRatio ==
                workingContentResidueAreaRatio &&
            other.componentCount == componentCount &&
            other.relationCount == relationCount &&
            other.selectedEdgeCount == selectedEdgeCount &&
            other.graphNodeCount == graphNodeCount &&
            other.graphEdgeCount == graphEdgeCount &&
            other.structureCount == structureCount &&
            other.largestStructureSize == largestStructureSize &&
            other.isolatedStructureCount == isolatedStructureCount;
  }

  @override
  int get hashCode => Object.hash(
    surfaceType,
    sourceId,
    workingImageWidth,
    workingImageHeight,
    workingResiduePixelCount,
    workingContentResidueAreaRatio,
    componentCount,
    relationCount,
    selectedEdgeCount,
    graphNodeCount,
    graphEdgeCount,
    structureCount,
    largestStructureSize,
    isolatedStructureCount,
  );
}

final class ValidationErrorRecord {
  ValidationErrorRecord({
    required this.category,
    this.sourceId,
    required this.message,
    Iterable<int> repeatIndexes = const <int>[],
  }) : repeatIndexes = List<int>.unmodifiable(
         _validatedIndexes(repeatIndexes),
       ) {
    if (sourceId != null && sourceId!.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'must not be empty');
    }
  }

  final ValidationErrorCategory category;
  final String? sourceId;
  final String message;
  final List<int> repeatIndexes;

  Map<String, Object?> toJson() => <String, Object?>{
    'category': category.name,
    'sourceId': sourceId,
    'message': message,
    'repeatIndexes': repeatIndexes,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidationErrorRecord &&
            other.category == category &&
            other.sourceId == sourceId &&
            other.message == message &&
            _sameList(other.repeatIndexes, repeatIndexes);
  }

  @override
  int get hashCode =>
      Object.hash(category, sourceId, message, Object.hashAll(repeatIndexes));
}

final class ValidationImageRecord {
  ValidationImageRecord({
    required this.entry,
    required this.analysisStatus,
    required this.determinismStatus,
    required this.repeatsPerformed,
    this.metrics,
    this.error,
    Iterable<int> mismatchedRepeatIndexes = const <int>[],
  }) : mismatchedRepeatIndexes = List<int>.unmodifiable(
         _validatedIndexes(mismatchedRepeatIndexes),
       ) {
    if (repeatsPerformed < 0) {
      throw ArgumentError.value(
        repeatsPerformed,
        'repeatsPerformed',
        'must not be negative',
      );
    }
    switch (analysisStatus) {
      case ValidationAnalysisStatus.skippedDisabled:
        if (entry.enabled ||
            repeatsPerformed != 0 ||
            determinismStatus != ValidationDeterminismStatus.notRun ||
            metrics != null ||
            error != null ||
            this.mismatchedRepeatIndexes.isNotEmpty) {
          throw ArgumentError(
            'A disabled record must be skipped without output.',
          );
        }
        break;
      case ValidationAnalysisStatus.failed:
        if (error == null ||
            metrics != null ||
            determinismStatus != ValidationDeterminismStatus.notRun ||
            this.mismatchedRepeatIndexes.isNotEmpty) {
          throw ArgumentError('A failed record must contain only an error.');
        }
        break;
      case ValidationAnalysisStatus.success:
        if (!entry.enabled || metrics == null || repeatsPerformed <= 0) {
          throw ArgumentError(
            'A successful record requires metrics and repeats.',
          );
        }
        if (determinismStatus == ValidationDeterminismStatus.deterministic &&
            (error != null || this.mismatchedRepeatIndexes.isNotEmpty)) {
          throw ArgumentError(
            'A deterministic record cannot contain differences.',
          );
        }
        if (determinismStatus == ValidationDeterminismStatus.nonDeterministic &&
            (error?.category !=
                    ValidationErrorCategory.nonDeterministicResult ||
                this.mismatchedRepeatIndexes.isEmpty)) {
          throw ArgumentError(
            'A non-deterministic record requires mismatch indexes and error.',
          );
        }
        if (determinismStatus == ValidationDeterminismStatus.notRun) {
          throw ArgumentError(
            'A successful record requires determinism status.',
          );
        }
        break;
    }
  }

  final ValidationDatasetEntry entry;
  final ValidationAnalysisStatus analysisStatus;
  final ValidationDeterminismStatus determinismStatus;
  final int repeatsPerformed;
  final ValidationImageMetrics? metrics;
  final ValidationErrorRecord? error;
  final List<int> mismatchedRepeatIndexes;

  Map<String, Object?> toJson() => <String, Object?>{
    'entry': entry.toJson(),
    'analysisStatus': analysisStatus.name,
    'determinismStatus': determinismStatus.name,
    'repeatsPerformed': repeatsPerformed,
    'mismatchedRepeatIndexes': mismatchedRepeatIndexes,
    'metrics': metrics?.toJson(),
    'error': error?.toJson(),
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidationImageRecord &&
            other.entry == entry &&
            other.analysisStatus == analysisStatus &&
            other.determinismStatus == determinismStatus &&
            other.repeatsPerformed == repeatsPerformed &&
            other.metrics == metrics &&
            other.error == error &&
            _sameList(other.mismatchedRepeatIndexes, mismatchedRepeatIndexes);
  }

  @override
  int get hashCode => Object.hash(
    entry,
    analysisStatus,
    determinismStatus,
    repeatsPerformed,
    metrics,
    error,
    Object.hashAll(mismatchedRepeatIndexes),
  );
}

final class ValidationRunSummary {
  const ValidationRunSummary({
    required this.entryCount,
    required this.enabledEntryCount,
    required this.skippedEntryCount,
    required this.successfulAnalysisCount,
    required this.failedAnalysisCount,
    required this.deterministicCount,
    required this.nonDeterministicCount,
  });

  factory ValidationRunSummary.fromRecords(
    Iterable<ValidationImageRecord> records,
  ) {
    final values = records.toList(growable: false);
    return ValidationRunSummary(
      entryCount: values.length,
      enabledEntryCount: values.where((record) => record.entry.enabled).length,
      skippedEntryCount: values
          .where(
            (record) =>
                record.analysisStatus ==
                ValidationAnalysisStatus.skippedDisabled,
          )
          .length,
      successfulAnalysisCount: values
          .where(
            (record) =>
                record.analysisStatus == ValidationAnalysisStatus.success,
          )
          .length,
      failedAnalysisCount: values
          .where(
            (record) =>
                record.analysisStatus == ValidationAnalysisStatus.failed,
          )
          .length,
      deterministicCount: values
          .where(
            (record) =>
                record.determinismStatus ==
                ValidationDeterminismStatus.deterministic,
          )
          .length,
      nonDeterministicCount: values
          .where(
            (record) =>
                record.determinismStatus ==
                ValidationDeterminismStatus.nonDeterministic,
          )
          .length,
    );
  }

  final int entryCount;
  final int enabledEntryCount;
  final int skippedEntryCount;
  final int successfulAnalysisCount;
  final int failedAnalysisCount;
  final int deterministicCount;
  final int nonDeterministicCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'entryCount': entryCount,
    'enabledEntryCount': enabledEntryCount,
    'skippedEntryCount': skippedEntryCount,
    'successfulAnalysisCount': successfulAnalysisCount,
    'failedAnalysisCount': failedAnalysisCount,
    'deterministicCount': deterministicCount,
    'nonDeterministicCount': nonDeterministicCount,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidationRunSummary &&
            other.entryCount == entryCount &&
            other.enabledEntryCount == enabledEntryCount &&
            other.skippedEntryCount == skippedEntryCount &&
            other.successfulAnalysisCount == successfulAnalysisCount &&
            other.failedAnalysisCount == failedAnalysisCount &&
            other.deterministicCount == deterministicCount &&
            other.nonDeterministicCount == nonDeterministicCount;
  }

  @override
  int get hashCode => Object.hash(
    entryCount,
    enabledEntryCount,
    skippedEntryCount,
    successfulAnalysisCount,
    failedAnalysisCount,
    deterministicCount,
    nonDeterministicCount,
  );
}

final class ValidationReport {
  factory ValidationReport({
    required String packageVersion,
    required int repeatCount,
    required int workingResolution,
    required Iterable<ValidationImageRecord> records,
    Iterable<ValidationErrorRecord> runErrors = const <ValidationErrorRecord>[],
  }) {
    if (packageVersion.trim().isEmpty) {
      throw ArgumentError.value(
        packageVersion,
        'packageVersion',
        'must not be empty',
      );
    }
    _requirePositive(repeatCount, 'repeatCount');
    _requirePositive(workingResolution, 'workingResolution');
    final recordList = List<ValidationImageRecord>.unmodifiable(records);
    final runErrorList = List<ValidationErrorRecord>.unmodifiable(runErrors);
    return ValidationReport._(
      packageVersion: packageVersion,
      repeatCount: repeatCount,
      workingResolution: workingResolution,
      records: recordList,
      runErrors: runErrorList,
      overallSummary: ValidationRunSummary.fromRecords(recordList),
      cupSummary: ValidationRunSummary.fromRecords(
        recordList.where(
          (record) => record.entry.surfaceType == VisionSurfaceType.cup,
        ),
      ),
      saucerSummary: ValidationRunSummary.fromRecords(
        recordList.where(
          (record) => record.entry.surfaceType == VisionSurfaceType.saucer,
        ),
      ),
    );
  }

  const ValidationReport._({
    required this.packageVersion,
    required this.repeatCount,
    required this.workingResolution,
    required this.records,
    required this.runErrors,
    required this.overallSummary,
    required this.cupSummary,
    required this.saucerSummary,
  });

  static const schemaVersion = '1.0';
  static const milestone = 'Atlas M5A';
  static const packageName = 'coffee_vision';

  final String packageVersion;
  final int repeatCount;
  final int workingResolution;
  final List<ValidationImageRecord> records;
  final List<ValidationErrorRecord> runErrors;
  final ValidationRunSummary overallSummary;
  final ValidationRunSummary cupSummary;
  final ValidationRunSummary saucerSummary;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'milestone': milestone,
    'packageName': packageName,
    'packageVersion': packageVersion,
    'repeatCount': repeatCount,
    'config': <String, Object?>{'workingResolution': workingResolution},
    'summary': <String, Object?>{
      'overall': overallSummary.toJson(),
      'cup': cupSummary.toJson(),
      'saucer': saucerSummary.toJson(),
    },
    'runErrors': runErrors.map((error) => error.toJson()).toList(),
    'records': records.map((record) => record.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidationReport &&
            other.packageVersion == packageVersion &&
            other.repeatCount == repeatCount &&
            other.workingResolution == workingResolution &&
            _sameList(other.records, records) &&
            _sameList(other.runErrors, runErrors);
  }

  @override
  int get hashCode => Object.hash(
    packageVersion,
    repeatCount,
    workingResolution,
    Object.hashAll(records),
    Object.hashAll(runErrors),
  );
}

final class ValidationRunOutcome {
  const ValidationRunOutcome({
    required this.exitCode,
    required this.report,
    this.reportWriteError,
  });

  final int exitCode;
  final ValidationReport report;
  final ValidationErrorRecord? reportWriteError;
}

void _requirePositive(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be greater than zero');
  }
}

void _requireNonNegative(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must not be negative');
  }
}

List<int> _validatedIndexes(Iterable<int> values) {
  final result = values.toList()..sort();
  final seen = <int>{};
  for (final value in result) {
    if (value <= 0 || !seen.add(value)) {
      throw ArgumentError.value(
        value,
        'repeatIndexes',
        'must contain unique positive indexes',
      );
    }
  }
  return result;
}

bool _sameList<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
