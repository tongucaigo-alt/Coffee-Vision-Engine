import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';
import 'opencv_traces_test.dart' show candidate;

void main() {
  testWidgets(
    'cold first frame waits for traces, captured observation and decoded image',
    (tester) async {
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.saving),
      );
      final flow = FortunePreparationController(progress);
      final photo = testPhoto(CaptureRole.free);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              FortunePreparationHost(controller: flow, child: child!),
          home: const Scaffold(body: Text('selection page')),
        ),
      );
      flow.begin(
        photos: [photo],
        imageFor: (_) => MemoryImage(testImage()),
        onCancel: () {},
        requireMarkedPhotos: true,
      );
      await tester.pump();
      expect(find.byType(FortuneScan), findsNothing);
      expect(find.text('selection page'), findsOneWidget);
      flow.updateTraces(TraceSet([photo], [candidate(0, 1)]), complete: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FortuneScan), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      flow.permitDisplay();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final scan = tester.widget<FortuneScan>(find.byType(FortuneScan));
      expect(scan.photos, [photo]);
      expect(scan.traces!.selected, hasLength(1));
      flow.updateTraces(TraceSet([photo], []));
      await tester.pump();
      expect(find.byType(FortuneScan), findsOneWidget);
      expect(flow.traces.selected, hasLength(1));
      flow.cancel();
      flow.updateTraces(TraceSet([photo], []), complete: true);
      expect(flow.traces.selected, hasLength(1));
      flow.finish();
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
      progress.dispose();
    },
  );
  testWidgets(
    'zero traces uses an honest message without displaying an unmarked photo',
    (tester) async {
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.generating),
      );
      final flow = FortunePreparationController(progress);
      final photo = testPhoto(CaptureRole.free);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              FortunePreparationHost(controller: flow, child: child!),
          home: const SizedBox(),
        ),
      );
      flow.begin(
        photos: [photo],
        imageFor: (_) => MemoryImage(testImage()),
        onCancel: () {},
        requireMarkedPhotos: true,
      );
      flow.permitDisplay();
      flow.updateTraces(TraceSet([photo], []), complete: true);
      await tester.pump();
      final scan = tester.widget<FortuneScan>(find.byType(FortuneScan));
      expect(scan.photos, isEmpty);
      expect(scan.noTracesMessage, isTrue);
      flow.finish();
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
      progress.dispose();
    },
  );
  test(
    'late results from a changed photograph cannot replace the active set',
    () {
      final p = ValueNotifier(const FortuneProgress(FortunePhase.saving));
      final flow = FortunePreparationController(p);
      final a = testPhoto(CaptureRole.free), b = testPhoto(CaptureRole.top);
      flow.begin(
        photos: [b],
        imageFor: (_) => MemoryImage(testImage()),
        onCancel: () {},
        requireMarkedPhotos: true,
      );
      flow.updateTraces(TraceSet([a], [candidate(0, 1)]), complete: true);
      expect(flow.traces.selected, isEmpty);
      expect(flow.readyToShow, isFalse);
      final oldEpoch = flow.epoch;
      flow.finish();
      flow.begin(
        photos: [a],
        imageFor: (_) => MemoryImage(testImage()),
        onCancel: () {},
        requireMarkedPhotos: true,
      );
      flow.permitDisplay();
      flow.updateTraces(TraceSet.empty, complete: true, epoch: oldEpoch);
      expect(flow.readyToShow, isFalse);
      flow.finish();
      flow.dispose();
      p.dispose();
    },
  );
}
