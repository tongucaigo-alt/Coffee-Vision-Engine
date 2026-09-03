import 'dart:ui';

import 'package:coffee_camera/src/models/preview_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a rotated camera center into a BoxFit.cover preview', () {
    const transform = PreviewTransform(
      sourceSize: Size(1280, 720),
      viewportSize: Size(360, 800),
      rotationDegrees: 90,
    );

    final viewport = transform.rawNormalizedToViewport(const Offset(0.5, 0.5));
    expect(viewport.dx, closeTo(180, 0.001));
    expect(viewport.dy, closeTo(400, 0.001));
    final raw = transform.viewportToRawNormalized(viewport);
    expect(raw.dx, closeTo(0.5, 0.001));
    expect(raw.dy, closeTo(0.5, 0.001));
  });

  test('round trips all rotations and front-camera mirroring', () {
    for (final rotation in const [0, 90, 180, 270]) {
      for (final mirrored in const [false, true]) {
        final transform = PreviewTransform(
          sourceSize: const Size(640, 480),
          viewportSize: const Size(360, 800),
          rotationDegrees: rotation,
          mirrored: mirrored,
        );
        const source = Offset(0.23, 0.71);
        final result = transform.viewportToRawNormalized(
          transform.rawNormalizedToViewport(source),
        );
        expect(result.dx, closeTo(source.dx, 0.0001));
        expect(result.dy, closeTo(source.dy, 0.0001));
      }
    }
  });

  test('maps viewport crop back to an oriented source image', () {
    const transform = PreviewTransform(
      sourceSize: Size(900, 1600),
      viewportSize: Size(360, 800),
      rotationDegrees: 0,
    );
    final source = transform.viewportRectToSource(
      const Rect.fromLTWH(90, 200, 180, 300),
    );

    expect(source.left, closeTo(270, 0.001));
    expect(source.top, closeTo(400, 0.001));
    expect(source.width, closeTo(360, 0.001));
    expect(source.height, closeTo(600, 0.001));
  });
}
