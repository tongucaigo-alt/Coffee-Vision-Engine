import 'dart:convert';
import 'dart:io';

import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/local_formation_profile_runner.dart';
import '../tool/src/lf1_profiles.dart';
import '../tool/src/lf1_report.dart';
import '../tool/src/lf1_runner.dart';

void main() {
  group('LF-1 profile research', () {
    test('freezes the exact eight-profile matrix', () {
      expect(lf1Profiles, hasLength(8));
      expect(lf1Profiles.map((definition) => definition.id), [
        'p00-pass-through',
        'p01-outgoing-1',
        'p02-outgoing-2',
        'p03-touch-only-outgoing-2',
        'p04-zero-gap-outgoing-2',
        'p05-gap-2px-outgoing-2',
        'p06-gap-4px-outgoing-2',
        'p07-gap-8px-outgoing-2',
      ]);
      expect(lf1Profiles[5].profile.maxBoundingBoxDistance, 2 / 512);
      expect(lf1Profiles[6].profile.maxBoundingBoxDistance, 4 / 512);
      expect(lf1Profiles[7].profile.maxBoundingBoxDistance, 8 / 512);
      expect(lf1Profiles[3].profile.requireBoundingBoxTouch, isTrue);
    });

    test('freezes the twenty-source review panel', () {
      expect(lf1ReviewPanelSourceIds, hasLength(20));
      expect(lf1ReviewPanelSourceIds.toSet(), hasLength(20));
      expect(
        lf1ReviewPanelSourceIds.where((id) => id.contains('saucer')),
        hasLength(4),
      );
    });

    test('materializes profiles once and rejects duplicates before work', () {
      final profiles = _CountingIterable(lf1Profiles);
      Lf1ProfileRunner(profiles: profiles);
      expect(profiles.iterations, 1);
      expect(
        () =>
            Lf1ProfileRunner(profiles: [lf1Profiles.first, lf1Profiles.first]),
        throwsArgumentError,
      );
    });

    test('runs Vision and Pattern exactly once per profile repeat', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      var visionCalls = 0;
      var patternCalls = 0;
      final seenProfiles = <VisionEdgeSelectionProfile>[];
      final runner = Lf1ProfileRunner(
        visionAnalyzer: (input, profile) {
          visionCalls++;
          seenProfiles.add(profile);
          return const CoffeeVisionEngine().analyzeFeatures(
            input,
            edgeSelectionProfile: profile,
          );
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

      expect(visionCalls, 24);
      expect(patternCalls, 24);
      expect(seenProfiles, hasLength(24));
      expect(report.observations, hasLength(8));
      expect(
        report.observations.every((value) => value.repeatsPerformed == 3),
        isTrue,
      );
      expect(report.succeeded, isTrue);
    });

    test('uses canonical profile and source ordering', () async {
      final fixture = await _Fixture.create(includeSaucer: true);
      addTearDown(fixture.dispose);
      final report = await Lf1ProfileRunner(profiles: lf1Profiles.reversed).run(
        datasetRoot: fixture.root.path,
        manifestPath: fixture.manifest.path,
        freezePath: fixture.freeze.path,
        repeatCount: 1,
      );

      expect(
        report.profileSummaries.map((value) => value.profileId),
        lf1Profiles.map((value) => value.id),
      );
      final keys = report.observations
          .map((value) => '${value.profileId}#${value.sourceId}')
          .toList();
      expect(keys, List<String>.of(keys)..sort());
      expect(
        () => report.observations.add(report.observations.first),
        throwsUnsupportedError,
      );
    });

    test(
      'continues after one profile failure without partial candidates',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        var calls = 0;
        final report =
            await Lf1ProfileRunner(
              visionAnalyzer: (input, profile) {
                calls++;
                if (profile == lf1Profiles.first.profile) {
                  throw StateError('synthetic failure');
                }
                return const CoffeeVisionEngine().analyzeFeatures(
                  input,
                  edgeSelectionProfile: profile,
                );
              },
            ).run(
              datasetRoot: fixture.root.path,
              manifestPath: fixture.manifest.path,
              freezePath: fixture.freeze.path,
              repeatCount: 1,
            );

        expect(calls, 8);
        expect(report.observations.first.analysisStatus.name, 'failed');
        expect(report.observations.first.candidates, isEmpty);
        expect(
          report.observations
              .skip(1)
              .every((value) => value.analysisStatus.name == 'success'),
          isTrue,
        );
      },
    );

    test('writes complete reports only outside the repository', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final report =
          await Lf1ProfileRunner(
            patternAnalyzer: (features) async => PatternAnalysisResult(
              surfaceType: features.surfaceType == VisionSurfaceType.cup
                  ? PatternSurfaceType.cup
                  : PatternSurfaceType.saucer,
              sourceId: features.sourceId,
              candidates: [_candidate()],
            ),
          ).run(
            datasetRoot: fixture.root.path,
            manifestPath: fixture.manifest.path,
            freezePath: fixture.freeze.path,
            repeatCount: 1,
          );
      final output = Directory(
        '${fixture.root.path}${Platform.pathSeparator}lfr-001',
      );
      final repositoryRoot = Directory.current.parent.path;
      final paths = await const Lf1ReportWriter().write(
        report: report,
        outputDirectory: output.path,
        repositoryRoot: repositoryRoot,
      );

      expect(paths, hasLength(2));
      final jsonSource = await File(paths.first).readAsString();
      expect(jsonSource, contains('p07-gap-8px-outgoing-2'));
      expect(jsonSource, contains('candidateIdentity'));
      expect(jsonSource, isNot(contains(fixture.root.path)));
      await expectLater(
        const Lf1ReportWriter().write(
          report: report,
          outputDirectory: repositoryRoot,
          repositoryRoot: repositoryRoot,
        ),
        throwsA(isA<Lf1ReportWriteException>()),
      );
    });

    test('CLI defaults to three repeats and lfr-001', () {
      final options = Lf1CliOptions.parse(const [
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
      expect(options.researchId, 'lfr-001');
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
      left: 0.1,
      top: 0.1,
      right: 0.3,
      bottom: 0.3,
      centroidX: 0.2,
      centroidY: 0.2,
    ),
    topology: PatternTopology(nodeCount: 1, directedEdgeCount: 0),
  );
}

final class _CountingIterable extends Iterable<Lf1ProfileDefinition> {
  _CountingIterable(this.values);

  final List<Lf1ProfileDefinition> values;
  int iterations = 0;

  @override
  Iterator<Lf1ProfileDefinition> get iterator {
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
    final root = await Directory.systemTemp.createTemp('atlas-lf1-runner-');
    final cupBytes = await File(
      '..${Platform.pathSeparator}coffee_vision${Platform.pathSeparator}test'
      '${Platform.pathSeparator}fixtures${Platform.pathSeparator}valid_2x3.png',
    ).readAsBytes();
    final entries = <Map<String, Object?>>[];
    await _addEntry(
      root,
      entries,
      'cup-001',
      'images/cup/cup.png',
      'cup',
      'png',
      cupBytes,
    );
    if (includeSaucer) {
      final saucerBytes = await File(
        '..${Platform.pathSeparator}coffee_vision${Platform.pathSeparator}test'
        '${Platform.pathSeparator}fixtures${Platform.pathSeparator}valid_3x2.jpg',
      ).readAsBytes();
      await _addEntry(
        root,
        entries,
        'saucer-001',
        'images/saucer/saucer.jpg',
        'saucer',
        'jpeg',
        saucerBytes,
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
datasetVersion=lf1-test
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
    String format,
    List<int> bytes,
  ) async {
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
