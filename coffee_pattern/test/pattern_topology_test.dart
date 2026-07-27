import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('PatternTopology', () {
    test('exposes only the approved canonical structural measurements', () {
      final topology = PatternTopology(nodeCount: 3, directedEdgeCount: 4);

      expect(topology.nodeCount, 3);
      expect(topology.directedEdgeCount, 4);
      expect(topology.isIsolated, isFalse);
    });

    test('derives isolation only for one node with zero directed edges', () {
      expect(
        PatternTopology(nodeCount: 1, directedEdgeCount: 0).isIsolated,
        isTrue,
      );
      expect(
        PatternTopology(nodeCount: 2, directedEdgeCount: 0).isIsolated,
        isFalse,
      );
      expect(
        PatternTopology(nodeCount: 2, directedEdgeCount: 1).isIsolated,
        isFalse,
      );
    });

    test('rejects invalid node and directed-edge counts', () {
      expect(
        () => PatternTopology(nodeCount: 0, directedEdgeCount: 0),
        throwsArgumentError,
      );
      expect(
        () => PatternTopology(nodeCount: 1, directedEdgeCount: -1),
        throwsArgumentError,
      );
      expect(
        () => PatternTopology(nodeCount: 1, directedEdgeCount: 1),
        throwsArgumentError,
      );
      expect(
        () => PatternTopology(nodeCount: 2, directedEdgeCount: 3),
        throwsArgumentError,
      );
    });

    test('accepts the canonical maximum directed-edge count', () {
      final topology = PatternTopology(nodeCount: 4, directedEdgeCount: 12);

      expect(topology.directedEdgeCount, 12);
    });

    test('supports exact equality, hashCode, and safe toString', () {
      final first = PatternTopology(nodeCount: 3, directedEdgeCount: 2);
      final second = PatternTopology(nodeCount: 3, directedEdgeCount: 2);
      final different = PatternTopology(nodeCount: 3, directedEdgeCount: 3);

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(different, isNot(first));
      expect(<PatternTopology>{first, second, different}, hasLength(2));
      expect(first.toString(), contains('nodeCount: 3'));
      expect(first.toString(), contains('directedEdgeCount: 2'));
      expect(first.toString(), contains('isIsolated: false'));
      for (final forbidden in ['tree', 'chain', 'star', 'ring', 'meaning']) {
        expect(first.toString().toLowerCase(), isNot(contains(forbidden)));
      }
    });
  });

  group('PatternCandidate topology compatibility', () {
    final geometry = PatternGeometry(
      left: 0.1,
      top: 0.1,
      right: 0.4,
      bottom: 0.4,
      centroidX: 0.2,
      centroidY: 0.2,
    );

    test('keeps M8A and M8B legacy construction topology-null', () {
      final candidate = PatternCandidate(
        id: 1,
        evidence: [PatternEvidence.componentFeature(4)],
      );

      expect(candidate.geometry, isNull);
      expect(candidate.topology, isNull);
    });

    test('keeps the M8C geometry construction topology-null', () {
      final candidate = PatternCandidate.withGeometry(
        id: 1,
        evidence: [PatternEvidence.componentFeature(4)],
        geometry: geometry,
      );

      expect(candidate.geometry, same(geometry));
      expect(candidate.topology, isNull);
    });

    test(
      'attaches geometry and topology atomically without changing evidence',
      () {
        final evidence = [
          PatternEvidence.componentFeature(4),
          PatternEvidence.connectedStructure(1),
        ];
        final topology = PatternTopology(nodeCount: 1, directedEdgeCount: 0);
        final candidate = PatternCandidate.withGeometryAndTopology(
          id: 1,
          evidence: evidence,
          geometry: geometry,
          topology: topology,
        );

        expect(candidate.id, 1);
        expect(candidate.evidence, evidence);
        expect(candidate.geometry, same(geometry));
        expect(candidate.topology, same(topology));
        expect(candidate.toString(), contains('topologyPresent: true'));
      },
    );

    test('includes topology in candidate equality and hashCode', () {
      PatternCandidate candidate(int edgeCount) {
        return PatternCandidate.withGeometryAndTopology(
          id: 1,
          evidence: [PatternEvidence.componentFeature(4)],
          geometry: geometry,
          topology: PatternTopology(nodeCount: 2, directedEdgeCount: edgeCount),
        );
      }

      final first = candidate(1);
      final sameValue = candidate(1);
      final different = candidate(2);

      expect(sameValue, first);
      expect(sameValue.hashCode, first.hashCode);
      expect(different, isNot(first));
    });
  });
}
