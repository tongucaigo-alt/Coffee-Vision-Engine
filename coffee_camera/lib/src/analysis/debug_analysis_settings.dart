import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/cup_detection_result.dart';
import '../models/coffee_region_mask.dart';
import '../models/frame_analysis_result.dart';
import '../models/target_geometry.dart';

class DebugAnalysisSettings {
  const DebugAnalysisSettings({
    this.enabled = false,
    this.cupDetected = false,
    this.centered = false,
    this.rightSize = false,
    this.lightEnough = true,
    this.sharp = true,
    this.stable = true,
    this.angleOk = true,
  });

  final bool enabled;
  final bool cupDetected;
  final bool centered;
  final bool rightSize;
  final bool lightEnough;
  final bool sharp;
  final bool stable;
  final bool angleOk;

  DebugAnalysisSettings copyWith({
    bool? enabled,
    bool? cupDetected,
    bool? centered,
    bool? rightSize,
    bool? lightEnough,
    bool? sharp,
    bool? stable,
    bool? angleOk,
  }) {
    return DebugAnalysisSettings(
      enabled: enabled ?? this.enabled,
      cupDetected: cupDetected ?? this.cupDetected,
      centered: centered ?? this.centered,
      rightSize: rightSize ?? this.rightSize,
      lightEnough: lightEnough ?? this.lightEnough,
      sharp: sharp ?? this.sharp,
      stable: stable ?? this.stable,
      angleOk: angleOk ?? this.angleOk,
    );
  }

  FrameAnalysisResult apply({
    required FrameAnalysisResult source,
    required Size viewportSize,
    required CoffeeCameraConfig config,
  }) {
    if (!enabled || viewportSize.isEmpty) return source;
    CupDetectionResult? cup;
    if (cupDetected) {
      final target = TargetGeometry.fromViewport(viewportSize, config);
      final diameter = target.radius * 2 * (rightSize ? 0.80 : 0.50);
      final center = centered
          ? target.center
          : target.center.translate(-target.radius * 0.55, 0);
      final pixelBounds = Rect.fromCircle(center: center, radius: diameter / 2);
      cup = CupDetectionResult(
        confidence: 0.95,
        normalizedBounds: Rect.fromLTRB(
          pixelBounds.left / viewportSize.width,
          pixelBounds.top / viewportSize.height,
          pixelBounds.right / viewportSize.width,
          pixelBounds.bottom / viewportSize.height,
        ),
      );
    }
    final thresholds = config.thresholds;
    final coffeeMask = cupDetected && cup != null
        ? _debugCoffeeMask(cup.normalizedBounds)
        : null;
    return FrameAnalysisResult(
      cupAnalysisAvailable: true,
      cup: cup,
      brightness: lightEnough
          ? math.max(source.brightness, thresholds.minimumBrightness + 0.2)
          : math.max(0, thresholds.minimumBrightness - 0.15),
      sharpness: sharp
          ? math.max(source.sharpness, thresholds.minimumSharpness + 0.2)
          : math.max(0, thresholds.minimumSharpness - 0.15),
      darkPixelRatio: cupDetected ? math.max(source.darkPixelRatio, 0.22) : 0,
      coffeePresenceScore: cupDetected
          ? math.max(source.coffeePresenceScore, 0.34)
          : 0,
      coffeeDetected: cupDetected,
      coffeeMask: coffeeMask,
      angleDegrees: angleOk ? 0 : thresholds.maximumAngleDegrees + 8,
      isStable: stable,
      timestamp: DateTime.now(),
    );
  }
}

CoffeeRegionMask _debugCoffeeMask(Rect cupBounds) {
  const gridSize = 32;
  final values = Uint8List(gridSize * gridSize);
  var active = 0;
  for (var row = 0; row < gridSize; row++) {
    for (var column = 0; column < gridSize; column++) {
      final x = ((column + 0.5) / gridSize - 0.5) / 0.36;
      final y = ((row + 0.5) / gridSize - 0.56) / 0.31;
      if (x * x + y * y <= 1) {
        values[row * gridSize + column] = 210;
        active++;
      }
    }
  }
  return CoffeeRegionMask(
    normalizedBounds: Rect.fromCenter(
      center: cupBounds.center,
      width: cupBounds.width * 0.78,
      height: cupBounds.height * 0.78,
    ),
    width: gridSize,
    height: gridSize,
    intensities: values,
    coverage: active / (gridSize * gridSize),
  );
}
