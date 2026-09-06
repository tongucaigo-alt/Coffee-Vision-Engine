import 'dart:async';
import 'dart:ui';

import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_models.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_result.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_surface_processor.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_three_angle_engine_controller.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_three_angle_engine_models.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('AtlasThreeAngleEngineController', () {
    test('processes exact roles sequentially as cup surfaces', () async {
      final events = <String>[];
      final processor = AtlasK6SurfaceProcessor(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: (path) async {
          events.add('read:$path');
          return fakeRead(path);
        },
        analyzeFeatures: (input) async {
          events.add('vision:${input.surfaceType.name}');
          return createFeatureSet(input.surfaceType);
        },
        analyzePatterns: (features) async {
          events.add('pattern:${features.surfaceType.name}');
          return PatternAnalysisResult(
            surfaceType: PatternSurfaceType.cup,
            candidates: const [],
          );
        },
        resolveSymbols:
            ({
              required knowledgeRelease,
              required knowledgeMatches,
              required definitions,
              required bindings,
            }) {
              events.add('symbol');
              return const [];
            },
      );
      final controller = AtlasThreeAngleEngineController.withProcessor(
        processor,
      );

      expect(await controller.analyze(_captureResult()), isTrue);

      expect(events, [
        'read:test-top-crop.jpg',
        'vision:cup',
        'pattern:cup',
        'symbol',
        'read:test-right.jpg',
        'vision:cup',
        'pattern:cup',
        'symbol',
        'read:test-left.jpg',
        'vision:cup',
        'pattern:cup',
        'symbol',
      ]);
      expect(
        controller.state.result!.angleResults.map((angle) => angle.role),
        AtlasCupCaptureRole.values,
      );
      await controller.close();
    });

    test('preserves mixed angle outcomes without a session winner', () async {
      final surfaces = {
        AtlasCupCaptureRole.top: _surfaceNoMatch(),
        AtlasCupCaptureRole.handleRight: _surfaceInsufficient(),
        AtlasCupCaptureRole.handleLeft: _surfaceWithSymbol(),
      };
      final controller = AtlasThreeAngleEngineController(
        processSurface: ({required role, required path}) async =>
            surfaces[role]!,
      );

      await controller.analyze(_captureResult());
      final result = controller.state.result!;

      expect(
        result.resultFor(AtlasCupCaptureRole.top).outcome,
        AtlasK6AggregateOutcome.noMatch,
      );
      expect(
        result.resultFor(AtlasCupCaptureRole.handleRight).outcome,
        AtlasK6AggregateOutcome.insufficientSymbolEvidence,
      );
      expect(
        result.resultFor(AtlasCupCaptureRole.handleLeft).outcome,
        AtlasK6AggregateOutcome.symbolCandidatesAvailable,
      );
      expect(result.symbolOccurrences, hasLength(1));
      expect(
        result.symbolOccurrences.single.role,
        AtlasCupCaptureRole.handleLeft,
      );
      expect(result.symbolOccurrences.single.symbolId, 'test-symbol-001');
      await controller.close();
    });

    test(
      'continues after one angle fails and retries only that angle',
      () async {
        final calls = <AtlasCupCaptureRole>[];
        var rightAttempts = 0;
        final controller = AtlasThreeAngleEngineController(
          processSurface: ({required role, required path}) async {
            calls.add(role);
            if (role == AtlasCupCaptureRole.handleRight &&
                rightAttempts++ == 0) {
              throw AtlasSurfaceProcessingException(
                stage: AtlasSurfaceProcessingStage.vision,
                cause: StateError('test-only failure'),
              );
            }
            return role == AtlasCupCaptureRole.handleRight
                ? _surfaceWithSymbol()
                : _surfaceNoMatch();
          },
        );

        await controller.analyze(_captureResult());
        final first = controller.state.result!;
        final preservedTop = first.resultFor(AtlasCupCaptureRole.top);
        final preservedLeft = first.resultFor(AtlasCupCaptureRole.handleLeft);
        expect(calls, AtlasCupCaptureRole.values);
        expect(first.technicalErrorCount, 1);
        expect(
          first.resultFor(AtlasCupCaptureRole.handleRight).failureStage,
          AtlasSurfaceProcessingStage.vision,
        );

        expect(await controller.retry(AtlasCupCaptureRole.handleRight), isTrue);
        final retried = controller.state.result!;
        expect(calls, [
          ...AtlasCupCaptureRole.values,
          AtlasCupCaptureRole.handleRight,
        ]);
        expect(
          identical(retried.resultFor(AtlasCupCaptureRole.top), preservedTop),
          isTrue,
        );
        expect(
          identical(
            retried.resultFor(AtlasCupCaptureRole.handleLeft),
            preservedLeft,
          ),
          isTrue,
        );
        expect(retried.technicalErrorCount, 0);
        expect(
          retried.symbolOccurrences.single.role,
          AtlasCupCaptureRole.handleRight,
        );
        await controller.close();
      },
    );

    test(
      'keeps identical candidate identities separate across roles',
      () async {
        final sharedSurface = _surfaceWithSymbol();
        final controller = AtlasThreeAngleEngineController(
          processSurface: ({required role, required path}) async =>
              sharedSurface,
        );

        await controller.analyze(_captureResult());
        final result = controller.state.result!;
        final occurrences = result.symbolOccurrences;

        expect(occurrences, hasLength(3));
        expect(
          occurrences.map((item) => item.role),
          AtlasCupCaptureRole.values,
        );
        expect(occurrences.map((item) => item.patternCandidateId), [1, 1, 1]);
        expect(occurrences.map((item) => item.symbolId), [
          'test-symbol-001',
          'test-symbol-001',
          'test-symbol-001',
        ]);
        expect(
          () => occurrences.add(occurrences.first),
          throwsUnsupportedError,
        );
        expect(result.symbolGroups, hasLength(1));
        final group = result.symbolGroups.single;
        expect(
          identical(
            group.definition,
            sharedSurface.symbolCandidates.single.definition,
          ),
          isTrue,
        );
        expect(group.occurrenceCount, 3);
        expect(group.angleCount, 3);
        expect(group.isMultiAngle, isTrue);
        expect(group.roles, AtlasCupCaptureRole.values);
        expect(() => result.symbolGroups.add(group), throwsUnsupportedError);
        expect(
          () => group.roles.add(AtlasCupCaptureRole.top),
          throwsUnsupportedError,
        );
        await controller.close();
      },
    );

    test('preserves same-angle occurrences and orders them canonically', () {
      final template = _surfaceWithSymbol().symbolCandidates.single;
      final first = _candidateForDefinition(
        template.definition,
        patternCandidateId: 1,
        identitySeed: 70,
      );
      final second = _candidateForDefinition(
        template.definition,
        patternCandidateId: 2,
        identitySeed: 71,
      );
      final group = AtlasThreeAngleSymbolGroup(
        definition: template.definition,
        occurrences: [
          AtlasThreeAngleSymbolOccurrence(
            role: AtlasCupCaptureRole.handleRight,
            candidate: first,
          ),
          AtlasThreeAngleSymbolOccurrence(
            role: AtlasCupCaptureRole.top,
            candidate: second,
          ),
          AtlasThreeAngleSymbolOccurrence(
            role: AtlasCupCaptureRole.top,
            candidate: first,
          ),
        ],
      );

      expect(group.occurrenceCount, 3);
      expect(group.angleCount, 2);
      expect(group.roles, [
        AtlasCupCaptureRole.top,
        AtlasCupCaptureRole.handleRight,
      ]);
      expect(
        group.occurrences.map(
          (occurrence) =>
              '${occurrence.role.name}:'
              '${occurrence.patternCandidateId}',
        ),
        ['top:1', 'top:2', 'handleRight:1'],
      );
      expect(
        () => group.occurrences.add(group.occurrences.first),
        throwsUnsupportedError,
      );

      final equalButDistinctDefinition = SymbolDefinition(
        symbolRef: template.definition.symbolRef,
        canonicalJsonProfileRef: template.definition.canonicalJsonProfileRef,
        preferredNames: template.definition.preferredNames,
        neutralDefinitions: template.definition.neutralDefinitions,
      );
      final inconsistentOccurrence = AtlasThreeAngleSymbolOccurrence(
        role: AtlasCupCaptureRole.handleLeft,
        candidate: _candidateForDefinition(
          equalButDistinctDefinition,
          patternCandidateId: 3,
          identitySeed: 72,
        ),
      );
      expect(
        () => AtlasThreeAngleSymbolGroup(
          definition: template.definition,
          occurrences: [group.occurrences.first, inconsistentOccurrence],
        ),
        throwsArgumentError,
      );
    });

    test('does not merge distinct symbol revisions or checksums', () async {
      final first = _surfaceWithSymbol().symbolCandidates.single;
      final secondDefinition = SymbolDefinition(
        symbolRef: SymbolRevisionRef(
          symbolId: first.symbolId,
          revision: first.symbolRevision,
          checksum: _testChecksum(90),
        ),
        canonicalJsonProfileRef: first.definition.canonicalJsonProfileRef,
        preferredNames: first.definition.preferredNames,
        neutralDefinitions: first.definition.neutralDefinitions,
      );
      final second = _candidateForDefinition(
        secondDefinition,
        patternCandidateId: 1,
        identitySeed: 91,
      );
      final thirdDefinition = SymbolDefinition(
        symbolRef: SymbolRevisionRef(
          symbolId: first.symbolId,
          revision: 2,
          checksum: _testChecksum(92),
        ),
        canonicalJsonProfileRef: first.definition.canonicalJsonProfileRef,
        preferredNames: first.definition.preferredNames,
        neutralDefinitions: first.definition.neutralDefinitions,
      );
      final third = _candidateForDefinition(
        thirdDefinition,
        patternCandidateId: 1,
        identitySeed: 93,
      );
      final surfaces = {
        AtlasCupCaptureRole.top: _surfaceFromCandidates([first]),
        AtlasCupCaptureRole.handleRight: _surfaceFromCandidates([second]),
        AtlasCupCaptureRole.handleLeft: _surfaceFromCandidates([third]),
      };
      final controller = AtlasThreeAngleEngineController(
        processSurface: ({required role, required path}) async =>
            surfaces[role]!,
      );

      await controller.analyze(_captureResult());
      final groups = controller.state.result!.symbolGroups;

      expect(groups, hasLength(3));
      expect(groups.map((group) => group.symbolRef.symbolId), [
        first.symbolId,
        first.symbolId,
        first.symbolId,
      ]);
      expect(groups.map((group) => group.symbolRef.revision), [1, 1, 2]);
      expect(groups.map((group) => group.symbolRef.checksum), [
        first.definition.symbolRef.checksum,
        secondDefinition.symbolRef.checksum,
        thirdDefinition.symbolRef.checksum,
      ]);
      expect(groups.every((group) => group.angleCount == 1), isTrue);
      await controller.close();
    });

    test(
      'rejects concurrent work and blocks retry for successful angles',
      () async {
        final release = Completer<AtlasK6SurfaceResult>();
        final controller = AtlasThreeAngleEngineController(
          processSurface: ({required role, required path}) => release.future,
        );
        final capture = _captureResult();

        final first = controller.analyze(capture);
        await Future<void>.delayed(Duration.zero);
        expect(await controller.analyze(capture), isFalse);
        expect(await controller.retry(AtlasCupCaptureRole.top), isFalse);

        release.complete(_surfaceNoMatch());
        await first;
        expect(await controller.analyze(capture), isFalse);
        expect(await controller.retry(AtlasCupCaptureRole.top), isFalse);
        expect(controller.reset(), isTrue);
        expect(controller.state.phase, AtlasThreeAngleEnginePhase.idle);
        await controller.close();
      },
    );

    test('setup failure blocks analysis and survives reset', () async {
      var calls = 0;
      final controller = AtlasThreeAngleEngineController(
        processSurface: ({required role, required path}) async {
          calls++;
          return _surfaceNoMatch();
        },
        setupError: 'Test setup doğrulanamadı.',
      );

      expect(controller.state.setupError, 'Test setup doğrulanamadı.');
      expect(await controller.analyze(_captureResult()), isFalse);
      expect(calls, 0);
      expect(controller.reset(), isTrue);
      expect(controller.state.setupError, 'Test setup doğrulanamadı.');
      await controller.close();
    });
  });
}

AtlasThreeAngleCupCaptureResult _captureResult() =>
    AtlasThreeAngleCupCaptureResult([
      AtlasCupCaptureSlot(
        role: AtlasCupCaptureRole.top,
        capture: _capture('test-top.jpg', croppedCupPath: 'test-top-crop.jpg'),
      ),
      AtlasCupCaptureSlot(
        role: AtlasCupCaptureRole.handleRight,
        capture: _capture('test-right.jpg'),
      ),
      AtlasCupCaptureSlot(
        role: AtlasCupCaptureRole.handleLeft,
        capture: _capture('test-left.jpg'),
      ),
    ]);

CameraCaptureResult _capture(String path, {String? croppedCupPath}) =>
    CameraCaptureResult(
      filePath: path,
      croppedCupPath: croppedCupPath,
      cropRect: const Rect.fromLTWH(0, 0, 10, 10),
      widthPixels: 100,
      heightPixels: 100,
      fileSizeBytes: 10,
      croppedWidthPixels: croppedCupPath == null ? null : 80,
      croppedHeightPixels: croppedCupPath == null ? null : 80,
      croppedFileSizeBytes: croppedCupPath == null ? null : 8,
      capturedAt: DateTime.utc(2026, 9, 5),
      qualityScore: 80,
      coffeePresenceScore: 0.8,
      coffeeDetected: true,
      mode: CameraCaptureMode.manual,
    );

AtlasK6SurfaceResult _surfaceNoMatch() {
  final features = createFeatureSet(VisionSurfaceType.cup);
  return AtlasK6SurfaceResult(
    featureSet: features,
    patternResult: PatternAnalysisResult(
      surfaceType: PatternSurfaceType.cup,
      candidates: const [],
    ),
    candidateResults: const [],
    symbolCandidates: const [],
    processingDuration: Duration.zero,
  );
}

AtlasK6SurfaceResult _surfaceInsufficient() {
  final features = createFeatureSet(VisionSurfaceType.cup);
  final pattern = createPatternResult(features);
  final matches = const KnowledgeRecordCollectionMatcher().match(
    candidate: pattern.candidates.single,
    records: createDataset().activeRecords,
  );
  return AtlasK6SurfaceResult(
    featureSet: features,
    patternResult: pattern,
    candidateResults: [
      AtlasK6CandidateResult(
        candidate: pattern.candidates.single,
        matches: matches,
      ),
    ],
    symbolCandidates: const [],
    processingDuration: Duration.zero,
  );
}

AtlasK6SurfaceResult _surfaceWithSymbol() {
  final insufficient = _surfaceInsufficient();
  final release = createKnowledgeRelease();
  final symbols = createSymbolDataset(
    includeBindings: true,
    knowledgeRelease: release,
  );
  final candidates = const SymbolCandidateResolver().resolve(
    knowledgeRelease: release,
    knowledgeMatches: [
      for (final candidate in insufficient.candidateResults)
        ...candidate.matches,
    ],
    definitions: symbols.definitions,
    bindings: symbols.bindings,
  );
  return AtlasK6SurfaceResult(
    featureSet: insufficient.featureSet,
    patternResult: insufficient.patternResult,
    candidateResults: insufficient.candidateResults,
    symbolCandidates: candidates,
    processingDuration: Duration.zero,
  );
}

SymbolCandidate _candidateForDefinition(
  SymbolDefinition definition, {
  required int patternCandidateId,
  required int identitySeed,
}) {
  final pattern = _patternCandidate(patternCandidateId);
  final match = const KnowledgeRecordCollectionMatcher()
      .match(candidate: pattern, records: createDataset().activeRecords)
      .single;
  final binding = SymbolEvidenceBinding(
    bindingId: 'test-binding-$identitySeed',
    revision: 1,
    canonicalJsonProfileRef: definition.canonicalJsonProfileRef,
    symbolRef: definition.symbolRef,
    knowledgeTargetRef: KnowledgeTargetRef(
      knowledgeRelease: createKnowledgeRelease(),
      knowledgeRecordId: match.recordId,
    ),
    evidenceAssessmentRefs: [
      EvidenceAssessmentRef(
        assessmentId: 'test-assessment-$identitySeed',
        revision: 1,
        assessmentType: EvidenceAssessmentType.holdoutValidation,
        checksum: _testChecksum(identitySeed),
      ),
    ],
  );
  return SymbolCandidate(
    patternCandidateId: patternCandidateId,
    definition: definition,
    supports: [SymbolCandidateSupport(binding: binding, knowledgeMatch: match)],
  );
}

AtlasK6SurfaceResult _surfaceFromCandidates(
  List<SymbolCandidate> symbolCandidates,
) {
  final featureSet = createFeatureSet(VisionSurfaceType.cup);
  final ids =
      symbolCandidates
          .map((candidate) => candidate.patternCandidateId)
          .toSet()
          .toList(growable: false)
        ..sort();
  final patterns = [for (final id in ids) _patternCandidate(id)];
  final patternResult = PatternAnalysisResult(
    surfaceType: PatternSurfaceType.cup,
    candidates: patterns,
  );
  return AtlasK6SurfaceResult(
    featureSet: featureSet,
    patternResult: patternResult,
    candidateResults: [
      for (final pattern in patternResult.candidates)
        AtlasK6CandidateResult(
          candidate: pattern,
          matches: [
            for (final candidate in symbolCandidates)
              if (candidate.patternCandidateId == pattern.id)
                for (final support in candidate.supports)
                  support.knowledgeMatch,
          ],
        ),
    ],
    symbolCandidates: symbolCandidates,
    processingDuration: Duration.zero,
  );
}

PatternCandidate _patternCandidate(int id) =>
    PatternCandidate.withGeometryAndTopology(
      id: id,
      evidence: [PatternEvidence.connectedStructure(id)],
      geometry: PatternGeometry(
        left: 0.1,
        top: 0.1,
        right: 0.9,
        bottom: 0.9,
        centroidX: 0.51,
        centroidY: 0.50,
      ),
      topology: PatternTopology(nodeCount: 62, directedEdgeCount: 0),
    );

String _testChecksum(int value) =>
    'sha256:${value.toRadixString(16).padLeft(64, '0')}';
