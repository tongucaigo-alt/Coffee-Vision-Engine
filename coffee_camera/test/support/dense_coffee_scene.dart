import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/models/analysis_frame.dart';
import 'package:coffee_camera/src/models/preview_transform.dart';

/// A visible porcelain rim surrounding almost entirely coated, textured walls.
/// Chroma is configurable so a dark grey/blue surface cannot stand in for coffee.
AnalysisFrame denseCoffeeScene({
  int luminance = 60,
  bool textured = true,
  bool smoothShadow = false,
  bool lightRim = true,
  int chromaU = 118,
  int chromaV = 146,
}) {
  const width = 360, height = 800;
  final y = Uint8List(width * height);
  for (var row = 0; row < height; row++) {
    for (var column = 0; column < width; column++) {
      final distance = math.sqrt(
        math.pow(column - 180, 2) + math.pow(row - 336, 2),
      );
      var value = ((column ~/ 3 + row ~/ 3).isEven ? 100 : 150);
      if (distance <= 106) value = lightRim ? 222 : 110;
      if (distance <= 88) {
        value = luminance;
        if (smoothShadow) value += ((column - 180) / 4).round();
        if (textured) value += ((column ~/ 5 + row ~/ 5 * 2) % 5 - 2) * 8;
        // Less than 2% white interior: not enough for the old p78 reference.
        if (math.pow(column - 147, 2) + math.pow(row - 305, 2) < 64) {
          value = lightRim ? 222 : 110;
        }
      }
      y[row * width + column] = value.clamp(0, 255);
    }
  }
  final u = Uint8List(width * height ~/ 4)
    ..fillRange(0, width * height ~/ 4, chromaU);
  final v = Uint8List(width * height ~/ 4)
    ..fillRange(0, width * height ~/ 4, chromaV);
  return AnalysisFrame(
    width: width,
    height: height,
    rotationDegrees: 0,
    format: AnalysisFrameFormat.yuv420,
    bytes: y,
    bytesPerRow: width,
    bytesPerPixel: 1,
    planes: [
      AnalysisPlane(bytes: y, bytesPerRow: width, bytesPerPixel: 1),
      AnalysisPlane(bytes: u, bytesPerRow: width ~/ 2, bytesPerPixel: 1),
      AnalysisPlane(bytes: v, bytesPerRow: width ~/ 2, bytesPerPixel: 1),
    ],
    previewTransform: const PreviewTransform(
      sourceSize: Size(360, 800),
      viewportSize: Size(360, 800),
      rotationDegrees: 0,
    ),
  );
}
