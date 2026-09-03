import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/residue_analysis_result.dart';
import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:coffee_camera/src/models/saucer_analysis_result.dart';
import 'package:coffee_camera/src/models/saucer_detection_result.dart';
import 'package:coffee_camera/src/quality/saucer_failure_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = SaucerFailureClassifier();
  const config = CoffeeCameraConfig();
  const viewport = Size(360, 800);

  test('treats invalid analysis and extreme light as hard failures', () {
    expect(
      classifier.isHardFailure(
        result: _result(analysisPerformed: false),
        viewportSize: viewport,
        config: config,
      ),
      isTrue,
    );
    expect(
      classifier.isHardFailure(
        result: _result(brightness: 0.05),
        viewportSize: viewport,
        config: config,
      ),
      isTrue,
    );
    expect(
      classifier.isHardFailure(
        result: _result(brightness: 0.99),
        viewportSize: viewport,
        config: config,
      ),
      isTrue,
    );
  });

  test('closes on severe geometry but not on one missing boundary', () {
    expect(
      classifier.isHardFailure(
        result: _result(
          saucerBounds: const Rect.fromLTWH(0.70, 0.12, 0.22, 0.10),
        ),
        viewportSize: viewport,
        config: config,
      ),
      isTrue,
    );
    expect(
      classifier.isHardFailure(
        result: _result(includeSaucer: false),
        viewportSize: viewport,
        config: config,
      ),
      isFalse,
    );
  });
}

SaucerAnalysisResult _result({
  bool analysisPerformed = true,
  double brightness = 0.8,
  bool includeSaucer = true,
  Rect saucerBounds = const Rect.fromLTWH(0.104, 0.2418, 0.792, 0.3564),
}) {
  final values = Uint8List(32 * 32)..fillRange(100, 132, 220);
  final mask = ResidueRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.09, 0.24, 0.82, 0.36),
    width: 32,
    height: 32,
    intensities: values,
    coverage: 0.04,
    residueBounds: const Rect.fromLTWH(0.20, 0.30, 0.28, 0.10),
    componentCount: 1,
  );
  return SaucerAnalysisResult(
    analysisAvailable: true,
    saucer: includeSaucer
        ? SaucerDetectionResult(confidence: 0.9, normalizedBounds: saucerBounds)
        : null,
    brightness: brightness,
    sharpness: 0.8,
    angleDegrees: 0,
    isStable: true,
    timestamp: DateTime(2026),
    residue: ResidueAnalysisResult(
      mask: analysisPerformed ? mask : null,
      score: analysisPerformed ? 0.65 : 0,
      confidence: analysisPerformed ? 0.76 : 0,
      residueDetected: analysisPerformed,
      residueBounds: analysisPerformed ? mask.residueBounds : null,
      boundaryUsed: includeSaucer,
      analysisPerformed: analysisPerformed,
    ),
  );
}
