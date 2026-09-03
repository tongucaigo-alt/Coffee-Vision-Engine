import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:coffee_camera/src/analysis/debug_analysis_settings.dart';
import 'package:coffee_camera/src/analysis/device_motion_service.dart';
import 'package:coffee_camera/src/analysis/cup_detector.dart';
import 'package:coffee_camera/src/analysis/saucer_detector.dart';
import 'package:coffee_camera/src/analysis/saucer_residue_analyzer.dart';
import 'package:coffee_camera/src/camera/camera_service.dart';
import 'package:coffee_camera/src/capture/coffee_camera_controller.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/config/residue_detection_profile.dart';
import 'package:coffee_camera/src/models/camera_capture_result.dart';
import 'package:coffee_camera/src/models/coffee_camera_capture_result.dart';
import 'package:coffee_camera/src/models/analysis_frame.dart';
import 'package:coffee_camera/src/models/residue_analysis_result.dart';
import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:coffee_camera/src/models/saucer_detection_result.dart';
import 'package:coffee_camera/src/quality/saucer_quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual capture and retake use the camera service contract', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'coffee-camera-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(_onePixelPng);
    final service = _FakeCameraService(capturePath: file.path);
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(),
      cameraService: service,
      motionService: _FakeMotionService(),
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    expect(controller.phase, CameraExperiencePhase.live);
    expect(controller.cupAnalysisActive, isTrue);

    await controller.capture(CameraCaptureMode.manual);
    expect(controller.phase, CameraExperiencePhase.reviewing);
    expect(controller.cupAnalysisActive, isFalse);
    expect(controller.previewPath, file.path);
    expect(service.takePictureCalls, 1);

    await controller.retake();
    expect(controller.phase, CameraExperiencePhase.live);
    expect(controller.cupAnalysisActive, isTrue);
    expect(service.startFrameStreamCalls, 2);
    expect(await file.exists(), isFalse);
    await controller.close();
  });

  test('two-step flow reuses the camera and returns both captures', () async {
    final cupFile = await _createCaptureFile('two-step-cup');
    final saucerFile = await _createCaptureFile('two-step-saucer');
    final service = _FakeCameraService(
      capturePaths: [cupFile.path, saucerFile.path],
    );
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(requireSaucerCapture: true),
      cameraService: service,
      motionService: _FakeMotionService(),
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    await controller.capture(CameraCaptureMode.manual);
    final cupCropPath = controller.draftResult!.croppedCupPath;
    expect(cupCropPath, isNotNull);

    final intermediate = await controller.takeApprovedFlowResult();
    expect(intermediate, isNull);
    expect(controller.currentStep, CoffeeCaptureStep.saucer);
    expect(controller.phase, CameraExperiencePhase.live);
    expect(controller.cupAnalysisActive, isFalse);
    expect(controller.saucerAnalysisActive, isTrue);
    expect(service.initializeCalls, 1);
    expect(service.startFrameStreamCalls, 2);
    expect(controller.autoCaptureVisible, isFalse);
    expect(controller.coffeeDetected, isFalse);
    expect(controller.coffeePresenceScore, 0);
    expect(controller.coffeeMask, isNull);
    expect(controller.scanActive, isFalse);

    await controller.pause();
    expect(controller.phase, CameraExperiencePhase.paused);
    await controller.resume();
    expect(controller.phase, CameraExperiencePhase.live);
    expect(controller.cupAnalysisActive, isFalse);
    expect(controller.saucerAnalysisActive, isTrue);
    expect(service.resumeCalls, 1);
    expect(service.startFrameStreamCalls, 3);

    await controller.capture(CameraCaptureMode.automatic);
    expect(service.takePictureCalls, 1);
    await controller.capture(CameraCaptureMode.manual);
    expect(controller.draftResult!.croppedCupPath, isNull);
    final saucerCropPath = controller.draftResult!.croppedSaucerPath;
    expect(saucerCropPath, isNotNull);
    expect(controller.draftResult!.croppedImagePath, saucerCropPath);

    final result = await controller.takeApprovedFlowResult();
    expect(result, isNotNull);
    expect(result!.cup.filePath, cupFile.path);
    expect(result.cup.croppedCupPath, cupCropPath);
    expect(result.saucer!.filePath, saucerFile.path);
    expect(result.saucer!.croppedSaucerPath, saucerCropPath);
    expect(result.saucer!.mode, CameraCaptureMode.manual);
    expect(result.saucer!.qualityScore, 0);
    expect(result.saucer!.coffeeDetected, isFalse);

    await controller.close();
    expect(await cupFile.exists(), isTrue);
    expect(await File(cupCropPath!).exists(), isTrue);
    expect(await saucerFile.exists(), isTrue);
    expect(await File(saucerCropPath!).exists(), isTrue);
    await _deleteIfExists(cupFile.path);
    await _deleteIfExists(cupCropPath);
    await _deleteIfExists(saucerFile.path);
    await _deleteIfExists(saucerCropPath);
  });

  test('back from saucer preserves cup and retake deletes it', () async {
    final cupFile = await _createCaptureFile('back-cup');
    final saucerFile = await _createCaptureFile('back-saucer');
    final service = _FakeCameraService(
      capturePaths: [cupFile.path, saucerFile.path],
    );
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(requireSaucerCapture: true),
      cameraService: service,
      motionService: _FakeMotionService(),
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    await controller.capture(CameraCaptureMode.manual);
    final cupCropPath = controller.draftResult!.croppedCupPath!;
    await controller.takeApprovedFlowResult();
    await controller.capture(CameraCaptureMode.manual);

    expect(await controller.backToPreviousStep(), isTrue);
    expect(controller.currentStep, CoffeeCaptureStep.cup);
    expect(controller.phase, CameraExperiencePhase.reviewing);
    expect(controller.isReviewingConfirmedCup, isTrue);
    expect(controller.previewPath, cupFile.path);
    expect(await cupFile.exists(), isTrue);
    expect(await File(cupCropPath).exists(), isTrue);
    expect(await saucerFile.exists(), isFalse);

    await controller.retake();
    expect(controller.currentStep, CoffeeCaptureStep.cup);
    expect(controller.phase, CameraExperiencePhase.live);
    expect(controller.cupAnalysisActive, isTrue);
    expect(service.startFrameStreamCalls, 3);
    expect(await cupFile.exists(), isFalse);
    expect(await File(cupCropPath).exists(), isFalse);
    await controller.close();
  });

  test('ready cup can auto capture but saucer cannot', () async {
    final cupFile = await _createCaptureFile('automatic-cup');
    final service = _FakeCameraService(capturePath: cupFile.path);
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(
        requireSaucerCapture: true,
        autoCaptureStableDuration: Duration(milliseconds: 1),
      ),
      cameraService: service,
      motionService: _FakeMotionService(),
    );
    const ready = DebugAnalysisSettings(
      enabled: true,
      cupDetected: true,
      centered: true,
      rightSize: true,
      lightEnough: true,
      sharp: true,
      stable: true,
      angleOk: true,
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    controller.setDebugSettings(ready);
    expect(controller.assessment.autoCaptureReady, isTrue);
    expect(controller.coffeeDetected, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.setDebugSettings(ready);
    await _waitForPhase(controller, CameraExperiencePhase.reviewing);

    expect(service.takePictureCalls, 1);
    expect(controller.draftResult!.mode, CameraCaptureMode.automatic);
    await controller.takeApprovedFlowResult();
    expect(controller.currentStep, CoffeeCaptureStep.saucer);
    expect(controller.cupAnalysisActive, isFalse);
    expect(controller.saucerAnalysisActive, isTrue);

    controller.setDebugSettings(ready);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(service.takePictureCalls, 1);
    await controller.close();
  });

  test('saucer residue state stays independent and retake clears it', () async {
    final cupFile = await _createCaptureFile('residue-shadow-cup');
    final saucerFile = await _createCaptureFile('residue-shadow-saucer');
    final service = _FakeCameraService(
      capturePaths: [cupFile.path, saucerFile.path],
    );
    final residueAnalyzer = _FakeResidueAnalyzer();
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(
        requireSaucerCapture: true,
        analysisInterval: Duration.zero,
      ),
      detector: const UnavailableCupDetector(),
      saucerDetector: const _FakeSaucerDetector(),
      saucerResidueAnalyzer: residueAnalyzer,
      cameraService: service,
      motionService: _FakeMotionService(),
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    service.emitFrame(_cameraImage());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(residueAnalyzer.calls, 0);
    expect(controller.saucerResidueAnalysis.analysisPerformed, isFalse);

    await controller.capture(CameraCaptureMode.manual);
    await controller.takeApprovedFlowResult();
    expect(controller.currentStep, CoffeeCaptureStep.saucer);
    service.emitFrame(_cameraImage());
    await _waitForCondition(() => residueAnalyzer.calls >= 1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.saucerResidueAnalysis.residueDetected, isFalse);
    expect(controller.captureReady, isFalse);

    service.emitFrame(_cameraImage());
    await _waitForCondition(() => residueAnalyzer.calls >= 2);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await _waitForCondition(
      () => controller.saucerResidueAnalysis.residueDetected,
    );
    expect(controller.captureReady, isTrue);
    expect(controller.guidance, controller.config.strings.saucerResidueFound);

    final expectedQuality = const SaucerQualityChecker().assess(
      result: controller.saucerAnalysis,
      viewportSize: const Size(360, 800),
      config: controller.config,
    );
    expect(controller.assessment.score, expectedQuality.score);
    expect(controller.coffeeDetected, isFalse);
    expect(controller.coffeeMask, isNull);
    expect(controller.scanActive, isFalse);
    expect(controller.autoCaptureVisible, isFalse);

    await controller.pause();
    await controller.resume();
    expect(controller.saucerResidueAnalysis.analysisPerformed, isFalse);
    expect(controller.saucerResidueAnalysis.residueDetected, isFalse);
    for (var frame = 3; frame <= 4; frame++) {
      service.emitFrame(_cameraImage());
      await _waitForCondition(() => residueAnalyzer.calls >= frame);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await _waitForCondition(
      () => controller.saucerResidueAnalysis.residueDetected,
    );

    await controller.capture(CameraCaptureMode.manual);
    await controller.retake();
    expect(controller.currentStep, CoffeeCaptureStep.saucer);
    expect(controller.saucerResidueAnalysis.analysisPerformed, isFalse);
    expect(controller.saucerResidueAnalysis.residueDetected, isFalse);
    expect(controller.saucerResidueAnalysis.mask, isNull);
    await controller.close();
  });

  test('cancelling a two-step flow deletes every owned file', () async {
    final cupFile = await _createCaptureFile('cancel-cup');
    final saucerFile = await _createCaptureFile('cancel-saucer');
    final service = _FakeCameraService(
      capturePaths: [cupFile.path, saucerFile.path],
    );
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(requireSaucerCapture: true),
      cameraService: service,
      motionService: _FakeMotionService(),
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    await controller.capture(CameraCaptureMode.manual);
    final cupCropPath = controller.draftResult!.croppedCupPath!;
    await controller.takeApprovedFlowResult();
    await controller.capture(CameraCaptureMode.manual);
    final saucerCropPath = controller.draftResult!.croppedSaucerPath!;
    await controller.close();

    expect(await cupFile.exists(), isFalse);
    expect(await File(cupCropPath).exists(), isFalse);
    expect(await saucerFile.exists(), isFalse);
    expect(await File(saucerCropPath).exists(), isFalse);
  });

  test('closing during capture leaves no temporary files', () async {
    final file = await _createCaptureFile('capture-close');
    final gate = Completer<void>();
    final service = _FakeCameraService(
      capturePath: file.path,
      captureGate: gate.future,
    );
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(),
      cameraService: service,
      motionService: _FakeMotionService(),
    );

    await controller.initialize();
    controller.setViewportSize(const Size(360, 800));
    final capture = controller.capture(CameraCaptureMode.manual);
    await Future<void>.delayed(Duration.zero);
    expect(service.takePictureCalls, 1);
    final close = controller.close();
    gate.complete();
    await capture;
    await close;

    expect(await file.exists(), isFalse);
    expect(await File(_cropPathFor(file.path)).exists(), isFalse);
  });

  test('permission failure becomes a user-facing controller state', () async {
    final controller = CoffeeCameraController(
      config: const CoffeeCameraConfig(),
      cameraService: _FakeCameraService(
        capturePath: 'unused',
        initializationFailure: const CameraFailure(
          CameraFailureType.permissionDenied,
          'denied',
        ),
      ),
      motionService: _FakeMotionService(),
    );

    await controller.initialize();

    expect(controller.phase, CameraExperiencePhase.error);
    expect(controller.failureType, CameraFailureType.permissionDenied);
    await controller.close();
  });
}

const _onePixelPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

Future<File> _createCaptureFile(String label) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    '$label-${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(_onePixelPng);
  return file;
}

String _cropPathFor(String originalPath) {
  final file = File(originalPath);
  final name = file.uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  return '${file.parent.path}${Platform.pathSeparator}${stem}_cup_crop.png';
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<void> _waitForPhase(
  CoffeeCameraController controller,
  CameraExperiencePhase phase,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (controller.phase == phase) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Controller did not reach $phase. Current: ${controller.phase}');
}

Future<void> _waitForCondition(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not met before the timeout.');
}

class _FakeMotionService extends DeviceMotionService {
  @override
  MotionSnapshot get snapshot =>
      const MotionSnapshot(isAvailable: true, angleDegrees: 0, isStable: true);

  @override
  void start() {}

  @override
  Future<void> stop() async {}
}

class _FakeCameraService implements CameraService {
  _FakeCameraService({
    String? capturePath,
    List<String>? capturePaths,
    this.initializationFailure,
    this.captureGate,
  }) : assert(capturePath != null || capturePaths != null),
       _capturePaths = capturePaths ?? [capturePath!];

  final List<String> _capturePaths;
  final CameraFailure? initializationFailure;
  final Future<void>? captureGate;
  bool _initialized = false;
  int _captureIndex = 0;
  int initializeCalls = 0;
  int resumeCalls = 0;
  int pauseCalls = 0;
  int startFrameStreamCalls = 0;
  int stopFrameStreamCalls = 0;
  int takePictureCalls = 0;
  void Function(CameraImage image)? _frameCallback;

  void emitFrame(CameraImage image) => _frameCallback?.call(image);

  @override
  CameraController? get controller => null;

  @override
  CameraDescription? get description => null;

  @override
  FlashMode get flashMode => FlashMode.off;

  @override
  bool get hasMultipleCameras => false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (initializationFailure case final failure?) throw failure;
    _initialized = true;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _initialized = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _initialized = false;
  }

  @override
  Future<void> dispose() async => _initialized = false;

  @override
  Future<void> cycleFlashMode() async {}

  @override
  Future<void> setFocusPoint(Offset point) async {}

  @override
  Future<void> startFrameStream(
    void Function(CameraImage image) onFrame,
  ) async {
    startFrameStreamCalls++;
    _frameCallback = onFrame;
  }

  @override
  Future<void> stopFrameStream() async {
    stopFrameStreamCalls++;
    _frameCallback = null;
  }

  @override
  Future<void> switchCamera() async {}

  @override
  Future<XFile> takePicture() async {
    takePictureCalls++;
    if (captureGate case final gate?) await gate;
    if (_captureIndex >= _capturePaths.length) {
      throw StateError('No fake capture path remains.');
    }
    return XFile(_capturePaths[_captureIndex++]);
  }
}

class _FakeSaucerDetector implements SaucerDetector {
  const _FakeSaucerDetector();

  @override
  bool get isAvailable => true;

  @override
  Future<SaucerDetectionResult?> detect(AnalysisFrame frame) async {
    return const SaucerDetectionResult(
      confidence: 0.9,
      normalizedBounds: Rect.fromLTWH(0.104, 0.2418, 0.792, 0.3564),
    );
  }
}

class _FakeResidueAnalyzer extends SaucerResidueAnalyzer {
  var calls = 0;

  @override
  Future<ResidueAnalysisResult> analyze({
    required AnalysisFrame frame,
    required SaucerDetectionResult? saucer,
    required ResidueDetectionProfile profile,
  }) async {
    calls++;
    final values = Uint8List(32 * 32)..fillRange(100, 120, 220);
    final mask = ResidueRegionMask(
      normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.8, 0.4),
      width: 32,
      height: 32,
      intensities: values,
      coverage: 0.025,
      residueBounds: const Rect.fromLTWH(0.2, 0.3, 0.2, 0.1),
      componentCount: 1,
    );
    return ResidueAnalysisResult(
      mask: mask,
      score: 0.5,
      confidence: 0.7,
      residueDetected: true,
      residueBounds: mask.residueBounds,
      boundaryUsed: saucer != null,
      analysisPerformed: true,
    );
  }
}

CameraImage _cameraImage() {
  const width = 16;
  const height = 16;
  final luminance = Uint8List(width * height)
    ..fillRange(0, width * height, 180);
  final chroma = Uint8List(width * height ~/ 4)
    ..fillRange(0, width * height ~/ 4, 128);
  // ignore: deprecated_member_use
  return CameraImage.fromPlatformData({
    'format': 35,
    'height': height,
    'width': width,
    'lensAperture': null,
    'sensorExposureTime': null,
    'sensorSensitivity': null,
    'planes': [
      {
        'bytes': luminance,
        'bytesPerPixel': 1,
        'bytesPerRow': width,
        'height': height,
        'width': width,
      },
      {
        'bytes': chroma,
        'bytesPerPixel': 1,
        'bytesPerRow': width ~/ 2,
        'height': height ~/ 2,
        'width': width ~/ 2,
      },
      {
        'bytes': chroma,
        'bytesPerPixel': 1,
        'bytesPerRow': width ~/ 2,
        'height': height ~/ 2,
        'width': width ~/ 2,
      },
    ],
  });
}
