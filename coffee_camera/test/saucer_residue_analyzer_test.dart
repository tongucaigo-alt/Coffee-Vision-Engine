import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/analysis/saucer_residue_analyzer.dart';
import 'package:coffee_camera/src/config/residue_detection_profile.dart';
import 'package:coffee_camera/src/models/analysis_frame.dart';
import 'package:coffee_camera/src/models/preview_transform.dart';
import 'package:coffee_camera/src/models/saucer_detection_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = SaucerResidueAnalyzer();
  const profile = ResidueDetectionProfile();
  const boundary = SaucerDetectionResult(
    confidence: 0.9,
    normalizedBounds: Rect.fromLTWH(0.075, 0.17, 0.85, 0.50),
  );

  test('uniform light, dark, and blue surfaces stay empty', () async {
    for (final surface in const <_Rgb>[
      _Rgb(220, 220, 220),
      _Rgb(72, 72, 72),
      _Rgb(48, 104, 166),
    ]) {
      final result = await analyzer.analyze(
        frame: _frame(surface: surface),
        saucer: boundary,
        profile: profile,
      );
      expect(result.residueDetected, isFalse);
      expect(result.coverage, 0);
    }
  });

  test('finds irregular dark residue on light and blue surfaces', () async {
    for (final surface in const <_Rgb>[
      _Rgb(220, 220, 220),
      _Rgb(48, 104, 166),
    ]) {
      final result = await analyzer.analyze(
        frame: _frame(
          surface: surface,
          patches: const [Rect.fromLTWH(72, 108, 54, 38)],
        ),
        saucer: boundary,
        profile: profile,
      );
      expect(result.residueDetected, isTrue);
      expect(result.activeCellCount, greaterThanOrEqualTo(8));
      expect(result.residueBounds, isNotNull);
    }
  });

  test('regular stripes do not activate the whole mask', () async {
    final result = await analyzer.analyze(
      frame: _frame(surface: const _Rgb(210, 210, 210), striped: true),
      saucer: boundary,
      profile: profile,
    );

    expect(result.mask, isNotNull);
    expect(result.coverage, lessThan(0.70));
    expect(
      result.activeCellCount,
      lessThan(profile.gridSize * profile.gridSize),
    );
  });

  test(
    'preserves separate residue components and combines their bounds',
    () async {
      final result = await analyzer.analyze(
        frame: _frame(
          surface: const _Rgb(215, 215, 215),
          patches: const [
            Rect.fromLTWH(48, 104, 30, 26),
            Rect.fromLTWH(126, 137, 30, 24),
          ],
        ),
        saucer: boundary,
        profile: profile,
      );

      expect(result.residueDetected, isTrue);
      expect(result.componentCount, greaterThanOrEqualTo(2));
      expect(result.residueBounds!.left, lessThan(0.40));
      expect(result.residueBounds!.right, greaterThan(0.60));
    },
  );

  test(
    'removes weak noise but can preserve a small strong component',
    () async {
      final weak = await analyzer.analyze(
        frame: _frame(
          surface: const _Rgb(210, 210, 210),
          patches: const [Rect.fromLTWH(98, 124, 4, 4)],
          residue: const _Rgb(194, 194, 194),
        ),
        saucer: boundary,
        profile: profile,
      );
      expect(weak.residueDetected, isFalse);
      expect(weak.activeCellCount, 0);

      const smallProfile = ResidueDetectionProfile(
        minimumCoverage: 0.0005,
        minimumActiveCells: 1,
        minimumScore: 0.20,
        strongComponentMinimumIntensity: 0.50,
      );
      final strong = await analyzer.analyze(
        frame: _frame(
          surface: const _Rgb(220, 220, 220),
          patches: const [Rect.fromLTWH(96, 122, 9, 7)],
        ),
        saucer: boundary,
        profile: smallProfile,
      );
      expect(strong.residueDetected, isTrue);
      expect(strong.activeCellCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'boundary excludes table residue and raises confidence when usable',
    () async {
      final outsidePatch = _frame(
        surface: const _Rgb(220, 220, 220),
        background: const _Rgb(135, 135, 135),
        patches: const [Rect.fromLTWH(18, 74, 14, 28)],
      );
      final constrained = await analyzer.analyze(
        frame: outsidePatch,
        saucer: boundary,
        profile: profile,
      );
      final fallback = await analyzer.analyze(
        frame: outsidePatch,
        saucer: null,
        profile: profile,
      );
      expect(constrained.boundaryUsed, isTrue);
      expect(constrained.residueDetected, isFalse);
      expect(fallback.boundaryUsed, isFalse);
      expect(fallback.analysisPerformed, isTrue);

      final residueFrame = _frame(
        surface: const _Rgb(220, 220, 220),
        patches: const [Rect.fromLTWH(74, 110, 50, 34)],
      );
      final withBoundary = await analyzer.analyze(
        frame: residueFrame,
        saucer: boundary,
        profile: profile,
      );
      final withoutBoundary = await analyzer.analyze(
        frame: residueFrame,
        saucer: null,
        profile: profile,
      );
      expect(withBoundary.confidence, greaterThan(withoutBoundary.confidence));
      expect(withoutBoundary.residueDetected, isTrue);
    },
  );
}

AnalysisFrame _frame({
  required _Rgb surface,
  _Rgb background = const _Rgb(70, 70, 70),
  _Rgb residue = const _Rgb(35, 30, 25),
  List<Rect> patches = const [],
  bool striped = false,
}) {
  const width = 200;
  const height = 300;
  const center = Offset(100, 126);
  const radiusX = 85.0;
  const radiusY = 75.0;
  final pixels = List<_Rgb>.filled(width * height, background);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final dx = (x - center.dx) / radiusX;
      final dy = (y - center.dy) / radiusY;
      var color = dx * dx + dy * dy <= 1 ? surface : background;
      if (striped && dx * dx + dy * dy <= 1) {
        color = (x ~/ 10).isEven ? surface : const _Rgb(105, 105, 105);
      }
      if (patches.any(
        (patch) => patch.contains(Offset(x.toDouble(), y.toDouble())),
      )) {
        color = residue;
      }
      pixels[y * width + x] = color;
    }
  }
  return _yuvFrame(width, height, pixels);
}

AnalysisFrame _yuvFrame(int width, int height, List<_Rgb> pixels) {
  final luminance = Uint8List(width * height);
  final chromaWidth = width ~/ 2;
  final chromaHeight = height ~/ 2;
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
  final viewport = Size(width.toDouble(), height.toDouble());
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
    previewTransform: PreviewTransform(
      sourceSize: viewport,
      viewportSize: viewport,
      rotationDegrees: 0,
    ),
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
