import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_m6_camera_vision_demo/src/integration/atlas_m6_controller.dart';
import 'package:atlas_m6_camera_vision_demo/src/integration/atlas_m6_state.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  setUpAll(preparePipelineResults);

  test('runs capture, cup, saucer, and success in exact order', () async {
    final bundle = await createCaptureBundle();
    final phases = <AtlasM6Phase>[];
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    controller.addListener(() => phases.add(controller.state.phase));
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    expect(await controller.startCapture(() async => bundle.result), isTrue);

    expect(phases, [
      AtlasM6Phase.capturing,
      AtlasM6Phase.analyzingCup,
      AtlasM6Phase.analyzingSaucer,
      AtlasM6Phase.success,
    ]);
  });

  test('analyzes cup before saucer with exact surface types', () async {
    final bundle = await createCaptureBundle();
    final surfaces = <VisionSurfaceType>[];
    final controller = AtlasM6Controller(
      analyze: (input) async {
        surfaces.add(input.surfaceType);
        return matchingPipelineResult(input);
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);

    expect(surfaces, [VisionSurfaceType.cup, VisionSurfaceType.saucer]);
  });

  test('prefers surface crop and falls back to original path', () async {
    final bundle = await createCaptureBundle(includeSaucerCrop: false);
    final readPaths = <String>[];
    final controller = AtlasM6Controller(
      readFile: (path) async {
        readPaths.add(path);
        return validPngBytes;
      },
      analyze: matchingPipelineResult,
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);

    expect(readPaths, [bundle.cupCropPath, bundle.saucerOriginalPath]);
  });

  test('rejects duplicate capture while camera operation is active', () async {
    final bundle = await createCaptureBundle();
    final captureCompleter = Completer<CoffeeCameraCaptureResult?>();
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    final first = controller.startCapture(() => captureCompleter.future);
    expect(controller.state.phase, AtlasM6Phase.capturing);
    expect(await controller.startCapture(() async => bundle.result), isFalse);
    captureCompleter.complete(bundle.result);
    expect(await first, isTrue);
  });

  test('rejects capture and retry while analysis is active', () async {
    final bundle = await createCaptureBundle();
    final analysisCompleter = Completer<VisionPipelineResult>();
    final controller = AtlasM6Controller(
      analyze: (input) {
        if (input.surfaceType == VisionSurfaceType.cup) {
          return analysisCompleter.future;
        }
        return matchingPipelineResult(input);
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    final operation = controller.startCapture(() async => bundle.result);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.phase, AtlasM6Phase.analyzingCup);
    expect(await controller.startCapture(() async => bundle.result), isFalse);
    expect(await controller.retry(), isFalse);
    analysisCompleter.complete(cupPipelineResult);
    await operation;
  });

  test('cup failure prevents saucer analysis', () async {
    final bundle = await createCaptureBundle();
    final surfaces = <VisionSurfaceType>[];
    final controller = AtlasM6Controller(
      analyze: (input) async {
        surfaces.add(input.surfaceType);
        throw const FormatException('invalid image');
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);

    expect(surfaces, [VisionSurfaceType.cup]);
    expect(controller.state.failureStage, AtlasM6FailureStage.cupAnalysis);
    expect(controller.state.captureResult, same(bundle.result));
  });

  test('saucer failure preserves successful cup result and duration', () async {
    final bundle = await createCaptureBundle();
    final controller = AtlasM6Controller(
      analyze: (input) async {
        if (input.surfaceType == VisionSurfaceType.saucer) {
          throw const FormatException('invalid image');
        }
        return cupPipelineResult;
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);

    expect(controller.state.failureStage, AtlasM6FailureStage.saucerAnalysis);
    expect(controller.state.captureResult, same(bundle.result));
    expect(controller.state.cupVisionResult, same(cupPipelineResult));
    expect(controller.state.cupAnalysisDuration, isNotNull);
    expect(controller.state.saucerAnalysisDuration, isNotNull);
  });

  test('retry after cup failure reruns cup and then saucer', () async {
    final bundle = await createCaptureBundle();
    final surfaces = <VisionSurfaceType>[];
    var failCup = true;
    final controller = AtlasM6Controller(
      analyze: (input) async {
        surfaces.add(input.surfaceType);
        if (input.surfaceType == VisionSurfaceType.cup && failCup) {
          failCup = false;
          throw const FormatException('invalid image');
        }
        return matchingPipelineResult(input);
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);
    expect(await controller.retry(), isTrue);

    expect(surfaces, [
      VisionSurfaceType.cup,
      VisionSurfaceType.cup,
      VisionSurfaceType.saucer,
    ]);
    expect(controller.state.phase, AtlasM6Phase.success);
  });

  test('retry after saucer failure reruns only saucer', () async {
    final bundle = await createCaptureBundle();
    final surfaces = <VisionSurfaceType>[];
    var failSaucer = true;
    final controller = AtlasM6Controller(
      analyze: (input) async {
        surfaces.add(input.surfaceType);
        if (input.surfaceType == VisionSurfaceType.saucer && failSaucer) {
          failSaucer = false;
          throw const FormatException('invalid image');
        }
        return matchingPipelineResult(input);
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);
    final preservedCup = controller.state.cupVisionResult;
    expect(await controller.retry(), isTrue);

    expect(surfaces, [
      VisionSurfaceType.cup,
      VisionSurfaceType.saucer,
      VisionSurfaceType.saucer,
    ]);
    expect(controller.state.result!.cupVisionResult, same(preservedCup));
  });

  test(
    'retains original capture and complete pipeline result identities',
    () async {
      final bundle = await createCaptureBundle();
      final controller = AtlasM6Controller(analyze: matchingPipelineResult);
      addTearDown(controller.close);
      addTearDown(() => removeTestDirectory(bundle.directory));

      await controller.startCapture(() async => bundle.result);
      final result = controller.state.result!;

      expect(result.captureResult, same(bundle.result));
      expect(result.cupVisionResult, same(cupPipelineResult));
      expect(result.saucerVisionResult, same(saucerPipelineResult));
      expect(result.cupAnalysisDuration, isA<Duration>());
      expect(result.saucerAnalysisDuration, isA<Duration>());
    },
  );

  test('records separate non-negative cup and saucer durations', () async {
    final bundle = await createCaptureBundle();
    final controller = AtlasM6Controller(
      analyze: (input) async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        return matchingPipelineResult(input);
      },
    );
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);

    expect(
      controller.state.result!.cupAnalysisDuration,
      greaterThan(Duration.zero),
    );
    expect(
      controller.state.result!.saucerAnalysisDuration,
      greaterThan(Duration.zero),
    );
  });

  group('controlled input failures', () {
    test('missing file', () async {
      final bundle = await createCaptureBundle();
      await File(bundle.cupCropPath!).delete();
      final controller = AtlasM6Controller();
      addTearDown(controller.close);
      addTearDown(() => removeTestDirectory(bundle.directory));

      await controller.startCapture(() async => bundle.result);
      expect(controller.state.failureStage, AtlasM6FailureStage.cupAnalysis);
    });

    test('empty file', () async {
      final bundle = await createCaptureBundle(cupBytes: Uint8List(0));
      final controller = AtlasM6Controller();
      addTearDown(controller.close);
      addTearDown(() => removeTestDirectory(bundle.directory));

      await controller.startCapture(() async => bundle.result);
      expect(controller.state.failureStage, AtlasM6FailureStage.cupAnalysis);
    });

    test('corrupt file', () async {
      final bundle = await createCaptureBundle(
        cupBytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      final controller = AtlasM6Controller();
      addTearDown(controller.close);
      addTearDown(() => removeTestDirectory(bundle.directory));

      await controller.startCapture(() async => bundle.result);
      expect(controller.state.failureStage, AtlasM6FailureStage.cupAnalysis);
    });

    test('inaccessible file', () async {
      final bundle = await createCaptureBundle();
      final controller = AtlasM6Controller(
        readFile: (_) => throw const FileSystemException('access denied'),
      );
      addTearDown(controller.close);
      addTearDown(() => removeTestDirectory(bundle.directory));

      await controller.startCapture(() async => bundle.result);
      expect(controller.state.failureStage, AtlasM6FailureStage.cupAnalysis);
    });
  });

  test('does not modify source bytes', () async {
    final bundle = await createCaptureBundle();
    final beforeCup = await File(bundle.cupCropPath!).readAsBytes();
    final beforeSaucer = await File(bundle.saucerCropPath!).readAsBytes();
    final controller = AtlasM6Controller();
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => bundle.result);

    expect(await File(bundle.cupCropPath!).readAsBytes(), beforeCup);
    expect(await File(bundle.saucerCropPath!).readAsBytes(), beforeSaucer);
  });

  test('camera cancellation restores previous stable state', () async {
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    addTearDown(controller.close);

    await controller.startCapture(() async => null);

    expect(controller.state.phase, AtlasM6Phase.idle);
  });

  test('rejects incomplete capture without a saucer', () async {
    final bundle = await createCaptureBundle();
    final incomplete = CoffeeCameraCaptureResult(
      cup: captureWithoutSaucer(bundle.cupOriginalPath),
    );
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    addTearDown(controller.close);
    addTearDown(() => removeTestDirectory(bundle.directory));

    await controller.startCapture(() async => incomplete);

    expect(controller.state.failureStage, AtlasM6FailureStage.capture);
  });

  test(
    'close waits for active analysis and suppresses stale updates',
    () async {
      final bundle = await createCaptureBundle();
      final analysisCompleter = Completer<VisionPipelineResult>();
      final controller = AtlasM6Controller(
        analyze: (_) => analysisCompleter.future,
      );
      addTearDown(() => removeTestDirectory(bundle.directory));

      final operation = controller.startCapture(() async => bundle.result);
      await Future<void>.delayed(Duration.zero);
      final closeFuture = controller.close();
      var closed = false;
      closeFuture.then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);

      analysisCompleter.complete(cupPipelineResult);
      await operation;
      await closeFuture;
      expect(closed, isTrue);
    },
  );
}
