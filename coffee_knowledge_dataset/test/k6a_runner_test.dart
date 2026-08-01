import 'dart:convert';
import 'dart:io';

import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/pattern_observation_runner.dart';
import '../tool/src/k6a_models.dart';
import '../tool/src/k6a_report.dart';
import '../tool/src/k6a_runner.dart';

void main() {
  group('K6A observation runner', () {
    test('runs Vision and Pattern exactly once per repeat', () async {
      final fixture = await _RunnerFixture.create();
      addTearDown(fixture.dispose);
      var visionCalls = 0;
      var patternCalls = 0;
      VisionImageInput? firstInput;

      final runner = K6aObservationRunner(
        visionAnalyzer: (input) {
          visionCalls++;
          firstInput ??= input;
          expect(input, same(firstInput));
          return const CoffeeVisionEngine().analyzeFeatures(input);
        },
        patternAnalyzer: (features) {
          patternCalls++;
          return const PatternEngine().analyzePatterns(features);
        },
      );
      final report = await runner.run(
        datasetRoot: fixture.root.path,
        manifestPath: fixture.manifest.path,
        freezePath: fixture.freeze.path,
        repeatCount: 3,
      );

      expect(visionCalls, 3);
      expect(patternCalls, 3);
      expect(report.summary.enabledEntries, 1);
      expect(report.summary.successfulEntries, 1);
      expect(report.summary.deterministicEntries, 1);
      expect(report.records.single.repeatsPerformed, 3);
    });

    test('records non-deterministic repeat indexes and first output', () async {
      final fixture = await _RunnerFixture.create();
      addTearDown(fixture.dispose);
      var patternCalls = 0;

      final runner = K6aObservationRunner(
        visionAnalyzer: const CoffeeVisionEngine().analyzeFeatures,
        patternAnalyzer: (features) async {
          patternCalls++;
          if (patternCalls == 2) {
            return PatternAnalysisResult(
              surfaceType: PatternSurfaceType.cup,
              sourceId: 'cup-001',
              candidates: [_candidate()],
            );
          }
          return const PatternEngine().analyzePatterns(features);
        },
      );
      final report = await runner.run(
        datasetRoot: fixture.root.path,
        manifestPath: fixture.manifest.path,
        freezePath: fixture.freeze.path,
        repeatCount: 3,
      );

      expect(
        report.records.single.determinismStatus,
        K6aDeterminismStatus.nonDeterministic,
      );
      expect(report.records.single.mismatchedRepeatIndexes, [2]);
      expect(
        report.records.single.failureCategory,
        K6aFailureCategory.nonDeterministicResult,
      );
      expect(report.succeeded, isFalse);
    });

    test('continues with the next image after a Vision failure', () async {
      final fixture = await _RunnerFixture.create(includeSaucer: true);
      addTearDown(fixture.dispose);
      var patternCalls = 0;

      final runner = K6aObservationRunner(
        visionAnalyzer: (input) {
          if (input.sourceId == 'cup-001') {
            throw StateError('synthetic test failure');
          }
          return const CoffeeVisionEngine().analyzeFeatures(input);
        },
        patternAnalyzer: (features) {
          patternCalls++;
          return const PatternEngine().analyzePatterns(features);
        },
      );
      final report = await runner.run(
        datasetRoot: fixture.root.path,
        manifestPath: fixture.manifest.path,
        freezePath: fixture.freeze.path,
        repeatCount: 1,
      );

      expect(report.records, hasLength(2));
      expect(report.records.first.analysisStatus, K6aAnalysisStatus.failed);
      expect(
        report.records.first.failureCategory,
        K6aFailureCategory.visionFailure,
      );
      expect(report.records.last.analysisStatus, K6aAnalysisStatus.success);
      expect(patternCalls, 1);
    });

    test('does not start analysis when preflight rejects duplicates', () async {
      final fixture = await _RunnerFixture.create(
        includeSaucer: true,
        useSameBytes: true,
      );
      addTearDown(fixture.dispose);
      var visionCalls = 0;

      final runner = K6aObservationRunner(
        visionAnalyzer: (input) {
          visionCalls++;
          return const CoffeeVisionEngine().analyzeFeatures(input);
        },
      );

      await expectLater(
        runner.run(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
          repeatCount: 1,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(visionCalls, 0);
    });

    test('writes deterministic reports without image paths or bytes', () async {
      final fixture = await _RunnerFixture.create();
      addTearDown(fixture.dispose);
      final report =
          await K6aObservationRunner(
            visionAnalyzer: const CoffeeVisionEngine().analyzeFeatures,
            patternAnalyzer: (features) async {
              return PatternAnalysisResult(
                surfaceType: switch (features.surfaceType) {
                  VisionSurfaceType.cup => PatternSurfaceType.cup,
                  VisionSurfaceType.saucer => PatternSurfaceType.saucer,
                },
                sourceId: features.sourceId,
                candidates: [_candidate()],
              );
            },
          ).run(
            datasetRoot: fixture.root.path,
            manifestPath: fixture.manifest.path,
            freezePath: fixture.freeze.path,
            repeatCount: 1,
          );
      final output = Directory(
        '${fixture.root.path}${Platform.pathSeparator}knowledge_research',
      );

      final paths = await const K6aReportWriter().write(
        report: report,
        outputDirectory: output.path,
      );

      expect(paths, hasLength(5));
      final jsonSource = await File(paths.first).readAsString();
      final csvSource = await File(paths[1]).readAsString();
      final cohortSource = await File(paths[2]).readAsString();
      expect(jsonDecode(jsonSource), isA<Map<String, Object?>>());
      expect(jsonSource, contains('"sourceId": "cup-001"'));
      expect(jsonSource, isNot(contains(fixture.root.path)));
      expect(jsonSource, isNot(contains('images/cup/cup.png')));
      expect(csvSource, contains('geometryAspectRatio'));
      expect(csvSource, isNot(contains('images/cup/cup.png')));
      expect(cohortSource, contains('cup-001#1'));
      expect(
        () => report.records.add(report.records.single),
        throwsUnsupportedError,
      );
    });

    test('refuses to overwrite an existing research artefact', () async {
      final fixture = await _RunnerFixture.create();
      addTearDown(fixture.dispose);
      final report = await K6aObservationRunner().run(
        datasetRoot: fixture.root.path,
        manifestPath: fixture.manifest.path,
        freezePath: fixture.freeze.path,
        repeatCount: 1,
      );
      final output = Directory(
        '${fixture.root.path}${Platform.pathSeparator}knowledge_research',
      );
      await const K6aReportWriter().write(
        report: report,
        outputDirectory: output.path,
      );

      await expectLater(
        const K6aReportWriter().write(
          report: report,
          outputDirectory: output.path,
        ),
        throwsA(isA<K6aReportWriteException>()),
      );
    });

    test('CLI defaults repeat to three and rejects duplicate flags', () {
      final options = K6aCliOptions.parse(const [
        '--dataset',
        'dataset',
        '--manifest',
        'manifest',
        '--freeze',
        'freeze',
        '--output',
        'output',
      ]);

      expect(options.repeatCount, 3);
      expect(options.researchId, 'kdr-001');
      expect(
        () => K6aCliOptions.parse(const [
          '--dataset',
          'one',
          '--dataset',
          'two',
          '--manifest',
          'manifest',
          '--freeze',
          'freeze',
          '--output',
          'output',
        ]),
        throwsFormatException,
      );
    });
  });
}

PatternCandidate _candidate() {
  return PatternCandidate.withGeometryAndTopology(
    id: 1,
    evidence: [
      PatternEvidence.componentFeature(1),
      PatternEvidence.connectedStructure(1),
    ],
    geometry: PatternGeometry(
      left: 0.0,
      top: 0.0,
      right: 0.5,
      bottom: 0.5,
      centroidX: 0.25,
      centroidY: 0.25,
    ),
    topology: PatternTopology(nodeCount: 1, directedEdgeCount: 0),
  );
}

final class _RunnerFixture {
  const _RunnerFixture({
    required this.root,
    required this.manifest,
    required this.freeze,
  });

  final Directory root;
  final File manifest;
  final File freeze;

  static Future<_RunnerFixture> create({
    bool includeSaucer = false,
    bool useSameBytes = false,
  }) async {
    final root = await Directory.systemTemp.createTemp('atlas-k6a-runner-');
    final cupBytes = await File(
      '..${Platform.pathSeparator}coffee_vision'
      '${Platform.pathSeparator}test${Platform.pathSeparator}fixtures'
      '${Platform.pathSeparator}valid_2x3.png',
    ).readAsBytes();
    final saucerBytes = useSameBytes
        ? cupBytes
        : await File(
            '..${Platform.pathSeparator}coffee_vision'
            '${Platform.pathSeparator}test${Platform.pathSeparator}fixtures'
            '${Platform.pathSeparator}valid_3x2.jpg',
          ).readAsBytes();
    final entries = <Map<String, Object?>>[];
    await _addEntry(
      root: root,
      entries: entries,
      sourceId: 'cup-001',
      relativePath: 'images/cup/cup.png',
      surfaceType: 'cup',
      format: 'png',
      bytes: cupBytes,
    );
    if (includeSaucer) {
      await _addEntry(
        root: root,
        entries: entries,
        sourceId: 'saucer-001',
        relativePath: 'images/saucer/saucer.jpg',
        surfaceType: 'saucer',
        format: 'jpeg',
        bytes: saucerBytes,
      );
    }
    final manifestSource =
        '${const JsonEncoder.withIndent('  ').convert({'schemaVersion': '1.0', 'entries': entries})}\n';
    final manifest = File(
      '${root.path}${Platform.pathSeparator}manifests'
      '${Platform.pathSeparator}dataset_manifest.json',
    );
    await manifest.parent.create(recursive: true);
    await manifest.writeAsString(manifestSource);
    final manifestChecksum =
        'sha256:${sha256.convert(utf8.encode(manifestSource))}';
    final saucerCount = includeSaucer ? 1 : 0;
    final freeze = File(
      '${root.path}${Platform.pathSeparator}records'
      '${Platform.pathSeparator}dataset_freeze.txt',
    );
    await freeze.parent.create(recursive: true);
    await freeze.writeAsString('''
datasetVersion=m5b-test
physicalCupCount=1
physicalSaucerCount=$saucerCount
physicalTotalCount=${entries.length}
enabledCupCount=1
enabledSaucerCount=$saucerCount
enabledTotalCount=${entries.length}
disabledCount=0
duplicateCount=0
manifestSha256=$manifestChecksum
manifestRelativePath=manifests/dataset_manifest.json
''');
    return _RunnerFixture(root: root, manifest: manifest, freeze: freeze);
  }

  static Future<void> _addEntry({
    required Directory root,
    required List<Map<String, Object?>> entries,
    required String sourceId,
    required String relativePath,
    required String surfaceType,
    required String format,
    required List<int> bytes,
  }) async {
    final file = File(
      [root.path, ...relativePath.split('/')].join(Platform.pathSeparator),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    entries.add({
      'sourceId': sourceId,
      'relativePath': relativePath,
      'surfaceType': surfaceType,
      'format': format,
      'ownership': 'user-owned',
      'consent': 'local-validation',
      'enabled': true,
      'contentChecksum': 'sha256:${sha256.convert(bytes)}',
    });
  }

  Future<void> dispose() => root.delete(recursive: true);
}
