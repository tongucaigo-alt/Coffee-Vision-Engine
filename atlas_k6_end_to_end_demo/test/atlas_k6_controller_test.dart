import 'dart:async';

import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_controller.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_state.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('AtlasK6Controller', () {
    test('runs the complete public chain in exact surface order', () async {
      final events = <String>[];
      final matcher = const KnowledgeRecordCollectionMatcher();
      final controller = AtlasK6Controller(
        dataset: createDataset(),
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
        'read:saucer-crop.jpg',
        'vision:saucer',
        'pattern:saucer',
        'knowledge:1',
      ]);
      expect(controller.state.phase, AtlasK6Phase.success);
      expect(controller.state.result!.datasetVersion, 'kds-001');
      expect(controller.state.result!.cupResult.matchedRecordCount, 1);
      expect(controller.state.result!.saucerResult.matchedRecordCount, 1);
      await controller.close();
    });

    test('rejects a duplicate operation while processing is active', () async {
      final release = Completer<void>();
      final controller = AtlasK6Controller(
        dataset: createDataset(),
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
      final controller = AtlasK6Controller(
        dataset: createDataset(),
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
      await controller.close();
    });
  });
}
