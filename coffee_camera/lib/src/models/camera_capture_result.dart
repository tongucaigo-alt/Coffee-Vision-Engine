import 'dart:ui';

enum CameraCaptureMode { manual, automatic }

class CameraCaptureResult {
  const CameraCaptureResult({
    required this.filePath,
    this.croppedCupPath,
    this.croppedSaucerPath,
    this.cropRect,
    required this.widthPixels,
    required this.heightPixels,
    required this.fileSizeBytes,
    this.croppedWidthPixels,
    this.croppedHeightPixels,
    this.croppedFileSizeBytes,
    required this.capturedAt,
    required this.qualityScore,
    required this.coffeePresenceScore,
    this.coffeeDetected = false,
    required this.mode,
  });

  final String filePath;
  final String? croppedCupPath;
  final String? croppedSaucerPath;
  final Rect? cropRect;
  final int widthPixels;
  final int heightPixels;
  final int fileSizeBytes;
  final int? croppedWidthPixels;
  final int? croppedHeightPixels;
  final int? croppedFileSizeBytes;
  final DateTime capturedAt;
  final int qualityScore;
  final double coffeePresenceScore;
  final bool coffeeDetected;
  final CameraCaptureMode mode;

  String? get croppedImagePath => croppedCupPath ?? croppedSaucerPath;
}
