import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';

import 'content_checksum.dart';
import 'validation_manifest_parser.dart';
import 'validation_metric_extractor.dart';
import 'validation_models.dart';
import 'validation_report_encoder.dart';

typedef ValidationAnalyzer =
    Future<VisionPipelineResult> Function(VisionImageInput input);
typedef ValidationFileReader = Future<Uint8List> Function(File file);
typedef ValidationReportWriter =
    Future<void> Function(ValidationReport report, Directory outputDirectory);

final class ValidationRunner {
  ValidationRunner({
    CoffeeVisionEngine engine = const CoffeeVisionEngine(),
    ValidationAnalyzer? analyzer,
    ValidationFileReader? fileReader,
    ValidationReportWriter reportWriter = writeValidationReport,
  }) : _workingResolution = engine.config.workingResolution,
       _analyzer = analyzer ?? ((input) => engine.analyzeDetailed(input)),
       _fileReader = fileReader ?? ((file) => file.readAsBytes()),
       _reportWriter = reportWriter;

  final int _workingResolution;
  final ValidationAnalyzer _analyzer;
  final ValidationFileReader _fileReader;
  final ValidationReportWriter _reportWriter;
  final ValidationManifestParser _manifestParser =
      const ValidationManifestParser();
  final ValidationMetricExtractor _metricExtractor =
      const ValidationMetricExtractor();

  Future<ValidationRunOutcome> run({
    required Directory datasetRoot,
    required File manifestFile,
    required Directory outputDirectory,
    required int repeatCount,
    required String packageVersion,
  }) async {
    if (repeatCount <= 0) {
      throw ArgumentError.value(
        repeatCount,
        'repeatCount',
        'must be greater than zero',
      );
    }

    final manifestResult = await _loadManifest(manifestFile);
    if (manifestResult.error != null) {
      return _writeOutcome(
        outputDirectory: outputDirectory,
        report: ValidationReport(
          packageVersion: packageVersion,
          repeatCount: repeatCount,
          workingResolution: _workingResolution,
          records: const [],
          runErrors: [manifestResult.error!],
        ),
        preferredExitCode: 2,
      );
    }
    if (!await datasetRoot.exists()) {
      return _writeOutcome(
        outputDirectory: outputDirectory,
        report: ValidationReport(
          packageVersion: packageVersion,
          repeatCount: repeatCount,
          workingResolution: _workingResolution,
          records: const [],
          runErrors: [
            ValidationErrorRecord(
              category: ValidationErrorCategory.manifestInvalid,
              message: 'Dataset root does not exist.',
            ),
          ],
        ),
        preferredExitCode: 2,
      );
    }

    final records = <ValidationImageRecord>[];
    for (final entry in manifestResult.manifest!.entries) {
      if (!entry.enabled) {
        records.add(
          ValidationImageRecord(
            entry: entry,
            analysisStatus: ValidationAnalysisStatus.skippedDisabled,
            determinismStatus: ValidationDeterminismStatus.notRun,
            repeatsPerformed: 0,
          ),
        );
        continue;
      }
      records.add(
        await _analyzeEntry(
          datasetRoot: datasetRoot,
          entry: entry,
          repeatCount: repeatCount,
        ),
      );
    }

    final report = ValidationReport(
      packageVersion: packageVersion,
      repeatCount: repeatCount,
      workingResolution: _workingResolution,
      records: records,
    );
    final hasFailure = records.any(
      (record) =>
          record.analysisStatus == ValidationAnalysisStatus.failed ||
          record.determinismStatus ==
              ValidationDeterminismStatus.nonDeterministic,
    );
    return _writeOutcome(
      outputDirectory: outputDirectory,
      report: report,
      preferredExitCode: hasFailure ? 1 : 0,
    );
  }

  Future<ValidationImageRecord> _analyzeEntry({
    required Directory datasetRoot,
    required ValidationDatasetEntry entry,
    required int repeatCount,
  }) async {
    final relativeNativePath = entry.relativePath.replaceAll(
      '/',
      Platform.pathSeparator,
    );
    final file = File(
      '${datasetRoot.path}${Platform.pathSeparator}$relativeNativePath',
    );
    final bool fileExists;
    try {
      fileExists = await file.exists();
    } on Object {
      return _failure(
        entry,
        ValidationErrorCategory.fileReadFailure,
        'Dataset file could not be read.',
      );
    }
    if (!fileExists) {
      return _failure(
        entry,
        ValidationErrorCategory.fileNotFound,
        'Dataset file was not found.',
      );
    }

    final Uint8List bytes;
    try {
      bytes = await _fileReader(file);
    } on Object {
      return _failure(
        entry,
        ValidationErrorCategory.fileReadFailure,
        'Dataset file could not be read.',
      );
    }
    if (!contentChecksumMatches(bytes, entry.contentChecksum)) {
      return _failure(
        entry,
        ValidationErrorCategory.checksumMismatch,
        'Dataset file checksum does not match the manifest.',
      );
    }

    final input = VisionImageInput(
      imageBytes: bytes,
      surfaceType: entry.surfaceType,
      sourceId: entry.sourceId,
    );
    VisionPipelineResult? baselineResult;
    ValidationImageMetrics? baselineMetrics;
    final mismatchIndexes = <int>[];
    var attempts = 0;
    for (var repeatIndex = 1; repeatIndex <= repeatCount; repeatIndex++) {
      attempts++;
      try {
        final result = await _analyzer(input);
        if (result.workingImage.sourceMetadata.format != entry.format) {
          return _failure(
            entry,
            ValidationErrorCategory.manifestInvalid,
            'Manifest format does not match the image content.',
            repeatsPerformed: attempts,
          );
        }
        final metrics = _metricExtractor.extract(result: result, entry: entry);
        if (baselineResult == null) {
          baselineResult = result;
          baselineMetrics = metrics;
        } else if (result != baselineResult || metrics != baselineMetrics) {
          mismatchIndexes.add(repeatIndex);
        }
      } on FormatException catch (error) {
        final unsupported = error.message.toString().startsWith(
          'Unsupported image format',
        );
        return _failure(
          entry,
          unsupported
              ? ValidationErrorCategory.unsupportedImage
              : ValidationErrorCategory.corruptedImage,
          unsupported
              ? 'Image format is not supported.'
              : 'Image content is corrupted.',
          repeatsPerformed: attempts,
        );
      } on Object {
        return _failure(
          entry,
          ValidationErrorCategory.pipelineFailure,
          'Pipeline analysis failed.',
          repeatsPerformed: attempts,
        );
      }
    }

    if (mismatchIndexes.isNotEmpty) {
      final error = ValidationErrorRecord(
        category: ValidationErrorCategory.nonDeterministicResult,
        sourceId: entry.sourceId,
        message: 'Repeated pipeline results are not deterministic.',
        repeatIndexes: mismatchIndexes,
      );
      return ValidationImageRecord(
        entry: entry,
        analysisStatus: ValidationAnalysisStatus.success,
        determinismStatus: ValidationDeterminismStatus.nonDeterministic,
        repeatsPerformed: attempts,
        metrics: baselineMetrics!,
        error: error,
        mismatchedRepeatIndexes: mismatchIndexes,
      );
    }
    return ValidationImageRecord(
      entry: entry,
      analysisStatus: ValidationAnalysisStatus.success,
      determinismStatus: ValidationDeterminismStatus.deterministic,
      repeatsPerformed: attempts,
      metrics: baselineMetrics!,
    );
  }

  ValidationImageRecord _failure(
    ValidationDatasetEntry entry,
    ValidationErrorCategory category,
    String message, {
    int repeatsPerformed = 0,
  }) {
    return ValidationImageRecord(
      entry: entry,
      analysisStatus: ValidationAnalysisStatus.failed,
      determinismStatus: ValidationDeterminismStatus.notRun,
      repeatsPerformed: repeatsPerformed,
      error: ValidationErrorRecord(
        category: category,
        sourceId: entry.sourceId,
        message: message,
      ),
    );
  }

  Future<ValidationRunOutcome> _writeOutcome({
    required Directory outputDirectory,
    required ValidationReport report,
    required int preferredExitCode,
  }) async {
    try {
      await _reportWriter(report, outputDirectory);
      return ValidationRunOutcome(exitCode: preferredExitCode, report: report);
    } on Object {
      return ValidationRunOutcome(
        exitCode: 3,
        report: report,
        reportWriteError: ValidationErrorRecord(
          category: ValidationErrorCategory.reportWriteFailure,
          message: 'Validation report could not be written.',
        ),
      );
    }
  }

  Future<({ValidationManifest? manifest, ValidationErrorRecord? error})>
  _loadManifest(File manifestFile) async {
    if (!await manifestFile.exists()) {
      return (
        manifest: null,
        error: ValidationErrorRecord(
          category: ValidationErrorCategory.manifestInvalid,
          message: 'Manifest file was not found.',
        ),
      );
    }
    final String source;
    try {
      source = await manifestFile.readAsString();
    } on Object {
      return (
        manifest: null,
        error: ValidationErrorRecord(
          category: ValidationErrorCategory.manifestInvalid,
          message: 'Manifest file could not be read.',
        ),
      );
    }
    try {
      return (manifest: _manifestParser.parse(source), error: null);
    } on ValidationManifestException catch (error) {
      return (
        manifest: null,
        error: ValidationErrorRecord(
          category: ValidationErrorCategory.manifestInvalid,
          message: error.message,
        ),
      );
    }
  }
}
