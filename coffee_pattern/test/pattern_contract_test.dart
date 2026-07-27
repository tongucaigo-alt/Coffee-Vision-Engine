import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('PatternEvidence', () {
    test('represents every approved canonical evidence identity', () {
      const global = PatternEvidence.globalFeatures();
      const region = PatternEvidence.regionFeature(PatternRegionId.middle);
      final component = PatternEvidence.componentFeature(7);
      final relation = PatternEvidence.spatialRelationFeature(
        sourceComponentId: 7,
        targetComponentId: 11,
      );
      const graph = PatternEvidence.graphStatistics();
      final structure = PatternEvidence.connectedStructure(3);

      expect(global.kind, PatternEvidenceKind.globalFeatures);
      expect(region.regionId, PatternRegionId.middle);
      expect(component.componentId, 7);
      expect(relation.sourceComponentId, 7);
      expect(relation.targetComponentId, 11);
      expect(graph.kind, PatternEvidenceKind.graphStatistics);
      expect(structure.structureId, 3);
    });

    test('rejects invalid canonical identities', () {
      expect(() => PatternEvidence.componentFeature(0), throwsArgumentError);
      expect(() => PatternEvidence.connectedStructure(-1), throwsArgumentError);
      expect(
        () => PatternEvidence.spatialRelationFeature(
          sourceComponentId: 2,
          targetComponentId: 2,
        ),
        throwsArgumentError,
      );
    });

    test('supports deterministic equality, hashCode, and safe toString', () {
      final first = PatternEvidence.spatialRelationFeature(
        sourceComponentId: 2,
        targetComponentId: 5,
      );
      final second = PatternEvidence.spatialRelationFeature(
        sourceComponentId: 2,
        targetComponentId: 5,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(<PatternEvidence>{first, second}, hasLength(1));
      expect(first.toString(), contains('sourceComponentId: 2'));
      expect(first.toString(), isNot(contains('meaning')));
    });
  });

  group('PatternCandidate', () {
    test('preserves canonical identity and evidence order without sorting', () {
      final evidence = <PatternEvidence>[
        const PatternEvidence.globalFeatures(),
        const PatternEvidence.regionFeature(PatternRegionId.top),
        PatternEvidence.componentFeature(3),
        PatternEvidence.spatialRelationFeature(
          sourceComponentId: 3,
          targetComponentId: 8,
        ),
        const PatternEvidence.graphStatistics(),
        PatternEvidence.connectedStructure(1),
      ];

      final candidate = PatternCandidate(id: 4, evidence: evidence);

      expect(candidate.id, 4);
      expect(candidate.evidence, evidence);
      expect(() => candidate.evidence.clear(), throwsUnsupportedError);
    });

    test('rejects empty, duplicate, and noncanonical evidence', () {
      expect(
        () => PatternCandidate(id: 1, evidence: const []),
        throwsArgumentError,
      );
      expect(
        () => PatternCandidate(
          id: 1,
          evidence: const [
            PatternEvidence.globalFeatures(),
            PatternEvidence.globalFeatures(),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => PatternCandidate(
          id: 1,
          evidence: [
            PatternEvidence.componentFeature(1),
            const PatternEvidence.regionFeature(PatternRegionId.top),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('supports immutable value semantics', () {
      final mutable = [PatternEvidence.componentFeature(9)];
      final first = PatternCandidate(id: 1, evidence: mutable);
      final second = PatternCandidate(
        id: 1,
        evidence: [PatternEvidence.componentFeature(9)],
      );
      mutable.clear();

      expect(first.evidence, hasLength(1));
      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.toString(), contains('id: 1'));
    });

    test(
      'preserves legacy equality while geometry distinguishes M8C values',
      () {
        final legacyFirst = PatternCandidate(
          id: 1,
          evidence: [PatternEvidence.componentFeature(9)],
        );
        final legacySecond = PatternCandidate(
          id: 1,
          evidence: [PatternEvidence.componentFeature(9)],
        );
        final described = PatternCandidate.withGeometry(
          id: 1,
          evidence: [PatternEvidence.componentFeature(9)],
          geometry: PatternGeometry(
            left: 0.1,
            top: 0.1,
            right: 0.2,
            bottom: 0.2,
            centroidX: 0.15,
            centroidY: 0.15,
          ),
        );

        expect(legacySecond, legacyFirst);
        expect(legacySecond.hashCode, legacyFirst.hashCode);
        expect(described, isNot(legacyFirst));
      },
    );
  });

  group('PatternAnalysisResult', () {
    test('preserves candidate IDs and order without regeneration', () {
      final candidates = [
        PatternCandidate(
          id: 1,
          evidence: [PatternEvidence.componentFeature(4)],
        ),
        PatternCandidate(
          id: 2,
          evidence: [PatternEvidence.componentFeature(9)],
        ),
      ];

      final result = PatternAnalysisResult(
        surfaceType: PatternSurfaceType.cup,
        sourceId: 'private-source',
        candidates: candidates,
      );

      expect(result.candidates.map((candidate) => candidate.id), [1, 2]);
      expect(() => result.candidates.clear(), throwsUnsupportedError);
      expect(result.toString(), contains('sourceIdPresent: true'));
      expect(result.toString(), isNot(contains('private-source')));
    });

    test('rejects reordered, regenerated, and duplicate candidates', () {
      final first = PatternCandidate(
        id: 1,
        evidence: [PatternEvidence.componentFeature(1)],
      );
      final second = PatternCandidate(
        id: 2,
        evidence: [PatternEvidence.componentFeature(2)],
      );

      expect(
        () => PatternAnalysisResult(
          surfaceType: PatternSurfaceType.cup,
          candidates: [second, first],
        ),
        throwsArgumentError,
      );
      expect(
        () => PatternAnalysisResult(
          surfaceType: PatternSurfaceType.cup,
          candidates: [
            first,
            PatternCandidate(
              id: 3,
              evidence: [PatternEvidence.componentFeature(3)],
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => PatternAnalysisResult(
          surfaceType: PatternSurfaceType.cup,
          candidates: [
            first,
            PatternCandidate(
              id: 2,
              evidence: [PatternEvidence.componentFeature(1)],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('supports empty immutable value results', () {
      final first = PatternAnalysisResult(
        surfaceType: PatternSurfaceType.saucer,
        candidates: const [],
      );
      final second = PatternAnalysisResult(
        surfaceType: PatternSurfaceType.saucer,
        candidates: const [],
      );

      expect(first.candidates, isEmpty);
      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });
  });
}
