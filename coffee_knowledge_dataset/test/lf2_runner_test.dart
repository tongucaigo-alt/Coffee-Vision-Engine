import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/local_formation_evidence_runner.dart';
import '../tool/src/lf2_models.dart';
import '../tool/src/lf2_profiles.dart';
import '../tool/src/lf2_report.dart';
import '../tool/src/lf2_runner.dart';

void main() {
  group('LF-2 evidence runner', () {
    test('materializes profiles once and rejects duplicates before work', () {
      final profiles = _CountingIterable(lf2Profiles);
      Lf2EvidenceRunner(profiles: profiles);
      expect(profiles.iterations, 1);
      expect(
        () =>
            Lf2EvidenceRunner(profiles: [lf2Profiles.first, lf2Profiles.first]),
        throwsArgumentError,
      );
    });

    test(
      'prepares one image and mask per repeat, then runs all profiles',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        var prepareCalls = 0;
        var maskCalls = 0;
        var extractionCalls = 0;
        final runner = Lf2EvidenceRunner(
          workingImagePreparer: (_) async {
            prepareCalls++;
            return _workingImage();
          },
          residueMaskCreator: (_) async {
            maskCalls++;
            return _mask();
          },
          extractionOperation:
              ({
                required profileId,
                required sourceId,
                required mask,
                required contentRect,
                required profile,
              }) {
                extractionCalls++;
                return _extraction(profileId);
              },
        );

        final report = await runner.run(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
          repeatCount: 3,
        );

        expect(prepareCalls, 3);
        expect(maskCalls, 3);
        expect(extractionCalls, 24);
        expect(report.observations, hasLength(8));
        expect(report.succeeded, isTrue);
      },
    );

    test(
      'returns no partial profile output after morphology failure',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        var extractionCalls = 0;
        final report =
            await Lf2EvidenceRunner(
              workingImagePreparer: (_) async => _workingImage(),
              residueMaskCreator: (_) async => _mask(),
              extractionOperation:
                  ({
                    required profileId,
                    required sourceId,
                    required mask,
                    required contentRect,
                    required profile,
                  }) {
                    extractionCalls++;
                    if (extractionCalls == 3)
                      throw StateError('synthetic failure');
                    return _extraction(profileId);
                  },
            ).run(
              datasetRoot: fixture.root.path,
              manifestPath: fixture.manifest.path,
              freezePath: fixture.freeze.path,
              repeatCount: 1,
            );

        expect(extractionCalls, 3);
        expect(
          report.observations.every(
            (value) =>
                value.analysisStatus.name == 'failed' &&
                value.candidates.isEmpty &&
                value.failureCategory == Lf2FailureCategory.morphologyFailure,
          ),
          isTrue,
        );
      },
    );

    test('reports repeat mismatch deterministically by profile', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      var calls = 0;
      final report =
          await Lf2EvidenceRunner(
            profiles: [lf2Profiles.first],
            workingImagePreparer: (_) async => _workingImage(),
            residueMaskCreator: (_) async => _mask(),
            extractionOperation:
                ({
                  required profileId,
                  required sourceId,
                  required mask,
                  required contentRect,
                  required profile,
                }) {
                  calls++;
                  return _extraction(
                    profileId,
                    fingerprint: '000000000000000$calls',
                  );
                },
          ).run(
            datasetRoot: fixture.root.path,
            manifestPath: fixture.manifest.path,
            freezePath: fixture.freeze.path,
            repeatCount: 3,
          );

      expect(report.observations.single.mismatchedRepeatIndexes, [2, 3]);
      expect(
        report.observations.single.failureCategory,
        Lf2FailureCategory.nonDeterministicResult,
      );
      expect(report.succeeded, isFalse);
    });

    test(
      'uses canonical profile and source ordering with immutable output',
      () async {
        final fixture = await _Fixture.create(includeSaucer: true);
        addTearDown(fixture.dispose);
        final report =
            await Lf2EvidenceRunner(
              profiles: lf2Profiles.reversed,
              workingImagePreparer: (_) async => _workingImage(),
              residueMaskCreator: (_) async => _mask(),
              extractionOperation:
                  ({
                    required profileId,
                    required sourceId,
                    required mask,
                    required contentRect,
                    required profile,
                  }) => _extraction(profileId),
            ).run(
              datasetRoot: fixture.root.path,
              manifestPath: fixture.manifest.path,
              freezePath: fixture.freeze.path,
              repeatCount: 1,
            );

        final keys = report.observations
            .map((value) => '${value.profileId}#${value.sourceId}')
            .toList();
        expect(keys, List<String>.of(keys)..sort());
        expect(
          () => report.observations.add(report.observations.first),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'writes complete external reports and rejects repository output',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        final report =
            await Lf2EvidenceRunner(
              profiles: [lf2Profiles.first],
              workingImagePreparer: (_) async => _workingImage(),
              residueMaskCreator: (_) async => _mask(),
              extractionOperation:
                  ({
                    required profileId,
                    required sourceId,
                    required mask,
                    required contentRect,
                    required profile,
                  }) => _extraction(profileId),
            ).run(
              datasetRoot: fixture.root.path,
              manifestPath: fixture.manifest.path,
              freezePath: fixture.freeze.path,
              repeatCount: 1,
            );
        final output = Directory(
          '${fixture.root.path}${Platform.pathSeparator}lfr-002',
        );
        final repositoryRoot = Directory.current.parent.path;
        final paths = await const Lf2ReportWriter().write(
          report: report,
          outputDirectory: output.path,
          repositoryRoot: repositoryRoot,
        );

        expect(paths, hasLength(2));
        final json = await File(paths.first).readAsString();
        expect(json, contains('candidateIdentity'));
        expect(json, contains('residueConservation'));
        expect(json, isNot(contains(fixture.root.path)));
        await expectLater(
          const Lf2ReportWriter().write(
            report: report,
            outputDirectory: repositoryRoot,
            repositoryRoot: repositoryRoot,
          ),
          throwsA(isA<Lf2ReportWriteException>()),
        );
      },
    );

    test('CLI defaults to three repeats and lfr-002', () {
      final options = Lf2CliOptions.parse(const [
        '--dataset',
        'dataset',
        '--manifest',
        'manifest',
        '--freeze',
        'freeze',
        '--output',
        'output',
        '--repository-root',
        'repo',
      ]);
      expect(options.repeatCount, 3);
      expect(options.researchId, 'lfr-002');
    });
  });
}

WorkingImage _workingImage() => WorkingImage(
  bytes: Uint8List.fromList([1]),
  metadata: VisionImageMetadata(
    format: VisionImageFormat.png,
    width: 8,
    height: 8,
  ),
  contentRect: VisionRect(left: 0, top: 0, right: 1, bottom: 1),
  resolution: 8,
);

ResidueMask _mask() {
  final pixels = Uint8List(64)..[18] = 1;
  return ResidueMask(width: 8, height: 8, pixels: pixels, residueRatio: 1 / 64);
}

Lf2ExtractionResult _extraction(
  String profileId, {
  String fingerprint = '0000000000000001',
}) => Lf2ExtractionResult(
  candidates: [
    Lf2CandidateObservation(
      candidateId: 1,
      polarity: Lf2Polarity.residue,
      supportIdentity: '$profileId#test-source#support#1',
      minimumRowMajorPixelIndex: 18,
      left: 0.25,
      top: 0.25,
      right: 0.375,
      bottom: 0.375,
      centroidX: 0.3125,
      centroidY: 0.3125,
      pixelCount: 1,
      areaRatio: 1 / 64,
      residueContactSectorCount: 0,
      pixelFingerprint: fingerprint,
    ),
  ],
  originalResiduePixelCount: 1,
  assignedResiduePixelCount: 1,
  emittedResiduePixelCount: 1,
  suppressedResiduePixelCount: 0,
  duplicateResidueAssignmentCount: 0,
);

final class _CountingIterable extends Iterable<Lf2ProfileDefinition> {
  _CountingIterable(this.values);

  final List<Lf2ProfileDefinition> values;
  int iterations = 0;

  @override
  Iterator<Lf2ProfileDefinition> get iterator {
    iterations++;
    return values.iterator;
  }
}

final class _Fixture {
  const _Fixture({
    required this.root,
    required this.manifest,
    required this.freeze,
  });

  final Directory root;
  final File manifest;
  final File freeze;

  static Future<_Fixture> create({bool includeSaucer = false}) async {
    final root = await Directory.systemTemp.createTemp('atlas-lf2-runner-');
    final entries = <Map<String, Object?>>[];
    await _addEntry(root, entries, 'cup-001', 'images/cup/cup.png', 'cup');
    if (includeSaucer) {
      await _addEntry(
        root,
        entries,
        'saucer-001',
        'images/saucer/saucer.png',
        'saucer',
      );
    }
    final manifestSource =
        '${const JsonEncoder.withIndent('  ').convert({'schemaVersion': '1.0', 'entries': entries})}\n';
    final manifest = File(
      '${root.path}${Platform.pathSeparator}manifests${Platform.pathSeparator}dataset_manifest.json',
    );
    await manifest.parent.create(recursive: true);
    await manifest.writeAsString(manifestSource);
    final checksum = 'sha256:${sha256.convert(utf8.encode(manifestSource))}';
    final freeze = File(
      '${root.path}${Platform.pathSeparator}records${Platform.pathSeparator}dataset_freeze.txt',
    );
    await freeze.parent.create(recursive: true);
    await freeze.writeAsString('''
datasetVersion=lf2-test
physicalCupCount=1
physicalSaucerCount=${includeSaucer ? 1 : 0}
physicalTotalCount=${entries.length}
enabledCupCount=1
enabledSaucerCount=${includeSaucer ? 1 : 0}
enabledTotalCount=${entries.length}
disabledCount=0
duplicateCount=0
manifestSha256=$checksum
manifestRelativePath=manifests/dataset_manifest.json
''');
    return _Fixture(root: root, manifest: manifest, freeze: freeze);
  }

  static Future<void> _addEntry(
    Directory root,
    List<Map<String, Object?>> entries,
    String sourceId,
    String relativePath,
    String surfaceType,
  ) async {
    final bytes = Uint8List.fromList(sourceId.codeUnits);
    final file = File(
      [root.path, ...relativePath.split('/')].join(Platform.pathSeparator),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    entries.add({
      'sourceId': sourceId,
      'relativePath': relativePath,
      'surfaceType': surfaceType,
      'format': 'png',
      'ownership': 'user-owned',
      'consent': 'local-validation',
      'enabled': true,
      'contentChecksum': 'sha256:${sha256.convert(bytes)}',
    });
  }

  Future<void> dispose() => root.delete(recursive: true);
}
