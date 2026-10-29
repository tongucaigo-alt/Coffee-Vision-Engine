// Reuse the package's production renderer without changing its public camera API.
// ignore_for_file: implementation_imports

import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/camera_target_overlay.dart';
import 'package:flutter/material.dart';
import 'capture_settings.dart';
import 'guide_scan_sample.dart';
import 'models.dart';

final _config = cameraConfigForRole(CaptureRole.free);

/// Replays the production camera overlay on the fixed teaching photograph.
/// No camera screen, capture controller, permissions or AI service is created.
class GuideCameraScan extends StatelessWidget {
  const GuideCameraScan({
    super.key,
    required this.progress,
    required this.playing,
    required this.reducedMotion,
  });

  final double progress;
  final bool playing;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    // Live cup sweeps use four cycles per 5400ms (1350ms per pass).
    // Allow 600ms for framing, then replay four passes in the 6s guide.
    final elapsedMs = progress * 6000;
    final detected = reducedMotion || elapsedMs >= 600;
    final scanProgress = reducedMotion || progress >= 1
        ? .5
        : ((elapsedMs - 600) / 1350 % 1).clamp(.0001, 1.0);
    return IgnorePointer(
      child: TickerMode(
        enabled: playing && !reducedMotion,
        child: LayoutBuilder(
          builder: (context, box) => CameraTargetOverlay(
            config: _config,
            ringColor: _config.theme.idleRing,
            subjectDetected: true,
            coffeeDetected: detected,
            coffeeMask: detected ? guideScanSampleMask : null,
            scanProgress: detected ? scanProgress : 0,
            // Match the known cup position in the square teaching artwork.
            targetGeometry: TargetGeometry(
              viewportSize: box.biggest,
              center: Offset(box.maxWidth * .505, box.maxHeight * .445),
              radius: box.maxWidth * .345,
            ),
          ),
        ),
      ),
    );
  }
}
