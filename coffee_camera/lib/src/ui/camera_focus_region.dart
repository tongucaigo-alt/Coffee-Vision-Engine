import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/coffee_camera_config.dart';
import '../models/target_geometry.dart';

/// Shared geometry keeps the blur, shade, and handle outline in agreement.
/// It has no effect on the detection target or the captured image.
class CameraFocusRegion {
  const CameraFocusRegion({required this.target, required this.handleGuide});

  final TargetGeometry target;
  final CameraHandleGuide handleGuide;

  Path get handleOutline {
    if (handleGuide == CameraHandleGuide.none) return Path();
    final right = handleGuide == CameraHandleGuide.right;
    final direction = right ? 1.0 : -1.0;
    final radius = target.radius;
    final halfHeight = radius * 0.28;
    final attachment = math.sqrt(radius * radius - halfHeight * halfHeight);
    final edgeSpace = right
        ? target.viewportSize.width - target.bounds.right
        : target.bounds.left;
    // Leave room for the stroke even on narrower viewports.
    final extension = math.min(radius * 0.30, math.max(0.0, edgeSpace - 8));
    if (extension <= 0) return Path();
    final startX = target.center.dx + direction * attachment;
    final outsideX = target.center.dx + direction * (radius + extension);
    final centerY = target.center.dy;
    return Path()
      ..moveTo(startX, centerY - halfHeight)
      ..cubicTo(
        outsideX,
        centerY - halfHeight,
        outsideX,
        centerY - halfHeight * 0.75,
        outsideX,
        centerY,
      )
      ..cubicTo(
        outsideX,
        centerY + halfHeight * 0.75,
        outsideX,
        centerY + halfHeight,
        startX,
        centerY + halfHeight,
      );
  }

  Path get clearArea {
    final circle = Path()..addOval(target.bounds);
    if (handleGuide == CameraHandleGuide.none) return circle;
    return Path.combine(PathOperation.union, circle, handleOutline..close());
  }

  Path shadePath(Size viewportSize) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & viewportSize)
    ..addPath(clearArea, Offset.zero);
}

class CameraOuterFocusClipper extends CustomClipper<Path> {
  const CameraOuterFocusClipper({required this.region});

  final CameraFocusRegion region;

  @override
  Path getClip(Size size) => region.shadePath(size);

  @override
  bool shouldReclip(CameraOuterFocusClipper oldClipper) =>
      region.target.center != oldClipper.region.target.center ||
      region.target.radius != oldClipper.region.target.radius ||
      region.target.viewportSize != oldClipper.region.target.viewportSize ||
      region.handleGuide != oldClipper.region.handleGuide;
}

/// Place immediately above the camera preview and below painted effects/UI.
class CameraBackgroundFocus extends StatelessWidget {
  const CameraBackgroundFocus({
    super.key,
    required this.region,
    required this.sigma,
  });

  final CameraFocusRegion region;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    if (sigma <= 0 || !sigma.isFinite) return const SizedBox.shrink();
    return IgnorePointer(
      child: ClipPath(
        clipper: CameraOuterFocusClipper(region: region),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
