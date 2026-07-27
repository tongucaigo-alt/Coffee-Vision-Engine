import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';

final Uint8List validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGN88e41'
  'AwMDEwMYQCkANKQCx3xNMvIAAAAASUVORK5CYII=',
);

late VisionPipelineResult cupPipelineResult;
late VisionPipelineResult saucerPipelineResult;

Future<void> preparePipelineResults() async {
  final engine = CoffeeVisionEngine();
  cupPipelineResult = await engine.analyzeDetailed(
    VisionImageInput(
      imageBytes: validPngBytes,
      surfaceType: VisionSurfaceType.cup,
    ),
  );
  saucerPipelineResult = await engine.analyzeDetailed(
    VisionImageInput(
      imageBytes: validPngBytes,
      surfaceType: VisionSurfaceType.saucer,
    ),
  );
}

Future<VisionPipelineResult> matchingPipelineResult(
  VisionImageInput input,
) async {
  return input.surfaceType == VisionSurfaceType.cup
      ? cupPipelineResult
      : saucerPipelineResult;
}

final class TestCaptureBundle {
  const TestCaptureBundle({
    required this.directory,
    required this.result,
    required this.cupOriginalPath,
    required this.saucerOriginalPath,
    this.cupCropPath,
    this.saucerCropPath,
  });

  final Directory directory;
  final CoffeeCameraCaptureResult result;
  final String cupOriginalPath;
  final String saucerOriginalPath;
  final String? cupCropPath;
  final String? saucerCropPath;
}

Future<TestCaptureBundle> createCaptureBundle({
  bool includeCupCrop = true,
  bool includeSaucerCrop = true,
  Uint8List? cupBytes,
  Uint8List? saucerBytes,
}) async {
  final directory = await Directory.systemTemp.createTemp('atlas_m6_test_');
  final cupOriginalPath = '${directory.path}${Platform.pathSeparator}cup.png';
  final saucerOriginalPath =
      '${directory.path}${Platform.pathSeparator}saucer.png';
  final cupCropPath = includeCupCrop
      ? '${directory.path}${Platform.pathSeparator}cup_crop.png'
      : null;
  final saucerCropPath = includeSaucerCrop
      ? '${directory.path}${Platform.pathSeparator}saucer_crop.png'
      : null;

  await File(cupOriginalPath).writeAsBytes(cupBytes ?? validPngBytes);
  await File(saucerOriginalPath).writeAsBytes(saucerBytes ?? validPngBytes);
  if (cupCropPath != null) {
    await File(cupCropPath).writeAsBytes(cupBytes ?? validPngBytes);
  }
  if (saucerCropPath != null) {
    await File(saucerCropPath).writeAsBytes(saucerBytes ?? validPngBytes);
  }

  return TestCaptureBundle(
    directory: directory,
    result: CoffeeCameraCaptureResult(
      cup: _captureResult(
        filePath: cupOriginalPath,
        croppedCupPath: cupCropPath,
      ),
      saucer: _captureResult(
        filePath: saucerOriginalPath,
        croppedSaucerPath: saucerCropPath,
      ),
    ),
    cupOriginalPath: cupOriginalPath,
    saucerOriginalPath: saucerOriginalPath,
    cupCropPath: cupCropPath,
    saucerCropPath: saucerCropPath,
  );
}

CameraCaptureResult captureWithoutSaucer(String filePath) {
  return _captureResult(filePath: filePath);
}

CameraCaptureResult _captureResult({
  required String filePath,
  String? croppedCupPath,
  String? croppedSaucerPath,
}) {
  return CameraCaptureResult(
    filePath: filePath,
    croppedCupPath: croppedCupPath,
    croppedSaucerPath: croppedSaucerPath,
    widthPixels: 2,
    heightPixels: 3,
    fileSizeBytes: validPngBytes.length,
    croppedWidthPixels: 2,
    croppedHeightPixels: 3,
    croppedFileSizeBytes: validPngBytes.length,
    capturedAt: DateTime.utc(2026, 7, 22),
    qualityScore: 90,
    coffeePresenceScore: 0.8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}

Future<void> removeTestDirectory(Directory directory) async {
  if (await directory.exists()) await directory.delete(recursive: true);
}
