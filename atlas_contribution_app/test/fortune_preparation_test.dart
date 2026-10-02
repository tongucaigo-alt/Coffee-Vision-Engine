import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

void main() {
  testWidgets(
    'save to AI navigation keeps one scan state and cancellation owner',
    (tester) async {
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.saving),
      );
      final flow = FortunePreparationController(progress);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) =>
              FortunePreparationHost(controller: flow, child: child!),
          home: const Scaffold(body: Text('draft')),
        ),
      );
      var saveCancelled = 0, aiCancelled = 0;
      void begin(VoidCallback cancel) => flow.begin(
        photos: [testPhoto(CaptureRole.free)],
        imageFor: (_) => MemoryImage(testImage()),
        onCancel: cancel,
      );
      begin(() => saveCancelled++);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final state = tester.state(find.byType(FortuneScan));
      final firstProvider = flow.imageFor!(flow.photos.first);
      expect(
        find.byKey(const ValueKey('fortune-decorative-symbols')),
        findsOneWidget,
      );
      progress.value = const FortuneProgress(FortunePhase.analyzing);
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('result')),
        ),
      );
      begin(() => aiCancelled++);
      expect(flow.imageFor!(flow.photos.first), same(firstProvider));
      progress.value = const FortuneProgress(FortunePhase.generating);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.state(find.byType(FortuneScan)), same(state));
      expect(find.byType(FortuneScan), findsOneWidget);
      flow.cancel();
      flow.cancel();
      await tester.pump();
      expect(saveCancelled, 0);
      expect(aiCancelled, 1);
      expect(
        tester.widget<FortuneScan>(find.byType(FortuneScan)).progress.phase,
        FortunePhase.cancelled,
      );
      await tester.scrollUntilVisible(
        find.text('İşlem durduruldu; kaydın korunuyor'),
        250,
      );
      expect(
        find.text('İşlem durduruldu; kaydın korunuyor').hitTestable(),
        findsOneWidget,
      );
      flow.finish();
      await tester.pumpAndSettle();
      expect(find.byType(FortuneScan), findsNothing);
      expect(find.text('result'), findsOneWidget);
      expect(flow.cancelled, isFalse);
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
      progress.dispose();
    },
  );
}
