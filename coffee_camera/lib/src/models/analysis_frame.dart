import 'dart:typed_data';

import 'preview_transform.dart';

enum AnalysisFrameFormat { luminance, yuv420, bgra8888 }

class AnalysisPlane {
  const AnalysisPlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

class AnalysisFrame {
  const AnalysisFrame({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.format,
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
    this.planes = const [],
    this.previewTransform,
  });

  final int width;
  final int height;
  final int rotationDegrees;
  final AnalysisFrameFormat format;
  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
  final List<AnalysisPlane> planes;
  final PreviewTransform? previewTransform;

  AnalysisPlane get firstPlane => planes.isNotEmpty
      ? planes.first
      : AnalysisPlane(
          bytes: bytes,
          bytesPerRow: bytesPerRow,
          bytesPerPixel: bytesPerPixel,
        );
}
