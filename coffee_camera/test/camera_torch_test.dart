import 'dart:async';

// Platform double verifies actual PluginCameraService calls without hardware.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:coffee_camera/src/camera/camera_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CameraPlatform previous;
  late _Platform platform;
  setUp(() {
    previous = CameraPlatform.instance;
    platform = _Platform();
    CameraPlatform.instance = platform;
  });
  tearDown(() => CameraPlatform.instance = previous);

  test('torch toggles in one tap and reopening resets it off', () async {
    final service = PluginCameraService();
    await service.initialize();
    expect(platform.openedDirection, CameraLensDirection.back);
    await service.cycleFlashMode();
    expect(service.flashMode, FlashMode.torch);
    await service.cycleFlashMode();
    expect(service.flashMode, FlashMode.off);
    expect(platform.modes, [FlashMode.off, FlashMode.torch, FlashMode.off]);
    await service.cycleFlashMode();
    await service.pause();
    await service.resume();
    expect(service.flashMode, FlashMode.off);
    expect(platform.modes.last, FlashMode.off);
    await service.dispose();
  });

  test('unsupported torch falls back off without propagating error', () async {
    final service = PluginCameraService();
    await service.initialize();
    platform.rejectTorch = true;
    await service.cycleFlashMode();
    expect(service.flashMode, FlashMode.off);
    expect(platform.modes, [FlashMode.off, FlashMode.torch, FlashMode.off]);
    await service.dispose();
  });
}

class _Platform extends CameraPlatform {
  final modes = <FlashMode>[];
  bool rejectTorch = false;
  CameraLensDirection? openedDirection;
  final _errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    ),
    CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];
  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async {
    openedDirection = description.lensDirection;
    return 1;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          1280,
          720,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    modes.add(mode);
    if (rejectTorch && mode == FlashMode.torch) {
      throw CameraException('torchUnsupported', 'test');
    }
  }

  @override
  Future<void> dispose(int cameraId) async {}
}
