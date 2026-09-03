import 'dart:ui';

class SaucerDetectionResult {
  const SaucerDetectionResult({
    required this.confidence,
    required this.normalizedBounds,
  });

  final double confidence;
  final Rect normalizedBounds;

  Offset get center => normalizedBounds.center;
  Size get size => normalizedBounds.size;
}
