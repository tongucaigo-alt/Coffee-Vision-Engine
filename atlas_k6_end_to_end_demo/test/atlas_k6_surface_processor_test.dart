import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_result.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_surface_processor.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('AtlasK6SurfaceProcessor', () {
    test('runs each public stage exactly once per applicable input', () async {
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
            candidates: [_candidate(1), _candidate(2)],
          );
        },
        matchRecords: ({required candidate, required records}) {
          events.add('knowledge:${candidate.id}');
          return const [];
        },
        resolveSymbols:
            ({
              required knowledgeRelease,
              required knowledgeMatches,
              required definitions,
              required bindings,
            }) {
              events.add('symbol:${knowledgeMatches.length}');
              return const [];
            },
      );

      final result = await processor.process(
        path: 'test-cup.jpg',
        surfaceType: VisionSurfaceType.cup,
      );

      expect(events, [
        'read:test-cup.jpg',
        'vision:cup',
        'pattern:cup',
        'knowledge:1',
        'knowledge:2',
        'symbol:0',
      ]);
      expect(result.candidateResults, hasLength(2));
      expect(result.outcome, AtlasK6AggregateOutcome.noMatch);
    });

    test('still invokes Symbol resolution for empty Pattern output', () async {
      var resolverCalls = 0;
      final processor = AtlasK6SurfaceProcessor(
        dataset: createDataset(),
        knowledgeRelease: createKnowledgeRelease(),
        symbolDataset: createSymbolDataset(),
        readFile: fakeRead,
        analyzeFeatures: (input) async => createFeatureSet(input.surfaceType),
        analyzePatterns: (features) async => PatternAnalysisResult(
          surfaceType: PatternSurfaceType.cup,
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
              expect(knowledgeMatches, isEmpty);
              return const [];
            },
      );

      final result = await processor.process(
        path: 'test-empty.jpg',
        surfaceType: VisionSurfaceType.cup,
      );

      expect(resolverCalls, 1);
      expect(result.candidateResults, isEmpty);
      expect(result.outcome, AtlasK6AggregateOutcome.noMatch);
    });

    test(
      'reports the exact failing stage and publishes no later work',
      () async {
        var patternCalls = 0;
        var matcherCalls = 0;
        var resolverCalls = 0;
        final processor = AtlasK6SurfaceProcessor(
          dataset: createDataset(),
          knowledgeRelease: createKnowledgeRelease(),
          symbolDataset: createSymbolDataset(),
          readFile: fakeRead,
          analyzeFeatures: (_) async => throw StateError('test failure'),
          analyzePatterns: (_) async {
            patternCalls++;
            throw StateError('must not run');
          },
          matchRecords: ({required candidate, required records}) {
            matcherCalls++;
            return const [];
          },
          resolveSymbols:
              ({
                required knowledgeRelease,
                required knowledgeMatches,
                required definitions,
                required bindings,
              }) {
                resolverCalls++;
                return const [];
              },
        );

        await expectLater(
          processor.process(
            path: 'test-failure.jpg',
            surfaceType: VisionSurfaceType.cup,
          ),
          throwsA(
            isA<AtlasSurfaceProcessingException>().having(
              (error) => error.stage,
              'stage',
              AtlasSurfaceProcessingStage.vision,
            ),
          ),
        );
        expect(patternCalls, 0);
        expect(matcherCalls, 0);
        expect(resolverCalls, 0);
      },
    );
  });
}

PatternCandidate _candidate(int id) => PatternCandidate.withGeometryAndTopology(
  id: id,
  evidence: [PatternEvidence.connectedStructure(id)],
  geometry: PatternGeometry(
    left: 0.1,
    top: 0.1,
    right: 0.9,
    bottom: 0.9,
    centroidX: 0.5,
    centroidY: 0.5,
  ),
  topology: PatternTopology(nodeCount: 1, directedEdgeCount: 0),
);
