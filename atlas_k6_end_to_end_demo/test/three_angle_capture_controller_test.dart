import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_capture_file_cleaner.dart';
import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_controller.dart';
import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_models.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtlasThreeAngleCaptureState', () {
    test('uses the exact canonical role order and immutable slots', () {
      final state = AtlasThreeAngleCaptureState();

      expect(state.slots.map((slot) => slot.role), AtlasCupCaptureRole.values);
      expect(state.nextIncompleteRole, AtlasCupCaptureRole.top);
      expect(
        () => state.slots.add(
          const AtlasCupCaptureSlot(role: AtlasCupCaptureRole.top),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => AtlasThreeAngleCaptureState(slots: state.slots.reversed),
        throwsArgumentError,
      );
    });
  });

  group('AtlasThreeAngleCaptureController', () {
    test('rejects a skipped role before invoking the camera', () async {
      var operationCalls = 0;
      final controller = AtlasThreeAngleCaptureController((_) async {});

      await expectLater(
        controller.capture(AtlasCupCaptureRole.handleRight, () async {
          operationCalls++;
          return _capture('unexpected');
        }),
        throwsArgumentError,
      );

      expect(operationCalls, 0);
      await controller.close();
    });

    test(
      'invokes one camera operation and rejects concurrent attempts',
      () async {
        final firstOperation = Completer<CameraCaptureResult?>();
        var secondOperationCalls = 0;
        final controller = AtlasThreeAngleCaptureController((_) async {});

        final first = controller.capture(
          AtlasCupCaptureRole.top,
          () => firstOperation.future,
        );
        expect(controller.state.activeRole, AtlasCupCaptureRole.top);

        final second = await controller.capture(
          AtlasCupCaptureRole.top,
          () async {
            secondOperationCalls++;
            return _capture('unexpected');
          },
        );
        expect(second, isFalse);
        expect(secondOperationCalls, 0);

        firstOperation.complete(null);
        expect(await first, isTrue);
        expect(controller.state.captureFor(AtlasCupCaptureRole.top), isNull);
        await controller.close();
      },
    );

    test(
      'cancellation and failure preserve an approved retake source',
      () async {
        final original = _capture('top-original');
        final controller = AtlasThreeAngleCaptureController((_) async {});
        await controller.capture(AtlasCupCaptureRole.top, () async => original);

        await controller.capture(AtlasCupCaptureRole.top, () async => null);
        expect(
          identical(
            controller.state.captureFor(AtlasCupCaptureRole.top),
            original,
          ),
          isTrue,
        );

        await controller.capture(AtlasCupCaptureRole.top, () async {
          throw StateError('diagnostic camera failure');
        });
        expect(
          identical(
            controller.state.captureFor(AtlasCupCaptureRole.top),
            original,
          ),
          isTrue,
        );
        expect(controller.state.errorMessage, isNotNull);
        await controller.close();
      },
    );

    test(
      'retake commits first and releases only the replaced result',
      () async {
        final original = _capture('top-original');
        final replacement = _capture('top-replacement');
        final released = <CameraCaptureResult>[];
        final controller = AtlasThreeAngleCaptureController((captures) async {
          released.addAll(captures);
        });

        await controller.capture(AtlasCupCaptureRole.top, () async => original);
        await controller.capture(
          AtlasCupCaptureRole.top,
          () async => replacement,
        );

        expect(
          identical(
            controller.state.captureFor(AtlasCupCaptureRole.top),
            replacement,
          ),
          isTrue,
        );
        expect(released, hasLength(1));
        expect(identical(released.single, original), isTrue);
        await controller.close();
      },
    );

    test(
      'completed result is immutable and preserves exact instances',
      () async {
        final captures = [
          _capture('top'),
          _capture('handle-right'),
          _capture('handle-left'),
        ];
        final controller = AtlasThreeAngleCaptureController((_) async {});
        for (
          var index = 0;
          index < AtlasCupCaptureRole.values.length;
          index++
        ) {
          await controller.capture(
            AtlasCupCaptureRole.values[index],
            () async => captures[index],
          );
        }

        final result = controller.takeCompletedResult();

        for (var index = 0; index < captures.length; index++) {
          expect(
            identical(
              result.captureFor(AtlasCupCaptureRole.values[index]),
              captures[index],
            ),
            isTrue,
          );
        }
        expect(() => result.slots.clear(), throwsUnsupportedError);
        expect(() => result.captures.clear(), throwsUnsupportedError);
        expect(controller.state.completedCount, 0);
        await controller.close();
      },
    );

    test(
      'discard releases every approved capture and resets the session',
      () async {
        final captures = [_capture('top'), _capture('handle-right')];
        final released = <CameraCaptureResult>[];
        final controller = AtlasThreeAngleCaptureController((values) async {
          released.addAll(values);
        });
        await controller.capture(
          AtlasCupCaptureRole.top,
          () async => captures[0],
        );
        await controller.capture(
          AtlasCupCaptureRole.handleRight,
          () async => captures[1],
        );

        expect(await controller.discard(), isTrue);

        expect(released, captures);
        expect(controller.state.completedCount, 0);
        expect(controller.state.nextIncompleteRole, AtlasCupCaptureRole.top);
        await controller.close();
      },
    );
  });

  test('file cleanup deduplicates original and cropped paths', () async {
    final directory = await Directory.systemTemp.createTemp(
      'atlas-three-angle-cleanup-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final first = File('${directory.path}${Platform.pathSeparator}first.jpg');
    final second = File('${directory.path}${Platform.pathSeparator}second.jpg');
    await first.writeAsString('first');
    await second.writeAsString('second');

    await const AtlasCaptureFileCleaner().release([
      _capture(first.path, croppedCupPath: first.path),
      _capture(second.path, croppedCupPath: first.path),
    ]);

    expect(await first.exists(), isFalse);
    expect(await second.exists(), isFalse);
  });
}

CameraCaptureResult _capture(String path, {String? croppedCupPath}) {
  return CameraCaptureResult(
    filePath: path,
    croppedCupPath: croppedCupPath,
    cropRect: const Rect.fromLTWH(0, 0, 10, 10),
    widthPixels: 100,
    heightPixels: 100,
    fileSizeBytes: 10,
    croppedWidthPixels: croppedCupPath == null ? null : 80,
    croppedHeightPixels: croppedCupPath == null ? null : 80,
    croppedFileSizeBytes: croppedCupPath == null ? null : 8,
    capturedAt: DateTime.utc(2026, 9, 3),
    qualityScore: 80,
    coffeePresenceScore: 0.8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}
