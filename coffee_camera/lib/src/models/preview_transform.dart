import 'dart:math' as math;
import 'dart:ui';

/// Maps raw camera-frame coordinates to the portrait BoxFit.cover preview.
class PreviewTransform {
  const PreviewTransform({
    required this.sourceSize,
    required this.viewportSize,
    required this.rotationDegrees,
    this.mirrored = false,
  });

  factory PreviewTransform.oriented({
    required Size sourceSize,
    required Size viewportSize,
    bool mirrored = false,
  }) {
    return PreviewTransform(
      sourceSize: sourceSize,
      viewportSize: viewportSize,
      rotationDegrees: 0,
      mirrored: mirrored,
    );
  }

  final Size sourceSize;
  final Size viewportSize;
  final int rotationDegrees;
  final bool mirrored;

  int get normalizedRotation => ((rotationDegrees % 360) + 360) % 360;

  Size get orientedSize => switch (normalizedRotation) {
    90 || 270 => Size(sourceSize.height, sourceSize.width),
    _ => sourceSize,
  };

  double get scale {
    final oriented = orientedSize;
    if (oriented.isEmpty || viewportSize.isEmpty) return 1;
    return math.max(
      viewportSize.width / oriented.width,
      viewportSize.height / oriented.height,
    );
  }

  Offset get overflow {
    final oriented = orientedSize;
    final currentScale = scale;
    return Offset(
      (oriented.width * currentScale - viewportSize.width) / 2,
      (oriented.height * currentScale - viewportSize.height) / 2,
    );
  }

  Offset rawNormalizedToViewport(Offset raw) {
    var oriented = switch (normalizedRotation) {
      90 => Offset(1 - raw.dy, raw.dx),
      180 => Offset(1 - raw.dx, 1 - raw.dy),
      270 => Offset(raw.dy, 1 - raw.dx),
      _ => raw,
    };
    if (mirrored) oriented = Offset(1 - oriented.dx, oriented.dy);
    final size = orientedSize;
    final currentScale = scale;
    final currentOverflow = overflow;
    return Offset(
      oriented.dx * size.width * currentScale - currentOverflow.dx,
      oriented.dy * size.height * currentScale - currentOverflow.dy,
    );
  }

  Offset viewportToRawNormalized(Offset viewport) {
    final size = orientedSize;
    final currentScale = scale;
    final currentOverflow = overflow;
    var oriented = Offset(
      (viewport.dx + currentOverflow.dx) / (size.width * currentScale),
      (viewport.dy + currentOverflow.dy) / (size.height * currentScale),
    );
    if (mirrored) oriented = Offset(1 - oriented.dx, oriented.dy);
    return switch (normalizedRotation) {
      90 => Offset(oriented.dy, 1 - oriented.dx),
      180 => Offset(1 - oriented.dx, 1 - oriented.dy),
      270 => Offset(1 - oriented.dy, oriented.dx),
      _ => oriented,
    };
  }

  Rect viewportRectToSource(Rect viewportRect) {
    final points = <Offset>[
      viewportRect.topLeft,
      viewportRect.topRight,
      viewportRect.bottomLeft,
      viewportRect.bottomRight,
    ].map(viewportToRawNormalized);
    final xs = points.map((point) => point.dx * sourceSize.width);
    final ys = points.map((point) => point.dy * sourceSize.height);
    return Rect.fromLTRB(
      xs.reduce(math.min).clamp(0.0, sourceSize.width),
      ys.reduce(math.min).clamp(0.0, sourceSize.height),
      xs.reduce(math.max).clamp(0.0, sourceSize.width),
      ys.reduce(math.max).clamp(0.0, sourceSize.height),
    );
  }
}
