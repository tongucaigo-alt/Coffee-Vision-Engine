import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/fortune_orbit.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'fixtures.dart';
import 'package:atlas_contribution_app/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('crescent cutout preserves the photo pixels beneath it', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 200),
      Paint()..color = const Color(0xff112233),
    );
    const FortuneOrbitPainter(0).paint(canvas, const Size(200, 200));
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = data!.buffer.asUint8List();
    List<int> pixel(int x, int y) =>
        pixels.sublist((y * 200 + x) * 4, (y * 200 + x) * 4 + 4);
    expect(pixel(104, 13), [17, 34, 51, 255]);
    expect(pixel(95, 19), [200, 155, 123, 255]);
    image.dispose();
    picture.dispose();
  });

  Widget screen({
    bool reduced = false,
    FortunePhase phase = FortunePhase.generating,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: FortuneScan(
          progress: FortuneProgress(phase),
          photos: [testPhoto(CaptureRole.free)],
          imageFor: (_) => MemoryImage(testImage()),
          showDecorativeSymbols: true,
        ),
      ),
    ),
  );
  FortuneOrbitPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('fortune-orbit-frame')),
              )
              .painter!
          as FortuneOrbitPainter;

  testWidgets(
    'reduced motion keeps a visible stationary orbit and phase text',
    (tester) async {
      await tester.pumpWidget(screen(reduced: true));
      final initial = painter(tester).seconds;
      await tester.pump(const Duration(seconds: 5));
      expect(painter(tester).seconds, initial);
      await tester.scrollUntilVisible(
        find.text('Fincanının hikâyesi hazırlanıyor'),
        300,
      );
      expect(find.text('Fincanının hikâyesi hazırlanıyor'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final phase in [
    FortunePhase.completed,
    FortunePhase.failed,
    FortunePhase.cancelled,
  ]) {
    testWidgets('orbit moves during preparation and stops for $phase', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      await tester.pump(const Duration(milliseconds: 700));
      final moving = painter(tester).seconds;
      expect(moving, greaterThan(0));
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsOneWidget,
      );
      await tester.pumpWidget(screen(phase: phase));
      final stopped = painter(tester).seconds;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(painter(tester).seconds, stopped);
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
