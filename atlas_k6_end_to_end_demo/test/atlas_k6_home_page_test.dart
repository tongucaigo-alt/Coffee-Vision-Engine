import 'dart:async';

import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_controller.dart';
import 'package:atlas_k6_end_to_end_demo/src/ui/atlas_k6_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('shows the frozen dataset and idle capture command', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(_page(controller));

    expect(find.text('kds-001 research baseline'), findsOneWidget);
    expect(find.text('1 kayit'), findsOneWidget);
    expect(find.byKey(const ValueKey('idle-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disables capture while cup processing is active', (
    tester,
  ) async {
    final release = Completer<void>();
    final controller = _controller(
      analyzeFeatures: (input) async {
        await release.future;
        return createFeatureSet(input.surfaceType);
      },
    );
    await tester.pumpWidget(_page(controller));

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('cup-processing-state')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('capture-button')),
    );
    expect(button.onPressed, isNull);

    release.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders the full physical match result', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_page(controller));

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('success-state')), findsOneWidget);
    expect(find.text('Fiziksel zincir tamamlandi'), findsOneWidget);
    expect(find.text('1/2 Fincan'), findsOneWidget);
    expect(find.text('2/2 Tabak'), findsOneWidget);
    expect(find.text('physical-pattern-001'), findsNWidgets(2));
    expect(find.text('MATCH'), findsNWidgets(2));
    expect(find.textContaining('geometryCentroidX'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('camera cancellation returns to idle without results', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(
      MaterialApp(
        home: AtlasK6HomePage(
          controller: controller,
          cameraLauncher: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('idle-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('success-state')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('complete result has no narrow-phone layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    await tester.pumpWidget(_page(controller));

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('success-state')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

AtlasK6Controller _controller({AtlasFeatureAnalyzer? analyzeFeatures}) {
  return AtlasK6Controller(
    dataset: createDataset(),
    readFile: fakeRead,
    analyzeFeatures:
        analyzeFeatures ?? (input) async => createFeatureSet(input.surfaceType),
    analyzePatterns: (featureSet) async => createPatternResult(featureSet),
  );
}

Widget _page(AtlasK6Controller controller) {
  return MaterialApp(
    home: AtlasK6HomePage(
      controller: controller,
      cameraLauncher: (_) async => createCapture(),
    ),
  );
}
