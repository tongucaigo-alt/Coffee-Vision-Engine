import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_aura.dart';

void main() {
  testWidgets(
    'aura samples only eligible indices and independently varies timing',
    (tester) async {
      final aura = TarotAuraController(random: Random(17));
      final samples = <Set<int>>[];
      final strengths = <double>[];
      final times = <DateTime>[];
      var generation = 0;
      aura.addListener(() {
        if (aura.generation == generation) return;
        generation = aura.generation;
        samples.add(aura.targets.keys.toSet());
        times.add(tester.binding.clock.now());
        strengths.addAll(aura.targets.values);
      });
      final startedAt = tester.binding.clock.now();
      aura.update(available: {1, 3, 5, 7}, enabled: true, interacting: false);
      for (var n = 0; n < 40; n++) {
        await tester.pump(const Duration(milliseconds: 4600));
      }
      expect(samples.expand((s) => s).toSet(), {1, 3, 5, 7});
      expect(
        times.first.difference(startedAt).inMilliseconds,
        inInclusiveRange(2500, 4500),
      );
      for (final sample in samples) {
        expect(sample.length, inInclusiveRange(1, 2));
        expect(sample.every({1, 3, 5, 7}.contains), true);
      }
      for (final value in strengths) {
        expect(value, inInclusiveRange(.45, .75));
      }
      expect(samples.any((s) => s.length == 1), true);
      expect(samples.any((s) => s.length == 2), true);
      final intervals = <int>[];
      for (var i = 1; i < times.length; i++) {
        final ms = times[i].difference(times[i - 1]).inMilliseconds;
        intervals.add(ms);
        expect(ms, inInclusiveRange(2500, 4500));
      }
      expect(intervals.toSet().length, greaterThan(1));
      aura.dispose();
    },
  );

  testWidgets(
    'touch fades and freezes aura; hidden or reduced mode cancels it',
    (tester) async {
      final aura = TarotAuraController(random: Random(5));
      aura.update(available: {0, 2}, enabled: true, interacting: false);
      for (var i = 0; i < 45 && aura.targets.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(aura.targets, isNotEmpty);
      final generation = aura.generation;
      aura.update(available: {0, 2}, enabled: true, interacting: true);
      expect(aura.fading, true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(aura.targets, isEmpty);
      await tester.pump(const Duration(seconds: 15));
      expect(aura.generation, generation);
      aura.update(available: {2}, enabled: true, interacting: false);
      for (var i = 0; i < 45 && aura.generation == generation; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(aura.generation, generation + 1);
      expect(aura.targets.keys.every((i) => i == 2), true);
      aura.update(available: {0, 2}, enabled: false, interacting: false);
      final last = aura.generation;
      await tester.pump(const Duration(seconds: 20));
      expect(aura.targets, isEmpty);
      expect(aura.generation, last);
      aura.dispose();
    },
  );
}
