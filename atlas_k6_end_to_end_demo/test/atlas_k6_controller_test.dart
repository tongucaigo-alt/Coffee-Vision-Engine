import 'dart:async';

import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_controller.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_result.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_state.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('AtlasK6Controller', () {
    test('runs the complete public chain in exact surface order', () async {
      final events = <String>[];
      final matcher = const KnowledgeRecordCollectionMatcher();
      final resolver = const SymbolCandidateResolver();
      final release = createKnowledgeRelease();
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: release,
        symbolDataset: createSymbolDataset(
          includeBindings: true,
          knowledgeRelease: release,
        ),
        readFile: (path) async {
          events.add('read:$path');
          return fakeRead(path);
        },
        analyzeFeatures: (input) async {
          events.add('vision:${input.surfaceType.name}');
          return createFeatureSet(input.surfaceType);
        },
        analyzePatterns: (featureSet) async {
          events.add('pattern:${featureSet.surfaceType.name}');
          return createPatternResult(featureSet);
        },
        matchRecords: ({required candidate, required records}) {
          events.add('knowledge:${candidate.id}');
          return matcher.match(candidate: candidate, records: records);
        },
        resolveSymbols:
            ({
              required knowledgeRelease,
              required knowledgeMatches,
              required definitions,
              required bindings,
            }) {
              events.add('symbol');
              return resolver.resolve(
                knowledgeRelease: knowledgeRelease,
                knowledgeMatches: knowledgeMatches,
                definitions: definitions,
                bindings: bindings,
              );
            },
      );

      expect(
        await controller.startCapture(() async => createCapture()),
        isTrue,
      );

      expect(events, [
        'read:cup-crop.jpg',
        'vision:cup',
        'pattern:cup',
        'knowledge:1',
        'symbol',
        'read:saucer-crop.jpg',
        'vision:saucer',
        'pattern:saucer',
        'knowledge:1',
        'symbol',
      ]);
      expect(controller.state.phase, AtlasK6Phase.success);
      expect(controller.state.result!.datasetVersion, 'kds-001');
      expect(controller.state.result!.cupResult.matchedRecordCount, 1);
      expect(controller.state.result!.saucerResult.matchedRecordCount, 1);
      expect(controller.state.result!.symbolCandidateCount, 2);
      expect(
        controller.state.aggregateOutcome,
        AtlasK6AggregateOutcome.symbolCandidatesAvailable,
      );
      await controller.close();
    });

    test('rejects a duplicate operation while processing is active', () async {
      final release = Completer<void>();
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async {
          await release.future;
          return createFeatureSet(input.surfaceType);
        },
        analyzePatterns: (featureSet) async => createPatternResult(featureSet),
      );

      final first = controller.startCapture(() async => createCapture());
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.phase, AtlasK6Phase.processingCup);
      expect(
        await controller.startCapture(() async => createCapture()),
        isFalse,
      );
      expect(await controller.retry(), isFalse);

      release.complete();
      await first;
      await controller.close();
    });

    test('cup failure stops before Pattern, Knowledge, and saucer', () async {
      var patternCalls = 0;
      var knowledgeCalls = 0;
      final surfaces = <VisionSurfaceType>[];
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async {
          surfaces.add(input.surfaceType);
          throw StateError('cup failure');
        },
        analyzePatterns: (featureSet) async {
          patternCalls++;
          return createPatternResult(featureSet);
        },
        matchRecords: ({required candidate, required records}) {
          knowledgeCalls++;
          return const [];
        },
      );

      await controller.startCapture(() async => createCapture());

      expect(controller.state.failureStage, AtlasK6FailureStage.cupProcessing);
      expect(surfaces, [VisionSurfaceType.cup]);
      expect(patternCalls, 0);
      expect(knowledgeCalls, 0);
      await controller.close();
    });

    test('saucer retry preserves cup and reruns only saucer', () async {
      var cupCalls = 0;
      var saucerCalls = 0;
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async {
          if (input.surfaceType == VisionSurfaceType.cup) {
            cupCalls++;
          } else {
            saucerCalls++;
            if (saucerCalls == 1) throw StateError('first saucer failure');
          }
          return createFeatureSet(input.surfaceType);
        },
        analyzePatterns: (featureSet) async => createPatternResult(featureSet),
      );

      await controller.startCapture(() async => createCapture());
      final preservedCup = controller.state.cupResult;
      expect(
        controller.state.failureStage,
        AtlasK6FailureStage.saucerProcessing,
      );
      expect(preservedCup, isNotNull);

      expect(await controller.retry(), isTrue);
      expect(controller.state.phase, AtlasK6Phase.success);
      expect(
        identical(controller.state.result!.cupResult, preservedCup),
        isTrue,
      );
      expect(cupCalls, 1);
      expect(saucerCalls, 2);
      await controller.close();
    });

    test('camera cancellation restores the previous stable state', () async {
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
      );

      await controller.startCapture(() async => null);

      expect(controller.state.phase, AtlasK6Phase.idle);
      await controller.close();
    });

    test(
      'close waits for active work and blocks stale state updates',
      () async {
        final release = Completer<void>();
        final controller = AtlasK6Controller(
          dataset: createDataset(),
          knowledgeRelease: createKnowledgeRelease(),
          symbolDataset: createSymbolDataset(),
          readFile: fakeRead,
          analyzeFeatures: (input) async {
            await release.future;
            return createFeatureSet(input.surfaceType);
          },
          analyzePatterns: (featureSet) async =>
              createPatternResult(featureSet),
        );

        unawaited(controller.startCapture(() async => createCapture()));
        await Future<void>.delayed(Duration.zero);
        var closeCompleted = false;
        final close = controller.close().then((_) => closeCompleted = true);
        await Future<void>.delayed(Duration.zero);
        expect(closeCompleted, isFalse);

        release.complete();
        await close;
        expect(closeCompleted, isTrue);
      },
    );

    test('result collections are runtime-unmodifiable', () async {
      final release = createKnowledgeRelease();
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: release,
        symbolDataset: createSymbolDataset(
          includeBindings: true,
          knowledgeRelease: release,
        ),
        readFile: fakeRead,
        analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
        analyzePatterns: (featureSet) async => createPatternResult(featureSet),
      );
      await controller.startCapture(() async => createCapture());
      final result = controller.state.result!.cupResult;

      expect(
        () => result.candidateResults.add(result.candidateResults.single),
        throwsUnsupportedError,
      );
      expect(
        () => result.candidateResults.single.matches.add(
          result.candidateResults.single.matches.single,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => result.symbolCandidates.add(result.symbolCandidates.single),
        throwsUnsupportedError,
      );
      await controller.close();
    });

    test('separates no match from missing Symbol evidence', () async {
      final noMatchController = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
        analyzePatterns: (featureSet) async => createPatternResult(
          featureSet,
          centroidX: 0.2,
          centroidY: 0.2,
          nodeCount: 1,
        ),
      );
      await noMatchController.startCapture(() async => createCapture());
      expect(
        noMatchController.state.aggregateOutcome,
        AtlasK6AggregateOutcome.noMatch,
      );
      expect(
        noMatchController
            .state
            .result!
            .cupResult
            .candidateResults
            .single
            .matches,
        hasLength(1),
      );
      await noMatchController.close();

      final insufficientController = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
        analyzePatterns: (featureSet) async => createPatternResult(featureSet),
      );
      await insufficientController.startCapture(() async => createCapture());
      expect(
        insufficientController.state.aggregateOutcome,
        AtlasK6AggregateOutcome.insufficientSymbolEvidence,
      );
      expect(insufficientController.state.result!.matchedRecordCount, 2);
      expect(insufficientController.state.result!.symbolCandidateCount, 0);
      await insufficientController.close();
    });

    test('empty Pattern output remains a complete no-match result', () async {
      var resolverCalls = 0;
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
        analyzePatterns: (featureSet) async => PatternAnalysisResult(
          surfaceType: featureSet.surfaceType == VisionSurfaceType.cup
              ? PatternSurfaceType.cup
              : PatternSurfaceType.saucer,
          candidates: const [],
        ),
        resolveSymbols:
            ({
              required knowledgeRelease,
              required knowledgeMatches,
              required definitions,
              required bindings,
            }) {
              resolverCalls++;
              return const SymbolCandidateResolver().resolve(
                knowledgeRelease: knowledgeRelease,
                knowledgeMatches: knowledgeMatches,
                definitions: definitions,
                bindings: bindings,
              );
            },
      );

      await controller.startCapture(() async => createCapture());

      expect(controller.state.result!.outcome, AtlasK6AggregateOutcome.noMatch);
      expect(controller.state.result!.cupResult.candidateResults, isEmpty);
      expect(controller.state.result!.saucerResult.candidateResults, isEmpty);
      expect(resolverCalls, 2);
      await controller.close();
    });

    test('preserves every Symbol candidate in deterministic order', () async {
      final release = createKnowledgeRelease();
      final symbols = createSymbolDataset(
        includeBindings: true,
        symbolCount: 2,
        knowledgeRelease: release,
      );

      Future<List<String>> run() async {
        final controller = AtlasK6Controller(
          dataset: createDataset(),
          knowledgeRelease: release,
          symbolDataset: symbols,
          readFile: fakeRead,
          analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
          analyzePatterns: (featureSet) async =>
              createPatternResult(featureSet),
        );
        await controller.startCapture(() async => createCapture());
        final result = controller.state.result!;
        expect(result.symbolCandidateCount, 4);
        expect(
          result.outcome,
          AtlasK6AggregateOutcome.symbolCandidatesAvailable,
        );
        final identities = [
          for (final candidate in result.cupResult.symbolCandidates)
            candidate.symbolId,
        ];
        await controller.close();
        return identities;
      }

      expect(await run(), ['test-symbol-001', 'test-symbol-002']);
      expect(await run(), ['test-symbol-001', 'test-symbol-002']);
    });

    test('maps resolver exceptions to a technical error', () async {
      final controller = AtlasK6Controller(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
        analyzePatterns: (featureSet) async => createPatternResult(featureSet),
        resolveSymbols:
            ({
              required knowledgeRelease,
              required knowledgeMatches,
              required definitions,
              required bindings,
            }) => throw StateError('stale fixture'),
      );

      await controller.startCapture(() async => createCapture());

      expect(controller.state.phase, AtlasK6Phase.failure);
      expect(controller.state.failureStage, AtlasK6FailureStage.cupProcessing);
      expect(
        controller.state.aggregateOutcome,
        AtlasK6AggregateOutcome.technicalError,
      );
      await controller.close();
    });

    test('rejects a Symbol dataset targeting another Knowledge release', () {
      final otherRelease = createKnowledgeRelease(
        releaseId: 'test-other-kds-001',
        checksum:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );

      expect(
        () => AtlasK6Controller(
          dataset: createDataset(),
          knowledgeRelease: createKnowledgeRelease(),
          symbolDataset: createSymbolDataset(
            includeBindings: true,
            knowledgeRelease: otherRelease,
          ),
          readFile: fakeRead,
        ),
        throwsArgumentError,
      );
    });
  });
}
