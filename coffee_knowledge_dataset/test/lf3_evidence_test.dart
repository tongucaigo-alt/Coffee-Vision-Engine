import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

import '../tool/src/lf3_evidence.dart';
import '../tool/src/lf3_profiles.dart';

void main() {
  group('LF-3 profiles', () {
    test('defines the exact fixed sixteen-profile matrix', () {
      expect(lf3Profiles, hasLength(16));
      expect(
        lf3Profiles.map((value) => value.id),
        orderedEquals([
          'lf3-p00-binary-full-r04',
          'lf3-p01-binary-full-r08',
          'lf3-p02-binary-support-r04',
          'lf3-p03-binary-support-r08',
          'lf3-p04-global-t16-r04',
          'lf3-p05-global-t16-r08',
          'lf3-p06-global-t24-r04',
          'lf3-p07-global-t24-r08',
          'lf3-p08-local-t16-r04',
          'lf3-p09-local-t16-r08',
          'lf3-p10-local-t24-r04',
          'lf3-p11-local-t24-r08',
          'lf3-p12-fusion-t16-r04',
          'lf3-p13-fusion-t16-r08',
          'lf3-p14-fusion-t24-r04',
          'lf3-p15-fusion-t24-r08',
        ]),
      );
      expect(
        lf3Profiles.every((value) => value.minimumRegionRatio == 0.002),
        isTrue,
      );
      expect(lf3Profiles.map((value) => value.closingRadius).toSet(), {4, 8});
      expect(() => lf3Profiles.add(lf3Profiles.first), throwsUnsupportedError);
    });
  });

  group('LF-3 evidence', () {
    test('computes exact P75, 17x17 local mean, and fusion', () {
      final source = image.Image(width: 3, height: 3);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          source.setPixelRgb(x, y, 100, 100, 100);
        }
      }
      source.setPixelRgb(1, 1, 0, 0, 0);

      final frame = const Lf3EvidenceBuilder().build(_workingImage(source));

      expect(frame.globalBackgroundLuminance, 100);
      expect(frame.globalContrast[4], 100);
      expect(frame.localContrast[4], 89);
      expect(frame.fusion[4], 100);
      expect(frame.globalContrast.where((value) => value != 0), [100]);
      expect(frame.support, isNull);
    });

    test('restricts evidence to the working content rectangle', () {
      final source = image.Image(width: 4, height: 4);
      image.fill(source, color: image.ColorRgb8(100, 100, 100));
      source.setPixelRgb(0, 0, 0, 0, 0);
      source.setPixelRgb(2, 2, 0, 0, 0);
      final working = _workingImage(
        source,
        contentRect: VisionRect(left: 0.25, top: 0.25, right: 1, bottom: 1),
      );

      final frame = const Lf3EvidenceBuilder().build(working);

      expect(frame.globalContrast[0], 0);
      expect(frame.localContrast[0], 0);
      expect(frame.fusion[0], 0);
      expect(frame.globalContrast[10], greaterThan(0));
    });

    test(
      'detects deterministic ellipse support without full-frame fallback',
      () {
        final source = image.Image(width: 128, height: 128);
        image.fill(source, color: image.ColorRgb8(230, 230, 230));
        for (var y = 0; y < 128; y++) {
          for (var x = 0; x < 128; x++) {
            final dx = (x + 0.5 - 63.5) / 48;
            final dy = (y + 0.5 - 63.5) / 40;
            if (dx * dx + dy * dy <= 1) {
              source.setPixelRgb(x, y, 70, 70, 70);
            }
          }
        }
        final working = _workingImage(source);

        final first = const Lf3EvidenceBuilder().build(working).support;
        final second = const Lf3EvidenceBuilder().build(working).support;

        expect(first, isNotNull);
        expect(second, first);
        expect(first!.edgeContinuity, greaterThanOrEqualTo(0.48));
        expect(first.pixelCount, lessThan(128 * 128));

        final flat = image.Image(width: 128, height: 128);
        image.fill(flat, color: image.ColorRgb8(100, 100, 100));
        expect(
          const Lf3EvidenceBuilder().build(_workingImage(flat)).support,
          isNull,
        );
      },
    );

    test(
      'support-required mask fails closed and defensive copies are safe',
      () {
        final source = image.Image(width: 8, height: 8);
        image.fill(source, color: image.ColorRgb8(100, 100, 100));
        source.setPixelRgb(4, 4, 0, 0, 0);
        final frame = const Lf3EvidenceBuilder().build(_workingImage(source));
        final baselinePixels = Uint8List(64)..[36] = 1;
        final baseline = ResidueMask(
          width: 8,
          height: 8,
          pixels: baselinePixels,
          residueRatio: 1 / 64,
        );

        expect(
          const Lf3MaskFactory().create(
            baseline: baseline,
            evidence: frame,
            profile: lf3Profiles[2],
          ),
          isNull,
        );
        final mask = const Lf3MaskFactory().create(
          baseline: baseline,
          evidence: frame,
          profile: lf3Profiles.first,
        )!;
        final copy = mask.pixels..[36] = 0;
        expect(copy[36], 0);
        expect(mask.pixels[36], 1);
        expect(baseline.pixels[36], 1);
      },
    );
  });
}

WorkingImage _workingImage(image.Image source, {VisionRect? contentRect}) {
  final bytes = Uint8List.fromList(image.encodePng(source));
  final metadata = VisionImageMetadata(
    format: VisionImageFormat.png,
    width: source.width,
    height: source.height,
  );
  return WorkingImage(
    bytes: bytes,
    metadata: metadata,
    contentRect:
        contentRect ?? VisionRect(left: 0, top: 0, right: 1, bottom: 1),
    resolution: source.width,
  );
}
