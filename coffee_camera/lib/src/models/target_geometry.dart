import 'dart:math' as math;
import 'dart:ui';

import '../config/coffee_camera_config.dart';

class TargetGeometry {
  const TargetGeometry({
    required this.viewportSize,
    required this.center,
    required this.radius,
  });

  factory TargetGeometry.fromViewport(
    Size viewportSize,
    CoffeeCameraConfig config,
  ) {
    return TargetGeometry.scaled(
      viewportSize: viewportSize,
      diameterWidthRatio: config.targetDiameterWidthRatio,
      maximumHeightRatio: 0.46,
      normalizedCenter: config.targetCenter,
    );
  }

  factory TargetGeometry.forSaucer(
    Size viewportSize,
    SaucerCaptureConfig config,
  ) {
    return TargetGeometry.scaled(
      viewportSize: viewportSize,
      diameterWidthRatio: config.targetDiameterWidthRatio,
      maximumHeightRatio: config.targetMaximumHeightRatio,
      normalizedCenter: config.targetCenter,
    );
  }

  factory TargetGeometry.scaled({
    required Size viewportSize,
    required double diameterWidthRatio,
    required double maximumHeightRatio,
    required Offset normalizedCenter,
  }) {
    final diameter = math.min(
      viewportSize.width * diameterWidthRatio,
      viewportSize.height * maximumHeightRatio,
    );
    return TargetGeometry(
      viewportSize: viewportSize,
      center: Offset(
        viewportSize.width * normalizedCenter.dx,
        viewportSize.height * normalizedCenter.dy,
      ),
      radius: diameter / 2,
    );
  }

  final Size viewportSize;
  final Offset center;
  final double radius;

  Rect get bounds => Rect.fromCircle(center: center, radius: radius);

  Rect normalizedRectToPixels(Rect value) => Rect.fromLTRB(
    value.left * viewportSize.width,
    value.top * viewportSize.height,
    value.right * viewportSize.width,
    value.bottom * viewportSize.height,
  );
}
