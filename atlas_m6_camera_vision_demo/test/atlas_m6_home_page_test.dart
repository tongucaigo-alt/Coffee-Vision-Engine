import 'dart:async';

import 'package:atlas_m6_camera_vision_demo/src/integration/atlas_m6_controller.dart';
import 'package:atlas_m6_camera_vision_demo/src/ui/atlas_m6_home_page.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  setUpAll(preparePipelineResults);

  testWidgets('shows idle state and capture command', (tester) async {
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    await tester.pumpWidget(_testApp(controller: controller));

    expect(find.byKey(const ValueKey('idle-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-button')), findsOneWidget);
  });

  testWidgets('shows capture state and disables repeated capture', (
    tester,
  ) async {
    final completer = Completer<CoffeeCameraCaptureResult?>();
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    await tester.pumpWidget(
      _testApp(controller: controller, launcher: (_) => completer.future),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('capturing-state')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('capture-button')),
    );
    expect(button.onPressed, isNull);

    completer.complete(null);
    await _pumpOperation(tester);
    expect(find.byKey(const ValueKey('idle-state')), findsOneWidget);
  });

  testWidgets('camera cancellation restores idle UI', (tester) async {
    final controller = AtlasM6Controller(analyze: matchingPipelineResult);
    await tester.pumpWidget(
      _testApp(controller: controller, launcher: (_) async => null),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await _pumpOperation(tester);

    expect(find.byKey(const ValueKey('idle-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('failure-state')), findsNothing);
  });

  testWidgets('renders explicit cup failure and retry action', (tester) async {
    final bundle = (await tester.runAsync(createCaptureBundle))!;
    addTearDown(() => removeTestDirectory(bundle.directory));
    final controller = AtlasM6Controller(
      deleteFile: (_) async {},
      readFile: (_) async => validPngBytes,
      analyze: (_) => throw const FormatException('invalid image'),
    );
    await tester.pumpWidget(
      _testApp(controller: controller, launcher: (_) async => bundle.result),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await _pumpOperation(tester);

    expect(find.byKey(const ValueKey('failure-state')), findsOneWidget);
    expect(find.text('Fincan hatasi'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-button')), findsOneWidget);
  });

  testWidgets('saucer failure displays preserved cup pipeline data', (
    tester,
  ) async {
    final bundle = (await tester.runAsync(createCaptureBundle))!;
    addTearDown(() => removeTestDirectory(bundle.directory));
    final controller = AtlasM6Controller(
      deleteFile: (_) async {},
      readFile: (_) async => validPngBytes,
      analyze: (input) async {
        if (input.surfaceType == VisionSurfaceType.saucer) {
          throw const FormatException('invalid image');
        }
        return cupPipelineResult;
      },
    );
    await tester.pumpWidget(
      _testApp(controller: controller, launcher: (_) async => bundle.result),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await _pumpOperation(tester);

    expect(find.text('Tabak hatasi'), findsOneWidget);
    expect(find.byKey(const ValueKey('preserved-cup-result')), findsOneWidget);
    expect(find.text('Korunan fincan sonucu'), findsOneWidget);
  });

  testWidgets('renders successful cup and saucer results', (tester) async {
    final bundle = (await tester.runAsync(createCaptureBundle))!;
    addTearDown(() => removeTestDirectory(bundle.directory));
    final controller = AtlasM6Controller(
      analyze: matchingPipelineResult,
      deleteFile: (_) async {},
      readFile: (_) async => validPngBytes,
    );
    await tester.pumpWidget(
      _testApp(controller: controller, launcher: (_) async => bundle.result),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await _pumpOperation(tester);

    expect(find.byKey(const ValueKey('success-state')), findsOneWidget);
    expect(find.text('1/2 Fincan'), findsOneWidget);
    expect(find.text('2/2 Tabak'), findsOneWidget);
    expect(find.text('cup'), findsOneWidget);
    expect(find.text('saucer'), findsOneWidget);
  });

  testWidgets('does not update UI after disposal during analysis', (
    tester,
  ) async {
    final bundle = (await tester.runAsync(createCaptureBundle))!;
    addTearDown(() => removeTestDirectory(bundle.directory));
    final completer = Completer<VisionPipelineResult>();
    final controller = AtlasM6Controller(
      analyze: (_) => completer.future,
      deleteFile: (_) async {},
      readFile: (_) async => validPngBytes,
    );
    await tester.pumpWidget(
      _testApp(controller: controller, launcher: (_) async => bundle.result),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('cup-analysis-state')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(cupPipelineResult);
    await _pumpOperation(tester);

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOperation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _testApp({
  required AtlasM6Controller controller,
  AtlasCameraLauncher? launcher,
}) {
  return MaterialApp(
    home: AtlasM6HomePage(
      controller: controller,
      cameraLauncher: launcher ?? (_) async => null,
    ),
  );
}
