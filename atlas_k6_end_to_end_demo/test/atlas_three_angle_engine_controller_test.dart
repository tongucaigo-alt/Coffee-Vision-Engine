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
        final occurrences = controller.state.result!.symbolOccurrences;

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
        await controller.close();
      },
    );

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
