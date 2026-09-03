import 'dart:ui';

class CupDetectionResult {
  const CupDetectionResult({
    required this.confidence,
    required this.normalizedBounds,
  });

  final double confidence;
  final Rect normalizedBounds;

  Offset get center => normalizedBounds.center;
  Size get size => normalizedBounds.size;
}
