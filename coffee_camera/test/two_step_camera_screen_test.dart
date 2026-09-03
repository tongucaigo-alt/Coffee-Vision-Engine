import 'dart:io';

import 'package:camera/camera.dart';
import 'package:coffee_camera/src/analysis/device_motion_service.dart';
import 'package:coffee_camera/src/camera/camera_service.dart';
import 'package:coffee_camera/src/capture/captured_image_processor.dart';
import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/coffee_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'step effects stay active and cup restarts after returning from saucer',
    (tester) async {
      final files = await tester.runAsync(() async {
        return [await _createCaptureFile(), await _createCaptureFile()];
      });
      final cupFile = files![0];
      final unusedSaucerFile = files[1];
      final service = _FakeCameraService([cupFile.path, unusedSaucerFile.path]);

      await tester.pumpWidget(
        MaterialApp(
          home: CoffeeCameraScreen.flow(
            config: const CoffeeCameraConfig(requireSaucerCapture: true),
            cameraService: service,
            motionService: _FakeMotionService(),
            imageProcessor: const _FakeImageProcessor(),
            onCompleted: (_) {},
            onCancelled: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('coffee-camera-target-overlay')), findsOne);
      expect(_effectsTicker(tester).enabled, isTrue);
      expect(find.byKey(const Key('coffee-camera-auto-switch')), findsOne);
      expect(
        find.byKey(const Key('coffee-camera-saucer-residue-basic-effect')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('coffee-camera-shutter')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Fotoğrafı onayla'));
      expect(find.text('1/2 Fincan çekimi'), findsOne);

      await tester.tap(find.text('Fotoğrafı onayla'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('2/2 Tabak çekimi'));
      expect(find.text('2/2 Tabak çekimi'), findsOne);
      expect(find.byKey(const Key('coffee-camera-target-overlay')), findsOne);
      expect(_effectsTicker(tester).enabled, isTrue);
      expect(find.byKey(const Key('coffee-camera-auto-switch')), findsNothing);
      expect(find.byKey(const Key('coffee-camera-scan-effect')), findsNothing);
      expect(
        find.byKey(const Key('coffee-camera-saucer-residue-basic-effect')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Geri'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Yeniden çek'));
      expect(find.text('1/2 Fincan çekimi'), findsOne);

      final retake = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Yeniden çek'),
      );
      await tester.runAsync(() async {
        retake.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('coffee-camera-target-overlay')), findsOne);
      expect(_effectsTicker(tester).enabled, isTrue);
      expect(find.byKey(const Key('coffee-camera-auto-switch')), findsOne);
      expect(
        find.byKey(const Key('coffee-camera-saucer-residue-basic-effect')),
        findsNothing,
      );
      expect(service.startFrameStreamCalls, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.runAsync(() => _deleteIfExists(unusedSaucerFile.path));
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget was not rendered: $finder');
}

TickerMode _effectsTicker(WidgetTester tester) {
  return tester.widget<TickerMode>(
    find.byKey(const Key('coffee-camera-effects-ticker')),
  );
}

Future<File> _createCaptureFile() async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'coffee-camera-screen-${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(_onePixelPng);
  return file;
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
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

class _FakeImageProcessor extends CapturedImageProcessor {
  const _FakeImageProcessor();

  @override
  Future<ProcessedCapture> process({
    required String path,
    required Size viewportSize,
    required CoffeeCameraConfig config,
    Rect? normalizedCupBounds,
    Rect? normalizedSubjectBounds,
    bool previewMirrored = false,
    bool createCrop = true,
    TargetGeometry? targetGeometry,
    double? cropPaddingRatio,
    String cropFileSuffix = 'cup_crop',
  }) async {
    return ProcessedCapture(
      originalPath: path,
      originalWidth: 1,
      originalHeight: 1,
      originalBytes: 1,
    );
  }
}

class _FakeCameraService implements CameraService {
  _FakeCameraService(this.capturePaths);

  final List<String> capturePaths;
  var _captureIndex = 0;
  var _initialized = false;
  var startFrameStreamCalls = 0;

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
  Future<void> initialize() async => _initialized = true;

  @override
  Future<void> resume() async => _initialized = true;

  @override
  Future<void> pause() async => _initialized = false;

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
  }

  @override
  Future<void> stopFrameStream() async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<XFile> takePicture() async {
    return XFile(capturePaths[_captureIndex++]);
  }
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
