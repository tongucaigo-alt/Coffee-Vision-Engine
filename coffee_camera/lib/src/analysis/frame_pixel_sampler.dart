import 'dart:ui';

import '../models/analysis_frame.dart';

class FramePixel {
  const FramePixel({
    required this.luminance,
    required this.chromaU,
    required this.chromaV,
  });

  final double luminance;
  final double chromaU;
  final double chromaV;

  double get warmth => ((chromaV - 128) - (chromaU - 128) * 0.35) / 128;
}

class FramePixelSampler {
  const FramePixelSampler(this.frame);

  final AnalysisFrame frame;

  FramePixel? sampleViewport(Offset point) {
    final transform = frame.previewTransform;
    if (transform == null) return null;
    final raw = transform.viewportToRawNormalized(point);
    return sampleRawNormalized(raw);
  }

  FramePixel? sampleRawNormalized(Offset point) {
    if (point.dx < 0 || point.dx > 1 || point.dy < 0 || point.dy > 1) {
      return null;
    }
    final x = (point.dx * (frame.width - 1)).round();
    final y = (point.dy * (frame.height - 1)).round();
    return sampleRaw(x, y);
  }

  FramePixel? sampleRaw(int x, int y) {
    if (x < 0 || x >= frame.width || y < 0 || y >= frame.height) {
      return null;
    }
    if (frame.format == AnalysisFrameFormat.bgra8888) {
      final plane = frame.firstPlane;
      final index = y * plane.bytesPerRow + x * plane.bytesPerPixel;
      if (index < 0 || index + 2 >= plane.bytes.length) return null;
      final blue = plane.bytes[index].toDouble();
      final green = plane.bytes[index + 1].toDouble();
      final red = plane.bytes[index + 2].toDouble();
      return FramePixel(
        luminance: 0.114 * blue + 0.587 * green + 0.299 * red,
        chromaU: (-0.169 * red - 0.331 * green + 0.5 * blue + 128).clamp(
          0.0,
          255.0,
        ),
        chromaV: (0.5 * red - 0.419 * green - 0.081 * blue + 128).clamp(
          0.0,
          255.0,
        ),
      );
    }

    final yPlane = frame.firstPlane;
    final yIndex = y * yPlane.bytesPerRow + x * yPlane.bytesPerPixel;
    if (yIndex < 0 || yIndex >= yPlane.bytes.length) return null;
    var chromaU = 128.0;
    var chromaV = 128.0;
    if (frame.format == AnalysisFrameFormat.yuv420 &&
        frame.planes.length >= 3) {
      chromaU = _readChroma(frame.planes[1], x ~/ 2, y ~/ 2);
      chromaV = _readChroma(frame.planes[2], x ~/ 2, y ~/ 2);
    }
    return FramePixel(
      luminance: yPlane.bytes[yIndex].toDouble(),
      chromaU: chromaU,
      chromaV: chromaV,
    );
  }

  double _readChroma(AnalysisPlane plane, int x, int y) {
    final index = y * plane.bytesPerRow + x * plane.bytesPerPixel;
    if (index < 0 || index >= plane.bytes.length) return 128;
    return plane.bytes[index].toDouble();
  }
}
