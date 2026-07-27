import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('PatternGeometry', () {
    test('exposes the approved normalized geometry contract', () {
      final geometry = PatternGeometry(
        left: 0.1,
        top: 0.2,
        right: 0.7,
        bottom: 0.6,
        centroidX: 0.4,
        centroidY: 0.35,
      );

      expect(geometry.left, 0.1);
      expect(geometry.top, 0.2);
      expect(geometry.right, 0.7);
      expect(geometry.bottom, 0.6);
      expect(geometry.centroidX, 0.4);
      expect(geometry.centroidY, 0.35);
      expect(geometry.width, closeTo(0.6, 1e-12));
      expect(geometry.height, closeTo(0.4, 1e-12));
      expect(geometry.aspectRatio, closeTo(1.5, 1e-12));
      expect(geometry.touchesWorkingImageBorder, isFalse);
    });

    test('derives working-image border contact from canonical bounds', () {
      PatternGeometry geometry({
        double left = 0.1,
        double top = 0.1,
        double right = 0.9,
        double bottom = 0.9,
      }) {
        return PatternGeometry(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          centroidX: (left + right) / 2,
          centroidY: (top + bottom) / 2,
        );
      }

      expect(geometry(left: 0.0).touchesWorkingImageBorder, isTrue);
      expect(geometry(top: 0.0).touchesWorkingImageBorder, isTrue);
      expect(geometry(right: 1.0).touchesWorkingImageBorder, isTrue);
      expect(geometry(bottom: 1.0).touchesWorkingImageBorder, isTrue);
      expect(geometry().touchesWorkingImageBorder, isFalse);
    });

    test('rejects non-finite and out-of-range coordinates', () {
      PatternGeometry create({
        double left = 0.1,
        double top = 0.1,
        double right = 0.9,
        double bottom = 0.9,
        double centroidX = 0.5,
        double centroidY = 0.5,
      }) {
        return PatternGeometry(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          centroidX: centroidX,
          centroidY: centroidY,
        );
      }

      expect(() => create(left: double.nan), throwsArgumentError);
      expect(() => create(right: double.infinity), throwsArgumentError);
      expect(() => create(top: -0.01), throwsArgumentError);
      expect(() => create(bottom: 1.01), throwsArgumentError);
      expect(
        () => create(centroidX: double.negativeInfinity),
        throwsArgumentError,
      );
      expect(() => create(centroidY: 1.01), throwsArgumentError);
    });

    test('rejects degenerate bounds and centroids outside the envelope', () {
      expect(
        () => PatternGeometry(
          left: 0.5,
          top: 0.1,
          right: 0.5,
          bottom: 0.9,
          centroidX: 0.5,
          centroidY: 0.5,
        ),
        throwsArgumentError,
      );
      expect(
        () => PatternGeometry(
          left: 0.1,
          top: 0.7,
          right: 0.9,
          bottom: 0.6,
          centroidX: 0.5,
          centroidY: 0.65,
        ),
        throwsArgumentError,
      );
      expect(
        () => PatternGeometry(
          left: 0.2,
          top: 0.2,
          right: 0.8,
          bottom: 0.8,
          centroidX: 0.1,
          centroidY: 0.5,
        ),
        throwsArgumentError,
      );
    });

    test('supports exact equality, hashCode, and safe toString', () {
      final first = PatternGeometry(
        left: 0.1,
        top: 0.2,
        right: 0.8,
        bottom: 0.7,
        centroidX: 0.3,
        centroidY: 0.4,
      );
      final second = PatternGeometry(
        left: 0.1,
        top: 0.2,
        right: 0.8,
        bottom: 0.7,
        centroidX: 0.3,
        centroidY: 0.4,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(<PatternGeometry>{first, second}, hasLength(1));
      expect(first.toString(), contains('centroidX: 0.3'));
      expect(first.toString(), isNot(contains('meaning')));
    });
  });

  group('PatternCandidate geometry compatibility', () {
    test('keeps the existing constructor as a legacy geometry-null path', () {
      final candidate = PatternCandidate(
        id: 1,
        evidence: [PatternEvidence.componentFeature(3)],
      );

      expect(candidate.geometry, isNull);
      expect(candidate.toString(), contains('geometryPresent: false'));
    });

    test(
      'attaches complete geometry without changing identity or evidence',
      () {
        final evidence = [
          PatternEvidence.componentFeature(3),
          PatternEvidence.connectedStructure(1),
        ];
        final geometry = PatternGeometry(
          left: 0.1,
          top: 0.2,
          right: 0.8,
          bottom: 0.7,
          centroidX: 0.3,
          centroidY: 0.4,
        );
        final candidate = PatternCandidate.withGeometry(
          id: 1,
          evidence: evidence,
          geometry: geometry,
        );

        expect(candidate.id, 1);
        expect(candidate.evidence, evidence);
        expect(candidate.geometry, same(geometry));
        expect(candidate.toString(), contains('geometryPresent: true'));
      },
    );

    test('includes geometry in equality and hashCode', () {
      PatternCandidate candidate(double centroidX) {
        return PatternCandidate.withGeometry(
          id: 1,
          evidence: [PatternEvidence.componentFeature(3)],
          geometry: PatternGeometry(
            left: 0.0,
            top: 0.0,
            right: 1.0,
            bottom: 1.0,
            centroidX: centroidX,
            centroidY: 0.5,
          ),
        );
      }

      final first = candidate(0.4);
      final sameValue = candidate(0.4);
      final different = candidate(0.6);

      expect(sameValue, first);
      expect(sameValue.hashCode, first.hashCode);
      expect(different, isNot(first));
      expect(<PatternCandidate>{first, sameValue, different}, hasLength(2));
    });
  });
}
