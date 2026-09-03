import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';

import '../models/analysis_frame.dart';
import '../models/preview_transform.dart';

class FrameMetrics {
  const FrameMetrics({
    required this.brightness,
    required this.sharpness,
    required this.darkPixelRatio,
    required this.coffeePresenceScore,
  });

  final double brightness;
  final double sharpness;
  final double darkPixelRatio;
  final double coffeePresenceScore;
}

class FrameMetricsAnalyzer {
  const FrameMetricsAnalyzer();

  AnalysisFrame copyFrame(
    CameraImage image, {
    required int rotationDegrees,
    required Size viewportSize,
    bool mirrored = false,
  }) {
    final sourcePlanes = image.planes;
    final plane = sourcePlanes.first;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final planes = sourcePlanes
        .map(
          (source) => AnalysisPlane(
            bytes: Uint8List.fromList(source.bytes),
            bytesPerRow: source.bytesPerRow,
            bytesPerPixel: source.bytesPerPixel ?? (isBgra ? 4 : 1),
          ),
        )
        .toList(growable: false);
    return AnalysisFrame(
      width: image.width,
      height: image.height,
      rotationDegrees: rotationDegrees,
      format: isBgra
          ? AnalysisFrameFormat.bgra8888
          : sourcePlanes.length >= 3
          ? AnalysisFrameFormat.yuv420
          : AnalysisFrameFormat.luminance,
      bytes: planes.first.bytes,
      bytesPerRow: plane.bytesPerRow,
      bytesPerPixel: plane.bytesPerPixel ?? (isBgra ? 4 : 1),
      planes: planes,
      previewTransform: PreviewTransform(
        sourceSize: Size(image.width.toDouble(), image.height.toDouble()),
        viewportSize: viewportSize,
        rotationDegrees: rotationDegrees,
        mirrored: mirrored,
      ),
    );
  }

  Future<FrameMetrics> analyze(AnalysisFrame frame) {
    return Isolate.run(() => _calculateMetrics(frame));
  }
}

FrameMetrics _calculateMetrics(AnalysisFrame frame) {
  final step = math.max(2, math.min(frame.width, frame.height) ~/ 120);
  var luminanceTotal = 0.0;
  var gradientTotal = 0.0;
  var darkCount = 0;
  var innerCount = 0;
  var darkWeightTotal = 0.0;
  var count = 0;
  final centerX = frame.width / 2;
  final centerY = frame.height / 2;
  final radiusX = frame.width * 0.36;
  final radiusY = frame.height * 0.36;
  for (var y = 0; y < frame.height - step; y += step) {
    for (var x = 0; x < frame.width - step; x += step) {
      final center = _luminanceAt(frame, x, y);
      final right = _luminanceAt(frame, x + step, y);
      final below = _luminanceAt(frame, x, y + step);
      luminanceTotal += center;
      gradientTotal += ((center - right).abs() + (center - below).abs()) / 2;
      final normalizedX = (x - centerX) / radiusX;
      final normalizedY = (y - centerY) / radiusY;
      if (normalizedX * normalizedX + normalizedY * normalizedY <= 1) {
        innerCount++;
        final darkness = ((115 - center) / 115).clamp(0.0, 1.0);
        if (darkness > 0) {
          darkCount++;
          darkWeightTotal += darkness;
        }
      }
      count++;
    }
  }
  if (count == 0) {
    return const FrameMetrics(
      brightness: 0,
      sharpness: 0,
      darkPixelRatio: 0,
      coffeePresenceScore: 0,
    );
  }
  final darkPixelRatio = innerCount == 0
      ? 0.0
      : (darkCount / innerCount).clamp(0.0, 1.0);
  final averageDarkness = darkCount == 0
      ? 0.0
      : (darkWeightTotal / darkCount).clamp(0.0, 1.0);
  return FrameMetrics(
    brightness: (luminanceTotal / count / 255).clamp(0.0, 1.0),
    sharpness: (gradientTotal / count / 24).clamp(0.0, 1.0),
    darkPixelRatio: darkPixelRatio,
    coffeePresenceScore: (darkPixelRatio * 0.65 + averageDarkness * 0.35).clamp(
      0.0,
      1.0,
    ),
  );
}

double _luminanceAt(AnalysisFrame frame, int x, int y) {
  final plane = frame.firstPlane;
  final index = y * plane.bytesPerRow + x * plane.bytesPerPixel;
  if (index < 0 || index >= plane.bytes.length) return 0;
  if (frame.format == AnalysisFrameFormat.luminance) {
    return plane.bytes[index].toDouble();
  }
  if (frame.format == AnalysisFrameFormat.yuv420) {
    return plane.bytes[index].toDouble();
  }
  if (index + 2 >= plane.bytes.length) return 0;
  final blue = plane.bytes[index];
  final green = plane.bytes[index + 1];
  final red = plane.bytes[index + 2];
  return 0.114 * blue + 0.587 * green + 0.299 * red;
}
