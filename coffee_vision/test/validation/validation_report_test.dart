import 'dart:convert';
import 'dart:io';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

import '../../tool/validation/src/validation_models.dart';
import '../../tool/validation/src/validation_report_encoder.dart';
import 'validation_test_support.dart';

void main() {
  const encoder = ValidationReportEncoder();

  group('ValidationReportEncoder', () {
    test('emits stable JSON metadata, summaries, and manifest order', () {
      final cup = createSuccessRecord();
      final saucerEntry = createEntry(
        sourceId: 'saucer-001',
        surfaceType: VisionSurfaceType.saucer,
      );
      final report = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [
          cup,
          createSuccessRecord(entry: saucerEntry),
        ],
      );

      final json = encoder.encodeJson(report);
      final decoded = jsonDecode(json) as Map<String, Object?>;
      final records = decoded['records']! as List<Object?>;

      expect(decoded['schemaVersion'], '1.0');
      expect(decoded['milestone'], 'Atlas M5A');
      expect(decoded['packageName'], 'coffee_vision');
      expect(decoded['packageVersion'], '0.0.1');
      expect(decoded, isNot(contains('timestamp')));
      expect(records.length, 2);
      expect(json.indexOf('sample-001'), lessThan(json.indexOf('saucer-001')));
    });

    test('emits one CSV row per manifest entry including disabled', () {
      final disabledEntry = createEntry(
        sourceId: 'disabled-001',
        enabled: false,
      );
      final disabled = ValidationImageRecord(
        entry: disabledEntry,
        analysisStatus: ValidationAnalysisStatus.skippedDisabled,
        determinismStatus: ValidationDeterminismStatus.notRun,
        repeatsPerformed: 0,
      );
      final report = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [createSuccessRecord(), disabled],
      );

      final lines = encoder.encodeCsv(report).split('\r\n');

      expect(lines.where((line) => line.isNotEmpty).length, 3);
      expect(lines[0], startsWith('sourceId,relativePath,surfaceType'));
      expect(lines[2], contains('skippedDisabled'));
    });

    test('escapes commas, quotes, and newlines using CSV rules', () {
      final entry = ValidationDatasetEntry(
        sourceId: 'sample,"id\nnext',
        relativePath: 'folder/sample.png',
        surfaceType: VisionSurfaceType.cup,
        format: VisionImageFormat.png,
        ownership: 'synthetic-test-fixture',
        consent: 'test-use-only',
        enabled: false,
        contentChecksum: 'sha256:${List.filled(64, '0').join()}',
      );
      final record = ValidationImageRecord(
        entry: entry,
        analysisStatus: ValidationAnalysisStatus.skippedDisabled,
        determinismStatus: ValidationDeterminismStatus.notRun,
        repeatsPerformed: 0,
      );
      final csv = encoder.encodeCsv(
        ValidationReport(
          packageVersion: '0.0.1',
          repeatCount: 3,
          workingResolution: 512,
          records: [record],
        ),
      );

      expect(csv, contains('"sample,""id\nnext"'));
    });

    test('does not serialize absolute paths or stack traces', () {
      final error = ValidationErrorRecord(
        category: ValidationErrorCategory.fileReadFailure,
        sourceId: 'sample-001',
        message: 'Dataset file could not be read.',
      );
      final record = ValidationImageRecord(
        entry: createEntry(relativePath: 'safe/sample.png'),
        analysisStatus: ValidationAnalysisStatus.failed,
        determinismStatus: ValidationDeterminismStatus.notRun,
        repeatsPerformed: 0,
        error: error,
      );
      final report = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [record],
      );

      final combined =
          '${encoder.encodeJson(report)}${encoder.encodeCsv(report)}';

      expect(combined, isNot(contains(r'C:\Users')));
      expect(combined, isNot(contains('StackTrace')));
      expect(combined, contains('safe/sample.png'));
    });

    test('writes the two named report files from one report model', () async {
      final directory = await Directory.systemTemp.createTemp(
        'coffee_vision_report_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final report = ValidationReport(
        packageVersion: '0.0.1',
        repeatCount: 3,
        workingResolution: 512,
        records: [createSuccessRecord()],
      );

      await writeValidationReport(report, directory);

      final jsonFile = File('${directory.path}/validation_report.json');
      final csvFile = File('${directory.path}/validation_summary.csv');
      expect(await jsonFile.exists(), isTrue);
      expect(await csvFile.exists(), isTrue);
      expect(await jsonFile.readAsString(), encoder.encodeJson(report));
      expect(await csvFile.readAsString(), encoder.encodeCsv(report));
    });
  });
}
