import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

import '../tool/src/lf2_models.dart';
import '../tool/src/lf2_morphology.dart';
import '../tool/src/lf2_profiles.dart';

void main() {
  group('LF-2 morphology', () {
    test('freezes the exact eight-profile matrix', () {
      expect(lf2Profiles, hasLength(8));
      expect(lf2Profiles.map((profile) => profile.id), [
        'lf2-p00-r04-a0005',
        'lf2-p01-r08-a0005',
        'lf2-p02-r16-a0005',
        'lf2-p03-r24-a0005',
        'lf2-p04-r04-a0020',
        'lf2-p05-r08-a0020',
        'lf2-p06-r16-a0020',
        'lf2-p07-r24-a0020',
      ]);
      expect(lf2Profiles.map((profile) => profile.closingRadius), [
        4,
        8,
        16,
        24,
        4,
        8,
        16,
        24,
      ]);
      expect(lf2Profiles.take(4).map((value) => value.minimumRegionRatio), [
        0.0005,
        0.0005,
        0.0005,
        0.0005,
      ]);
      expect(lf2Profiles.skip(4).map((value) => value.minimumRegionRatio), [
        0.002,
        0.002,
        0.002,
        0.002,
      ]);
    });

    test('closing joins nearby residue while preserving original pixels', () {
      final result = _extract(
        width: 16,
        height: 16,
        residue: {
          for (var y = 5; y <= 8; y++)
            for (var x = 2; x <= 4; x++) y * 16 + x,
          for (var y = 5; y <= 8; y++)
            for (var x = 7; x <= 9; x++) y * 16 + x,
        },
        radius: 2,
      );

      final residue = result.candidates.where(
        (candidate) => candidate.polarity == Lf2Polarity.residue,
      );
      expect(residue, hasLength(1));
      expect(residue.single.pixelCount, 24);
      expect(result.residuePixelsConserved, isTrue);
      expect(result.originalResiduePixelCount, 24);
      expect(result.assignedResiduePixelCount, 24);
    });

    test('detects only enclosed negative regions with two contact sectors', () {
      final residue = <int>{};
      for (var y = 3; y <= 11; y++) {
        for (var x = 3; x <= 11; x++) {
          if (x <= 5 || x >= 9 || y <= 5 || y >= 9) {
            residue.add(y * 16 + x);
          }
        }
      }
      final result = _extract(
        width: 16,
        height: 16,
        residue: residue,
        radius: 4,
      );

      final negative = result.candidates.where(
        (candidate) => candidate.polarity == Lf2Polarity.negativeSpace,
      );
      expect(negative, isNotEmpty);
      expect(
        negative.every((candidate) => candidate.residueContactSectorCount >= 2),
        isTrue,
      );
      expect(
        negative.every(
          (candidate) =>
              candidate.left > 0 &&
              candidate.top > 0 &&
              candidate.right < 1 &&
              candidate.bottom < 1,
        ),
        isTrue,
      );
    });

    test('never emits a negative region touching content boundary', () {
      final result = _extract(
        width: 12,
        height: 12,
        residue: {
          for (var y = 0; y < 12; y++) y * 12 + 3,
          for (var y = 0; y < 12; y++) y * 12 + 7,
        },
        radius: 3,
      );

      final negative = result.candidates.where(
        (candidate) => candidate.polarity == Lf2Polarity.negativeSpace,
      );
      expect(
        negative.every(
          (candidate) =>
              candidate.left > 0 &&
              candidate.top > 0 &&
              candidate.right < 1 &&
              candidate.bottom < 1,
        ),
        isTrue,
      );
    });

    test('reports suppressed residue instead of silently losing it', () {
      final result = _extract(
        width: 20,
        height: 20,
        residue: {21},
        radius: 2,
        minimumRatio: 0.01,
      );

      expect(result.candidates, isEmpty);
      expect(result.originalResiduePixelCount, 1);
      expect(result.emittedResiduePixelCount, 0);
      expect(result.suppressedResiduePixelCount, 1);
      expect(result.residuePixelsConserved, isTrue);
    });

    test('uses canonical polarity and row-major candidate ordering', () {
      final result = _extract(
        width: 20,
        height: 20,
        residue: {
          for (var y = 2; y <= 4; y++)
            for (var x = 2; x <= 4; x++) y * 20 + x,
          for (var y = 12; y <= 14; y++)
            for (var x = 12; x <= 14; x++) y * 20 + x,
        },
        radius: 1,
      );

      expect(result.candidates.map((candidate) => candidate.candidateId), [
        1,
        2,
      ]);
      expect(
        result.candidates.map((candidate) => candidate.polarity),
        everyElement(Lf2Polarity.residue),
      );
      expect(
        result.candidates[0].minimumRowMajorPixelIndex,
        lessThan(result.candidates[1].minimumRowMajorPixelIndex),
      );
      expect(
        () => result.candidates.add(result.candidates.first),
        throwsUnsupportedError,
      );
    });

    test('is deterministic and does not mutate the public mask', () {
      final pixels = Uint8List(100)
        ..[44] = 1
        ..[45] = 1;
      final mask = ResidueMask(
        width: 10,
        height: 10,
        pixels: pixels,
        residueRatio: 0.02,
      );
      final before = mask.pixels;
      final profile = Lf2ProfileDefinition(
        id: 'test-profile',
        closingRadius: 2,
        minimumRegionRatio: 0.001,
      );
      final first = const Lf2MorphologyExtractor().extract(
        profileId: profile.id,
        sourceId: 'test-source',
        mask: mask,
        contentRect: _fullRect,
        profile: profile,
      );
      final second = const Lf2MorphologyExtractor().extract(
        profileId: profile.id,
        sourceId: 'test-source',
        mask: mask,
        contentRect: _fullRect,
        profile: profile,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(mask.pixels, before);
    });

    test('handles empty and full masks with complete conservation', () {
      final empty = _extract(width: 8, height: 8, residue: const {}, radius: 2);
      final full = _extract(
        width: 8,
        height: 8,
        residue: {for (var pixel = 0; pixel < 64; pixel++) pixel},
        radius: 2,
      );

      expect(empty.candidates, isEmpty);
      expect(empty.residuePixelsConserved, isTrue);
      expect(full.residuePixelsConserved, isTrue);
      expect(full.candidates, hasLength(1));
      expect(full.candidates.single.pixelCount, 64);
    });
  });
}

final VisionRect _fullRect = VisionRect(left: 0, top: 0, right: 1, bottom: 1);

Lf2ExtractionResult _extract({
  required int width,
  required int height,
  required Set<int> residue,
  required int radius,
  double minimumRatio = 0.001,
}) {
  final pixels = Uint8List(width * height);
  for (final pixel in residue) {
    pixels[pixel] = 1;
  }
  final profile = Lf2ProfileDefinition(
    id: 'test-profile',
    closingRadius: radius,
    minimumRegionRatio: minimumRatio,
  );
  return const Lf2MorphologyExtractor().extract(
    profileId: 'test-profile',
    sourceId: 'test-source',
    mask: ResidueMask(
      width: width,
      height: height,
      pixels: pixels,
      residueRatio: residue.length / (width * height),
    ),
    contentRect: _fullRect,
    profile: profile,
  );
}
