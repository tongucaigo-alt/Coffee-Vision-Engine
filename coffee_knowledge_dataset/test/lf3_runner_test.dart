import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/local_formation_lf3_runner.dart';
import '../tool/src/lf2_models.dart';
import '../tool/src/lf3_models.dart';
import '../tool/src/lf3_profiles.dart';
import '../tool/src/lf3_report.dart';
import '../tool/src/lf3_runner.dart';

void main() {
  group('LF-3 evidence runner', () {
    test(
      'materializes profiles once and rejects duplicate IDs before work',
      () {
        final profiles = _CountingIterable(lf3Profiles);
        Lf3EvidenceRunner(profiles: profiles);
        expect(profiles.iterations, 1);
        expect(
          () => Lf3EvidenceRunner(
            profiles: [lf3Profiles.first, lf3Profiles.first],
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'creates one WorkingImage, mask, and evidence frame per repeat',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        var prepareCalls = 0;
        var maskCalls = 0;
        var evidenceCalls = 0;
        var extractionCalls = 0;
        final runner = Lf3EvidenceRunner(
          profiles: [lf3Profiles[0], lf3Profiles[4]],
          workingImagePreparer: (_) async {
            prepareCalls++;
            return _workingImage();
          },
          residueMaskCreator: (_) async {
            maskCalls++;
            return _mask();
          },
          evidenceOperation: (_) {
            evidenceCalls++;
            return _evidence(withSupport: true);
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
        expect(evidenceCalls, 3);
        expect(extractionCalls, 6);
        expect(report.observations, hasLength(2));
        expect(report.succeeded, isTrue);
      },
    );

    test(
      'fails support profiles closed while preserving full-frame research',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        final report =
            await Lf3EvidenceRunner(
              profiles: [lf3Profiles[0], lf3Profiles[2]],
              workingImagePreparer: (_) async => _workingImage(),
              residueMaskCreator: (_) async => _mask(),
              evidenceOperation: (_) => _evidence(withSupport: false),
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

        final full = report.observations.first;
        final supported = report.observations.last;
        expect(full.analysisStatus.name, 'success');
        expect(full.candidates, hasLength(1));
        expect(supported.analysisStatus.name, 'failed');
        expect(
          supported.failureCategory,
          Lf3FailureCategory.supportUnavailable,
        );
        expect(supported.candidates, isEmpty);
        expect(report.succeeded, isFalse);
      },
    );

    test('contains morphology failure within the affected profile', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final report =
          await Lf3EvidenceRunner(
            profiles: [lf3Profiles[0], lf3Profiles[1]],
            workingImagePreparer: (_) async => _workingImage(),
            residueMaskCreator: (_) async => _mask(),
            evidenceOperation: (_) => _evidence(withSupport: false),
            extractionOperation:
                ({
                  required profileId,
                  required sourceId,
                  required mask,
                  required contentRect,
                  required profile,
                }) {
                  if (profileId == lf3Profiles.first.id) {
                    throw StateError('synthetic failure');
                  }
                  return _extraction(profileId);
                },
          ).run(
            datasetRoot: fixture.root.path,
            manifestPath: fixture.manifest.path,
            freezePath: fixture.freeze.path,
            repeatCount: 1,
          );

      expect(report.observations.first.candidates, isEmpty);
      expect(
        report.observations.first.failureCategory,
        Lf3FailureCategory.morphologyFailure,
      );
      expect(report.observations.last.candidates, hasLength(1));
    });

    test(
      'reports repeat mismatch and returns canonical immutable output',
      () async {
        final fixture = await _Fixture.create(includeSaucer: true);
        addTearDown(fixture.dispose);
        var calls = 0;
        final report =
            await Lf3EvidenceRunner(
              profiles: [lf3Profiles.first],
              workingImagePreparer: (_) async => _workingImage(),
              residueMaskCreator: (_) async => _mask(),
              evidenceOperation: (_) => _evidence(withSupport: false),
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
              repeatCount: 2,
            );

        expect(
          report.observations.map((value) => value.sourceId),
          orderedEquals(['cup-001', 'saucer-001']),
        );
        expect(
          report.observations.every(
            (value) =>
                value.failureCategory ==
                Lf3FailureCategory.nonDeterministicResult,
          ),
          isTrue,
        );
        expect(
          () => report.observations.add(report.observations.first),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'writes four complete external reports without source paths',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        final report =
            await Lf3EvidenceRunner(
              profiles: [lf3Profiles.first],
              workingImagePreparer: (_) async => _workingImage(),
              residueMaskCreator: (_) async => _mask(),
              evidenceOperation: (_) => _evidence(withSupport: false),
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
          '${fixture.root.path}${Platform.pathSeparator}lfr-003',
        );
        final repositoryRoot = Directory.current.parent.path;

        final paths = await const Lf3ReportWriter().write(
          report: report,
          outputDirectory: output.path,
          repositoryRoot: repositoryRoot,
        );

        expect(paths, hasLength(4));
        final candidateJson = await File(paths.first).readAsString();
        final evidenceJson = await File(paths[2]).readAsString();
        expect(candidateJson, contains('candidateIdentity'));
        expect(evidenceJson, contains('surfaceSummaries'));
        expect(candidateJson, isNot(contains(fixture.root.path)));
        expect(evidenceJson, isNot(contains(fixture.root.path)));
        expect(() => paths.add('extra'), throwsUnsupportedError);
        await expectLater(
          const Lf3ReportWriter().write(
            report: report,
            outputDirectory: repositoryRoot,
            repositoryRoot: repositoryRoot,
          ),
          throwsA(isA<Lf3ReportWriteException>()),
        );
      },
    );

    test('CLI defaults to three repeats and lfr-003', () {
      final options = Lf3CliOptions.parse(const [
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
      expect(options.researchId, 'lfr-003');
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

Lf3EvidenceFrame _evidence({required bool withSupport}) {
  final values = Uint8List(64)..[18] = 32;
  return Lf3EvidenceFrame(
    width: 8,
    height: 8,
    contentBounds: const Lf2PixelBounds(left: 0, top: 0, right: 8, bottom: 8),
    globalBackgroundLuminance: 100,
    luminance: Uint8List(64),
    globalContrast: values,
    localContrast: values,
    fusion: values,
    support: withSupport
        ? Lf3SupportEvidence(
            centerX: 0.5,
            centerY: 0.5,
            radiusX: 0.4,
            radiusY: 0.4,
            visibleSampleCount: 64,
            edgeSampleCount: 64,
            edgeContinuity: 1,
            meanBoundaryContrast: 20,
            pixels: Uint8List.fromList(List<int>.filled(64, 1)),
          )
        : null,
  );
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

final class _CountingIterable extends Iterable<Lf3ProfileDefinition> {
  _CountingIterable(this.values);

  final List<Lf3ProfileDefinition> values;
  int iterations = 0;

  @override
  Iterator<Lf3ProfileDefinition> get iterator {
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
    final root = await Directory.systemTemp.createTemp('atlas-lf3-runner-');
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
datasetVersion=lf3-test
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
