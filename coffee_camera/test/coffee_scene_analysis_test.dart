import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/analysis/coffee_region_analyzer.dart';
import 'package:coffee_camera/src/analysis/cup_detector.dart';
import 'package:coffee_camera/src/analysis/frame_pixel_sampler.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/analysis_frame.dart';
import 'package:coffee_camera/src/models/preview_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const detector = LightCupDetector(config);
  const regionAnalyzer = CoffeeRegionAnalyzer();

  test('detects a light cup and dark coffee grounds', () async {
    final frame = _syntheticFrame(cup: true, grounds: true);
    final cup = await detector.detect(frame);
    expect(cup, isNotNull);
    expect(cup!.confidence, greaterThanOrEqualTo(config.minimumCupConfidence));

    final coffee = await regionAnalyzer.analyze(
      frame: frame,
      cup: cup,
      config: config,
    );
    expect(coffee.mask, isNotNull);
    expect(coffee.coverage, inInclusiveRange(0.06, 0.70));
    expect(coffee.score, greaterThanOrEqualTo(config.minimumCoffeePresence));
    expect(coffee.mask!.activeCellCount, greaterThanOrEqualTo(24));
  });

  test('does not classify an empty light cup as grounds', () async {
    final frame = _syntheticFrame(cup: true, grounds: false);
    final cup = await detector.detect(frame);
    expect(cup, isNotNull);
    final coffee = await regionAnalyzer.analyze(
      frame: frame,
      cup: cup,
      config: config,
    );

    expect(coffee.score, lessThan(config.minimumCoffeePresence));
    expect(coffee.mask?.activeCellCount ?? 0, lessThan(24));
  });

  test('does not detect a cup on a uniformly dark floor', () async {
    final cup = await detector.detect(_syntheticFrame());
    expect(cup, isNull);
  });

  test('does not detect a cup on a striped floor', () async {
    final cup = await detector.detect(_syntheticFrame(striped: true));
    expect(cup, isNull);
  });

  test('rejects an off-center or partially clipped cup', () async {
    final cup = await detector.detect(
      _syntheticFrame(
        cup: true,
        grounds: true,
        cupCenter: const Offset(75, 336),
      ),
    );
    expect(cup, isNull);
  });

  test('rejects a cup whose light rim is too dark', () async {
    final cup = await detector.detect(
      _syntheticFrame(cup: true, grounds: true, lowLight: true),
    );
    expect(cup, isNull);
  });

  test('samples YUV and BGRA frame colors', () {
    final yuv = _frameFromLuminance(4, 4, Uint8List(16)..fillRange(0, 16, 80));
    final yuvPixel = FramePixelSampler(yuv).sampleRaw(2, 2)!;
    expect(yuvPixel.luminance, 80);
    expect(yuvPixel.chromaU, 118);
    expect(yuvPixel.chromaV, 146);

    final bgraBytes = Uint8List.fromList([20, 40, 80, 255]);
    final bgra = AnalysisFrame(
      width: 1,
      height: 1,
      rotationDegrees: 0,
      format: AnalysisFrameFormat.bgra8888,
      bytes: bgraBytes,
      bytesPerRow: 4,
      bytesPerPixel: 4,
      planes: [
        AnalysisPlane(bytes: bgraBytes, bytesPerRow: 4, bytesPerPixel: 4),
      ],
      previewTransform: const PreviewTransform(
        sourceSize: Size(1, 1),
        viewportSize: Size(1, 1),
        rotationDegrees: 0,
      ),
    );
    final bgraPixel = FramePixelSampler(bgra).sampleRaw(0, 0)!;
    expect(bgraPixel.luminance, closeTo(49.68, 0.01));
  });
}

AnalysisFrame _syntheticFrame({
  bool cup = false,
  bool grounds = false,
  bool striped = false,
  bool lowLight = false,
  Offset cupCenter = const Offset(180, 336),
}) {
  const width = 360;
  const height = 800;
  const cupRadius = 106.0;
  const innerRadius = 88.0;
  final bytes = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var luminance = striped ? ((x ~/ 18).isEven ? 58 : 168) : 72;
      if (cup) {
        final distance =
            (Offset(x.toDouble(), y.toDouble()) - cupCenter).distance;
        if (distance <= cupRadius) luminance = lowLight ? 125 : 222;
        if (distance <= innerRadius) luminance = lowLight ? 86 : 184;
        final groundDistance =
            (Offset(x.toDouble(), y.toDouble()) - cupCenter.translate(0, 12))
                .distance;
        if (grounds && groundDistance <= 50) luminance = 46;
      }
      bytes[y * width + x] = luminance;
    }
  }
  return _frameFromLuminance(width, height, bytes);
}

AnalysisFrame _frameFromLuminance(int width, int height, Uint8List bytes) {
  final chromaLength = math.max(1, (width ~/ 2) * (height ~/ 2));
  final u = Uint8List(chromaLength)..fillRange(0, chromaLength, 118);
  final v = Uint8List(chromaLength)..fillRange(0, chromaLength, 146);
  return AnalysisFrame(
    width: width,
    height: height,
    rotationDegrees: 0,
    format: AnalysisFrameFormat.yuv420,
    bytes: bytes,
    bytesPerRow: width,
    bytesPerPixel: 1,
    planes: [
      AnalysisPlane(bytes: bytes, bytesPerRow: width, bytesPerPixel: 1),
      AnalysisPlane(
        bytes: u,
        bytesPerRow: math.max(1, width ~/ 2),
        bytesPerPixel: 1,
      ),
      AnalysisPlane(
        bytes: v,
        bytesPerRow: math.max(1, width ~/ 2),
        bytesPerPixel: 1,
      ),
    ],
    previewTransform: PreviewTransform(
      sourceSize: Size(width.toDouble(), height.toDouble()),
      viewportSize: Size(width.toDouble(), height.toDouble()),
      rotationDegrees: 0,
    ),
  );
}
