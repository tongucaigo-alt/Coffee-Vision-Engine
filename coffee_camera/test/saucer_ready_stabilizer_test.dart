import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/residue_analysis_result.dart';
import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:coffee_camera/src/models/saucer_analysis_result.dart';
import 'package:coffee_camera/src/models/saucer_detection_result.dart';
import 'package:coffee_camera/src/quality/saucer_quality_checker.dart';
import 'package:coffee_camera/src/quality/saucer_ready_stabilizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const checker = SaucerQualityChecker();
  const viewport = Size(360, 800);

  test('enters after two good frames and leaves after five soft failures', () {
    final stabilizer = SaucerReadyStabilizer(config);
    final good = _result();
    final moving = _result(stable: false);

    expect(_update(stabilizer, good, checker), isFalse);
    expect(_update(stabilizer, good, checker), isTrue);
    for (var frame = 0; frame < 4; frame++) {
      expect(_update(stabilizer, moving, checker), isTrue);
    }
    expect(_update(stabilizer, moving, checker), isFalse);
  });

  test('a single weak residue frame is a soft failure', () {
    final stabilizer = SaucerReadyStabilizer(config);
    _update(stabilizer, _result(), checker);
    expect(_update(stabilizer, _result(), checker), isTrue);

    expect(_update(stabilizer, _result(residueValid: false), checker), isTrue);
  });

  test('closes immediately when the saucer clearly leaves the target', () {
    final stabilizer = SaucerReadyStabilizer(config);
    final good = _result();
    _update(stabilizer, good, checker);
    expect(_update(stabilizer, good, checker), isTrue);

    final farOutside = _result(
      bounds: const Rect.fromLTWH(0.68, 0.18, 0.25, 0.12),
    );
    expect(_update(stabilizer, farOutside, checker), isFalse);
  });

  test('combined score includes stability and reset clears ready state', () {
    final stable = checker.assess(
      result: _result(),
      viewportSize: viewport,
      config: config,
    );
    final moving = checker.assess(
      result: _result(stable: false),
      viewportSize: viewport,
      config: config,
    );
    expect(stable.score, 100);
    expect(moving.score, 95);

    final stabilizer = SaucerReadyStabilizer(config);
    _update(stabilizer, _result(), checker);
    _update(stabilizer, _result(), checker);
    expect(stabilizer.isReady, isTrue);
    stabilizer.reset();
    expect(stabilizer.isReady, isFalse);
  });

  test('severe darkness is an immediate hard failure', () {
    final stabilizer = SaucerReadyStabilizer(config);
    _update(stabilizer, _result(), checker);
    expect(_update(stabilizer, _result(), checker), isTrue);

    expect(_update(stabilizer, _result(brightness: 0.05), checker), isFalse);
  });
}

bool _update(
  SaucerReadyStabilizer stabilizer,
  SaucerAnalysisResult result,
  SaucerQualityChecker checker,
) {
  return stabilizer.update(
    result: result,
    assessment: checker.assess(
      result: result,
      viewportSize: const Size(360, 800),
      config: const CoffeeCameraConfig(),
    ),
    viewportSize: const Size(360, 800),
  );
}

SaucerAnalysisResult _result({
  Rect bounds = const Rect.fromLTWH(0.104, 0.2418, 0.792, 0.3564),
  bool stable = true,
  bool residueValid = true,
  double brightness = 0.8,
}) {
  final values = Uint8List(32 * 32);
  if (residueValid) values.fillRange(100, 132, 220);
  final mask = ResidueRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.09, 0.24, 0.82, 0.36),
    width: 32,
    height: 32,
    intensities: values,
    coverage: residueValid ? 0.04 : 0,
    residueBounds: residueValid
        ? const Rect.fromLTWH(0.20, 0.30, 0.28, 0.10)
        : null,
    componentCount: residueValid ? 1 : 0,
  );
  return SaucerAnalysisResult(
    analysisAvailable: true,
    saucer: SaucerDetectionResult(confidence: 0.9, normalizedBounds: bounds),
    brightness: brightness,
    sharpness: 0.8,
    angleDegrees: 0,
    isStable: stable,
    timestamp: DateTime(2026),
    residue: ResidueAnalysisResult(
      mask: residueValid ? mask : null,
      score: residueValid ? 0.65 : 0,
      confidence: residueValid ? 0.76 : 0,
      residueDetected: residueValid,
      residueBounds: residueValid ? mask.residueBounds : null,
      boundaryUsed: true,
      analysisPerformed: true,
    ),
  );
}
