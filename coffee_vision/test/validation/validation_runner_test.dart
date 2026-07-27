import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

import '../../tool/validation/src/validation_models.dart';
import '../../tool/validation/src/validation_runner.dart';
import '../../tool/validation/validation_runner.dart' as cli;
import 'validation_test_support.dart';

void main() {
  const engine = CoffeeVisionEngine(config: VisionConfig(workingResolution: 8));

  group('ValidationRunner', () {
    test(
      'runs cup and saucer entries sequentially in manifest order',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        final cupBytes = createPngBytes(withResidue: true);
        final saucerBytes = createJpegBytes(withResidue: true);
        await fixture.writeFile('cup.png', cupBytes);
        await fixture.writeFile('saucer.jpg', saucerBytes);
        await fixture.writeManifest([
          createEntry(
            sourceId: 'cup-001',
            relativePath: 'cup.png',
            bytes: cupBytes,
          ),
          createEntry(
            sourceId: 'saucer-001',
            relativePath: 'saucer.jpg',
            surfaceType: VisionSurfaceType.saucer,
            format: VisionImageFormat.jpeg,
            bytes: saucerBytes,
          ),
        ]);
        final inputs = <String, VisionImageInput>{};
        var active = 0;
        var maximumActive = 0;
        var calls = 0;
        final runner = ValidationRunner(
          engine: engine,
          analyzer: (input) async {
            calls++;
            final previous = inputs[input.sourceId];
            if (previous == null) {
              inputs[input.sourceId!] = input;
            } else {
              expect(input, same(previous));
            }
            active++;
            if (active > maximumActive) maximumActive = active;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            final result = await engine.analyzeDetailed(input);
            active--;
            return result;
          },
        );

        final outcome = await fixture.run(runner, repeatCount: 3);

        expect(outcome.exitCode, 0);
        expect(outcome.report.records.map((record) => record.entry.sourceId), [
          'cup-001',
          'saucer-001',
        ]);
        expect(calls, 6);
        expect(maximumActive, 1);
        expect(
          outcome.report.records.every(
            (record) =>
                record.determinismStatus ==
                ValidationDeterminismStatus.deterministic,
          ),
          isTrue,
        );
      },
    );

    test('validates but does not read or analyze disabled entries', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      await fixture.writeManifest([
        createEntry(
          sourceId: 'disabled-001',
          relativePath: 'missing.png',
          enabled: false,
        ),
      ]);
      var reads = 0;
      var analyses = 0;
      final runner = ValidationRunner(
        engine: engine,
        fileReader: (file) async {
          reads++;
          return file.readAsBytes();
        },
        analyzer: (input) async {
          analyses++;
          return engine.analyzeDetailed(input);
        },
      );

      final outcome = await fixture.run(runner);

      expect(outcome.exitCode, 0);
      expect(reads, 0);
      expect(analyses, 0);
      expect(
        outcome.report.records.single.analysisStatus,
        ValidationAnalysisStatus.skippedDisabled,
      );
    });

    test('reports a missing file and continues to the next entry', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final bytes = createPngBytes();
      await fixture.writeFile('present.png', bytes);
      await fixture.writeManifest([
        createEntry(sourceId: 'missing', relativePath: 'missing.png'),
        createEntry(
          sourceId: 'present',
          relativePath: 'present.png',
          bytes: bytes,
        ),
      ]);

      final outcome = await fixture.run(ValidationRunner(engine: engine));

      expect(outcome.exitCode, 1);
      expect(
        outcome.report.records.first.error?.category,
        ValidationErrorCategory.fileNotFound,
      );
      expect(
        outcome.report.records.last.analysisStatus,
        ValidationAnalysisStatus.success,
      );
    });

    test(
      'reports file read failure without leaking exception details',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        final bytes = createPngBytes();
        await fixture.writeFile('sample.png', bytes);
        await fixture.writeManifest([createEntry(bytes: bytes)]);
        final runner = ValidationRunner(
          engine: engine,
          fileReader: (file) async => throw FileSystemException(
            'secret',
            r'C:\Users\private\sample.png',
          ),
        );

        final outcome = await fixture.run(runner);

        final error = outcome.report.records.single.error!;
        expect(error.category, ValidationErrorCategory.fileReadFailure);
        expect(error.message, 'Dataset file could not be read.');
        expect(error.message, isNot(contains(r'C:\Users')));
      },
    );

    test('rejects checksum mismatch before invoking the pipeline', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final bytes = createPngBytes();
      await fixture.writeFile('sample.png', bytes);
      await fixture.writeManifest([
        createEntry(bytes: createPngBytes(width: 7)),
      ]);
      var calls = 0;
      final runner = ValidationRunner(
        engine: engine,
        analyzer: (input) async {
          calls++;
          return engine.analyzeDetailed(input);
        },
      );

      final outcome = await fixture.run(runner);

      expect(calls, 0);
      expect(
        outcome.report.records.single.error?.category,
        ValidationErrorCategory.checksumMismatch,
      );
    });

    test('classifies unsupported and corrupted images separately', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final unsupported = Uint8List.fromList(
        await File('test/fixtures/unsupported.gif').readAsBytes(),
      );
      final corrupted = Uint8List.fromList(
        await File('test/fixtures/corrupt.png').readAsBytes(),
      );
      await fixture.writeFile('unsupported.gif', unsupported);
      await fixture.writeFile('corrupt.png', corrupted);
      await fixture.writeManifest([
        createEntry(
          sourceId: 'unsupported',
          relativePath: 'unsupported.gif',
          bytes: unsupported,
        ),
        createEntry(
          sourceId: 'corrupt',
          relativePath: 'corrupt.png',
          bytes: corrupted,
        ),
      ]);

      final outcome = await fixture.run(ValidationRunner(engine: engine));

      expect(outcome.exitCode, 1);
      expect(outcome.report.records.map((record) => record.error?.category), [
        ValidationErrorCategory.unsupportedImage,
        ValidationErrorCategory.corruptedImage,
      ]);
    });

    test('stops remaining repeats after a pipeline exception', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final bytes = createPngBytes();
      await fixture.writeFile('sample.png', bytes);
      await fixture.writeManifest([createEntry(bytes: bytes)]);
      var calls = 0;
      final runner = ValidationRunner(
        engine: engine,
        analyzer: (input) async {
          calls++;
          throw StateError('private implementation detail');
        },
      );

      final outcome = await fixture.run(runner, repeatCount: 3);

      expect(calls, 1);
      expect(outcome.report.records.single.repeatsPerformed, 1);
      expect(
        outcome.report.records.single.error?.category,
        ValidationErrorCategory.pipelineFailure,
      );
    });

    test(
      'records one-based mismatched repeat indexes and baseline metrics',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        final bytes = createPngBytes();
        await fixture.writeFile('sample.png', bytes);
        await fixture.writeManifest([createEntry(bytes: bytes)]);
        final baseline = await createPipelineResult(withResidue: false);
        final different = await createPipelineResult(withResidue: true);
        var calls = 0;
        final runner = ValidationRunner(
          engine: engine,
          analyzer: (input) async {
            calls++;
            return calls == 2 ? different : baseline;
          },
        );

        final outcome = await fixture.run(runner, repeatCount: 3);

        final record = outcome.report.records.single;
        expect(outcome.exitCode, 1);
        expect(record.analysisStatus, ValidationAnalysisStatus.success);
        expect(
          record.determinismStatus,
          ValidationDeterminismStatus.nonDeterministic,
        );
        expect(record.mismatchedRepeatIndexes, [2]);
        expect(record.metrics?.workingResiduePixelCount, 0);
        expect(
          record.error?.category,
          ValidationErrorCategory.nonDeterministicResult,
        );
      },
    );

    test('reports manifest format mismatch as controlled failure', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final bytes = createPngBytes();
      await fixture.writeFile('sample.png', bytes);
      await fixture.writeManifest([
        createEntry(format: VisionImageFormat.jpeg, bytes: bytes),
      ]);

      final outcome = await fixture.run(ValidationRunner(engine: engine));

      expect(outcome.exitCode, 1);
      expect(
        outcome.report.records.single.error?.category,
        ValidationErrorCategory.manifestInvalid,
      );
    });

    test('invalid manifest returns exit 2 before any analysis', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      await fixture.manifest.writeAsString('{}');
      var calls = 0;
      final runner = ValidationRunner(
        engine: engine,
        analyzer: (input) async {
          calls++;
          return engine.analyzeDetailed(input);
        },
      );

      final outcome = await fixture.run(runner);

      expect(outcome.exitCode, 2);
      expect(calls, 0);
      expect(outcome.report.records, isEmpty);
      expect(
        outcome.report.runErrors.single.category,
        ValidationErrorCategory.manifestInvalid,
      );
    });

    test('missing dataset root returns exit 2 before analysis', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      await fixture.writeManifest(<ValidationDatasetEntry>[]);
      await fixture.dataset.delete(recursive: true);

      final outcome = await fixture.run(ValidationRunner(engine: engine));

      expect(outcome.exitCode, 2);
      expect(
        outcome.report.runErrors.single.category,
        ValidationErrorCategory.manifestInvalid,
      );
    });

    test('report writer failure overrides result with exit 3', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final bytes = createPngBytes();
      await fixture.writeFile('sample.png', bytes);
      await fixture.writeManifest([createEntry(bytes: bytes)]);
      final runner = ValidationRunner(
        engine: engine,
        reportWriter: (report, output) async =>
            throw const FileSystemException('write failed'),
      );

      final outcome = await fixture.run(runner);

      expect(outcome.exitCode, 3);
      expect(
        outcome.reportWriteError?.category,
        ValidationErrorCategory.reportWriteFailure,
      );
    });

    test('writes JSON and CSV for a successful real pipeline run', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final bytes = createPngBytes(withResidue: true);
      await fixture.writeFile('sample.png', bytes);
      await fixture.writeManifest([createEntry(bytes: bytes)]);

      final outcome = await fixture.run(ValidationRunner(engine: engine));

      expect(outcome.exitCode, 0);
      expect(
        await File('${fixture.output.path}/validation_report.json').exists(),
        isTrue,
      );
      expect(
        await File('${fixture.output.path}/validation_summary.csv').exists(),
        isTrue,
      );
    });

    test('uses only the public barrel and analyzeDetailed pipeline entry', () {
      final files = Directory('tool/validation')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final sources = files.map((file) => file.readAsStringSync()).join('\n');
      final runnerSource = File(
        'tool/validation/src/validation_runner.dart',
      ).readAsStringSync();

      expect(sources, contains("package:coffee_vision/coffee_vision.dart"));
      expect(runnerSource, contains('engine.analyzeDetailed(input)'));
      expect(sources, isNot(contains('package:coffee_vision/src/')));
      expect(sources, isNot(contains('prepareWorkingImage(')));
      expect(sources, isNot(contains('createResidueMask(')));
    });
  });

  group('Validation CLI arguments', () {
    test('accepts any flag order and defaults to three total repeats', () {
      final parsed = cli.parseValidationCliArguments([
        '--output',
        'out',
        '--dataset',
        'data',
        '--manifest',
        'manifest.json',
      ]);

      expect(parsed.datasetPath, 'data');
      expect(parsed.manifestPath, 'manifest.json');
      expect(parsed.outputPath, 'out');
      expect(parsed.repeatCount, 3);
    });

    test('accepts an explicit positive total repeat count', () {
      final parsed = cli.parseValidationCliArguments([
        '--dataset',
        'data',
        '--manifest',
        'manifest.json',
        '--repeat',
        '5',
        '--output',
        'out',
      ]);

      expect(parsed.repeatCount, 5);
    });

    test('rejects missing, duplicate, unknown, and invalid flags', () {
      expect(() => cli.parseValidationCliArguments([]), throwsFormatException);
      expect(
        () => cli.parseValidationCliArguments([
          '--dataset',
          'one',
          '--dataset',
          'two',
        ]),
        throwsFormatException,
      );
      expect(
        () => cli.parseValidationCliArguments(['--unknown', 'value']),
        throwsFormatException,
      );
      expect(
        () => cli.parseValidationCliArguments([
          '--dataset',
          'data',
          '--manifest',
          'manifest.json',
          '--output',
          'out',
          '--repeat',
          '0',
        ]),
        throwsFormatException,
      );
    });
  });
}

final class _Fixture {
  _Fixture({
    required this.root,
    required this.dataset,
    required this.output,
    required this.manifest,
  });

  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp(
      'coffee_vision_validation_runner_',
    );
    final dataset = Directory('${root.path}/dataset');
    final output = Directory('${root.path}/output');
    await dataset.create();
    return _Fixture(
      root: root,
      dataset: dataset,
      output: output,
      manifest: File('${root.path}/manifest.json'),
    );
  }

  final Directory root;
  final Directory dataset;
  final Directory output;
  final File manifest;

  Future<void> writeFile(String relativePath, Uint8List bytes) async {
    final file = File('${dataset.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  Future<void> writeManifest(Iterable<ValidationDatasetEntry> entries) {
    return manifest.writeAsString(manifestJson(entries));
  }

  Future<ValidationRunOutcome> run(
    ValidationRunner runner, {
    int repeatCount = 3,
  }) {
    return runner.run(
      datasetRoot: dataset,
      manifestFile: manifest,
      outputDirectory: output,
      repeatCount: repeatCount,
      packageVersion: '0.0.1',
    );
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
