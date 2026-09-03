import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/analysis/saucer_detector.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/analysis_frame.dart';
import 'package:coffee_camera/src/models/preview_transform.dart';
import 'package:coffee_camera/src/models/saucer_analysis_result.dart';
import 'package:coffee_camera/src/models/saucer_detection_result.dart';
import 'package:coffee_camera/src/quality/saucer_quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const detector = LightSaucerDetector(config);
  const checker = SaucerQualityChecker();
  const viewport = Size(360, 800);

  test(
    'detects the same outer boundary on empty and ground-filled white saucers',
    () async {
      final empty = await detector.detect(
        _syntheticFrame(style: _SaucerStyle.white),
      );
      final withGrounds = await detector.detect(
        _syntheticFrame(style: _SaucerStyle.white, grounds: true),
      );

      expect(empty, isNotNull);
      expect(withGrounds, isNotNull);
      expect(
        (empty!.normalizedBounds.width - withGrounds!.normalizedBounds.width)
            .abs(),
        lessThan(0.04),
      );
      expect(
        (empty.normalizedBounds.center - withGrounds.normalizedBounds.center)
            .distance,
        lessThan(0.03),
      );
    },
  );

  test(
    'detects a ground-filled blue patterned saucer from its outer edge',
    () async {
      final saucer = await detector.detect(
        _syntheticFrame(
          style: _SaucerStyle.bluePatterned,
          grounds: true,
          format: AnalysisFrameFormat.bgra8888,
        ),
      );

      expect(saucer, isNotNull);
      expect(
        saucer!.confidence,
        greaterThanOrEqualTo(config.saucerConfig.minimumSaucerConfidence),
      );
      expect(saucer.normalizedBounds.width, greaterThan(0.70));
    },
  );

  test('an oversized saucer cannot receive 100 or become ready', () async {
    final detected = await detector.detect(
      _syntheticFrame(
        style: _SaucerStyle.bluePatterned,
        grounds: true,
        radiusX: 170,
        format: AnalysisFrameFormat.bgra8888,
      ),
    );
    expect(detected, isNotNull);

    final assessment = checker.assess(
      result: _qualityResult(detected!),
      viewportSize: viewport,
      config: config,
    );
    expect(assessment.cupDiameterRatio, greaterThan(1));
    expect(assessment.score, lessThan(100));
    expect(assessment.autoCaptureReady, isFalse);
  });

  test(
    'rejects uniform and striped backgrounds without an outer contour',
    () async {
      expect(await detector.detect(_syntheticFrame()), isNull);
      expect(
        await detector.detect(_syntheticFrame(backgroundStriped: true)),
        isNull,
      );
    },
  );

  test(
    'accepts mild perspective but strong oval distortion is not ready',
    () async {
      final mild = await detector.detect(
        _syntheticFrame(
          style: _SaucerStyle.white,
          grounds: true,
          verticalRatio: 0.95,
        ),
      );
      expect(mild, isNotNull);

      final strongOval = _qualityResult(
        const SaucerDetectionResult(
          confidence: 0.9,
          normalizedBounds: Rect.fromLTWH(0.12, 0.32, 0.76, 0.18),
        ),
      );
      expect(
        checker
            .assess(result: strongOval, viewportSize: viewport, config: config)
            .autoCaptureReady,
        isFalse,
      );
    },
  );

  test('a centered round outer boundary can become ready', () {
    final result = _qualityResult(
      const SaucerDetectionResult(
        confidence: 0.9,
        normalizedBounds: Rect.fromLTWH(0.104, 0.2418, 0.792, 0.3564),
      ),
    );
    final assessment = checker.assess(
      result: result,
      viewportSize: viewport,
      config: config,
    );

    expect(assessment.score, 100);
    expect(assessment.autoCaptureReady, isTrue);
  });
}

SaucerAnalysisResult _qualityResult(SaucerDetectionResult saucer) {
  return SaucerAnalysisResult(
    analysisAvailable: true,
    saucer: saucer,
    brightness: 0.8,
    sharpness: 0.8,
    angleDegrees: 0,
    isStable: true,
    timestamp: DateTime(2026),
  );
}

enum _SaucerStyle { none, white, bluePatterned }

AnalysisFrame _syntheticFrame({
  _SaucerStyle style = _SaucerStyle.none,
  bool grounds = false,
  bool backgroundStriped = false,
  double radiusX = 140,
  double verticalRatio = 1,
  Offset center = const Offset(180, 336),
  AnalysisFrameFormat format = AnalysisFrameFormat.yuv420,
}) {
  const width = 360;
  const height = 800;
  final radiusY = radiusX * verticalRatio;
  final pixels = List<_Rgb>.filled(width * height, const _Rgb(58, 66, 74));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var color = backgroundStriped && (x ~/ 18).isEven
          ? const _Rgb(145, 150, 155)
          : const _Rgb(58, 66, 74);
      final dx = (x - center.dx) / radiusX;
      final dy = (y - center.dy) / radiusY;
      final distanceSquared = dx * dx + dy * dy;
      if (style != _SaucerStyle.none && distanceSquared <= 1) {
        color = switch (style) {
          _SaucerStyle.white => const _Rgb(220, 220, 220),
          _SaucerStyle.bluePatterned =>
            (x ~/ 15 + y ~/ 15).isEven
                ? const _Rgb(48, 104, 166)
                : const _Rgb(68, 126, 188),
          _SaucerStyle.none => color,
        };
        final groundsDx = (x - center.dx) / 76;
        final groundsDy = (y - center.dy - 8) / (68 * verticalRatio);
        if (grounds && groundsDx * groundsDx + groundsDy * groundsDy <= 1) {
          color = const _Rgb(34, 38, 43);
        }
      }
      pixels[y * width + x] = color;
    }
  }
  return _frameFromPixels(width, height, pixels, format);
}

AnalysisFrame _frameFromPixels(
  int width,
  int height,
  List<_Rgb> pixels,
  AnalysisFrameFormat format,
) {
  final viewport = Size(width.toDouble(), height.toDouble());
  final transform = PreviewTransform(
    sourceSize: viewport,
    viewportSize: viewport,
    rotationDegrees: 0,
  );
  if (format == AnalysisFrameFormat.bgra8888) {
    final bytes = Uint8List(width * height * 4);
    for (var index = 0; index < pixels.length; index++) {
      final pixel = pixels[index];
      final offset = index * 4;
      bytes[offset] = pixel.blue;
      bytes[offset + 1] = pixel.green;
      bytes[offset + 2] = pixel.red;
      bytes[offset + 3] = 255;
    }
    return AnalysisFrame(
      width: width,
      height: height,
      rotationDegrees: 0,
      format: format,
      bytes: bytes,
      bytesPerRow: width * 4,
      bytesPerPixel: 4,
      planes: [
        AnalysisPlane(bytes: bytes, bytesPerRow: width * 4, bytesPerPixel: 4),
      ],
      previewTransform: transform,
    );
  }

  final luminance = Uint8List(width * height);
  final chromaWidth = math.max(1, width ~/ 2);
  final chromaHeight = math.max(1, height ~/ 2);
  final u = Uint8List(chromaWidth * chromaHeight);
  final v = Uint8List(chromaWidth * chromaHeight);
  for (var index = 0; index < pixels.length; index++) {
    luminance[index] = pixels[index].luminance;
  }
  for (var y = 0; y < chromaHeight; y++) {
    for (var x = 0; x < chromaWidth; x++) {
      final pixel = pixels[(y * 2) * width + x * 2];
      final index = y * chromaWidth + x;
      u[index] = pixel.chromaU;
      v[index] = pixel.chromaV;
    }
  }
  return AnalysisFrame(
    width: width,
    height: height,
    rotationDegrees: 0,
    format: AnalysisFrameFormat.yuv420,
    bytes: luminance,
    bytesPerRow: width,
    bytesPerPixel: 1,
    planes: [
      AnalysisPlane(bytes: luminance, bytesPerRow: width, bytesPerPixel: 1),
      AnalysisPlane(bytes: u, bytesPerRow: chromaWidth, bytesPerPixel: 1),
      AnalysisPlane(bytes: v, bytesPerRow: chromaWidth, bytesPerPixel: 1),
    ],
    previewTransform: transform,
  );
}

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;

  int get luminance =>
      (0.299 * red + 0.587 * green + 0.114 * blue).round().clamp(0, 255);

  int get chromaU =>
      (-0.169 * red - 0.331 * green + 0.5 * blue + 128).round().clamp(0, 255);

  int get chromaV =>
      (0.5 * red - 0.419 * green - 0.081 * blue + 128).round().clamp(0, 255);
}
