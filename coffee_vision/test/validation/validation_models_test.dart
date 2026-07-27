import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

import '../../tool/validation/src/validation_models.dart';
import 'validation_test_support.dart';

void main() {
  group('Validation models', () {
    test('dataset entry has value equality and stable JSON field order', () {
      final first = createEntry();
      final second = createEntry();

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toJson().keys, [
        'sourceId',
        'relativePath',
        'surfaceType',
        'format',
        'ownership',
        'consent',
        'enabled',
        'contentChecksum',
      ]);
    });

    test('metrics validate ranges and have value equality', () {
      final first = createMetrics();
      final second = createMetrics();

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(
        () => ValidationImageMetrics(
          surfaceType: VisionSurfaceType.cup,
          sourceId: 'invalid',
          workingImageWidth: 8,
          workingImageHeight: 8,
          workingResiduePixelCount: 0,
          workingContentResidueAreaRatio: double.nan,
          componentCount: 0,
          relationCount: 0,
          selectedEdgeCount: 0,
          graphNodeCount: 0,
          graphEdgeCount: 0,
          structureCount: 0,
          largestStructureSize: 0,
          isolatedStructureCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('error repeat indexes are sorted, unique, and immutable', () {
      final error = ValidationErrorRecord(
        category: ValidationErrorCategory.nonDeterministicResult,
        sourceId: 'sample-001',
        message: 'Not deterministic.',
        repeatIndexes: const [3, 2],
      );

      expect(error.repeatIndexes, [2, 3]);
      expect(() => error.repeatIndexes.add(4), throwsUnsupportedError);
      expect(
        () => ValidationErrorRecord(
          category: ValidationErrorCategory.nonDeterministicResult,
          message: 'Invalid.',
          repeatIndexes: const [2, 2],
        ),
        throwsArgumentError,
      );
    });

    test('disabled record can only represent an untouched skip', () {
      final entry = createEntry(enabled: false);
      final record = ValidationImageRecord(
        entry: entry,
        analysisStatus: ValidationAnalysisStatus.skippedDisabled,
        determinismStatus: ValidationDeterminismStatus.notRun,
        repeatsPerformed: 0,
      );

      expect(record.analysisStatus, ValidationAnalysisStatus.skippedDisabled);
      expect(
        () => ValidationImageRecord(
          entry: entry,
          analysisStatus: ValidationAnalysisStatus.skippedDisabled,
          determinismStatus: ValidationDeterminismStatus.notRun,
          repeatsPerformed: 1,
        ),
        throwsArgumentError,
      );
    });

    test('successful and failed records enforce their contracts', () {
      final success = createSuccessRecord();
      final failure = ValidationImageRecord(
        entry: createEntry(),
        analysisStatus: ValidationAnalysisStatus.failed,
        determinismStatus: ValidationDeterminismStatus.notRun,
        repeatsPerformed: 1,
        error: ValidationErrorRecord(
          category: ValidationErrorCategory.pipelineFailure,
          sourceId: 'sample-001',
          message: 'Pipeline analysis failed.',
        ),
      );

      expect(success.metrics, isNotNull);
      expect(failure.error, isNotNull);
      expect(createSuccessRecord(), success);
      expect(createSuccessRecord().hashCode, success.hashCode);
    });

    test('non-deterministic record preserves baseline and differences', () {
      final error = ValidationErrorRecord(
        category: ValidationErrorCategory.nonDeterministicResult,
        sourceId: 'sample-001',
        message: 'Repeated results differ.',
        repeatIndexes: const [2],
      );
      final record = ValidationImageRecord(
        entry: createEntry(),
        analysisStatus: ValidationAnalysisStatus.success,
        determinismStatus: ValidationDeterminismStatus.nonDeterministic,
        repeatsPerformed: 3,
        metrics: createMetrics(),
        error: error,
        mismatchedRepeatIndexes: const [2],
      );

      expect(record.metrics, createMetrics());
      expect(record.error, error);
      expect(record.mismatchedRepeatIndexes, [2]);
    });

    test('report summaries split cup and saucer records', () {
      final cup = createSuccessRecord();
      final saucerEntry = createEntry(
        sourceId: 'saucer-001',
        surfaceType: VisionSurfaceType.saucer,
      );
      final saucer = createSuccessRecord(entry: saucerEntry);
      final report = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [cup, saucer],
      );

      expect(report.overallSummary.entryCount, 2);
      expect(report.cupSummary.successfulAnalysisCount, 1);
      expect(report.saucerSummary.successfulAnalysisCount, 1);
      expect(() => report.records.clear(), throwsUnsupportedError);
      expect(() => report.runErrors.clear(), throwsUnsupportedError);
    });

    test('report equality excludes no hidden machine or time state', () {
      final first = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [createSuccessRecord()],
      );
      final second = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [createSuccessRecord()],
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toJson(), isNot(contains('timestamp')));
    });
  });
}
