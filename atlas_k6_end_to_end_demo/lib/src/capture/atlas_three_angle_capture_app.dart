import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';

import '../ui/atlas_three_angle_capture_page.dart';
import 'atlas_capture_file_cleaner.dart';
import 'atlas_three_angle_capture_controller.dart';
import 'atlas_three_angle_capture_models.dart';

final class AtlasThreeAngleCaptureApp extends StatelessWidget {
  const AtlasThreeAngleCaptureApp({
    super.key,
    this.cameraLauncher,
    this.releaseCaptures,
  });

  final AtlasThreeAngleCameraLauncher? cameraLauncher;
  final AtlasCaptureRelease? releaseCaptures;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF175C4C),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF175C4C),
          secondary: const Color(0xFFB7791F),
          tertiary: const Color(0xFF9B4F3F),
          surface: const Color(0xFFF8F7F3),
          error: const Color(0xFFB3261E),
        );
    return MaterialApp(
      title: 'Atlas Üç Açı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFD9DFDB)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: AtlasThreeAngleCaptureHomePage(
        cameraLauncher: cameraLauncher ?? _launchCamera,
        releaseCaptures:
            releaseCaptures ?? const AtlasCaptureFileCleaner().release,
      ),
    );
  }

  static Future<CameraCaptureResult?> _launchCamera(
    BuildContext context,
    AtlasCupCaptureRole role,
  ) {
    return showCoffeeCamera(
      context,
      captureTitle: role.captureTitle,
      captureInstruction: role.captureInstruction,
    );
  }
}
