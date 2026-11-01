import 'package:coffee_camera/src/capture/auto_capture_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('triggers after the configured continuous stable duration', () {
    final controller = AutoCaptureController(
      stableDuration: const Duration(milliseconds: 1200),
    );
    final start = DateTime(2026);

    expect(controller.update(ready: true, now: start).shouldCapture, isFalse);
    final midway = controller.update(
      ready: true,
      now: start.add(const Duration(milliseconds: 600)),
    );
    expect(midway.progress, closeTo(0.5, 0.01));
    final completed = controller.update(
      ready: true,
      now: start.add(const Duration(milliseconds: 1200)),
    );
    expect(completed.shouldCapture, isTrue);
  });

  test('resets the countdown when readiness breaks', () {
    final controller = AutoCaptureController(
      stableDuration: const Duration(milliseconds: 1200),
    );
    final start = DateTime(2026);
    controller.update(ready: true, now: start);
    controller.update(
      ready: true,
      now: start.add(const Duration(milliseconds: 900)),
    );
    final reset = controller.update(
      ready: false,
      now: start.add(const Duration(milliseconds: 950)),
    );
    expect(reset.progress, 0);
    final restarted = controller.update(
      ready: true,
      now: start.add(const Duration(milliseconds: 1000)),
    );
    expect(restarted.progress, 0);
  });

  test('one soft failure pauses without counting either adjacent interval', () {
    final c = AutoCaptureController(
      stableDuration: const Duration(milliseconds: 1200),
    );
    final start = DateTime(2026);
    AutoCaptureUpdate frame(int ms, {bool ready = true, bool hard = false}) =>
        c.update(
          ready: ready,
          now: start.add(Duration(milliseconds: ms)),
          hardFailure: hard,
        );
    frame(0);
    frame(400);
    expect(frame(600, ready: false).progress, closeTo(1 / 3, .001));
    expect(frame(800).progress, closeTo(1 / 3, .001));
    expect(frame(1200).shouldCapture, false);
    expect(frame(1600).shouldCapture, true);
    expect(frame(1800).shouldCapture, false);
  });

  test(
    'short repeated soft failures pause; prolonged or hard failures reset',
    () {
      final c = AutoCaptureController(
        stableDuration: const Duration(milliseconds: 1200),
      );
      final start = DateTime(2026);
      AutoCaptureUpdate frame(int ms, {bool ready = true, bool hard = false}) =>
          c.update(
            ready: ready,
            now: start.add(Duration(milliseconds: ms)),
            hardFailure: hard,
          );
      frame(0);
      frame(400);
      frame(600, ready: false);
      expect(frame(700, ready: false).progress, closeTo(1 / 3, .001));
      expect(frame(1101, ready: false).progress, 0);
      frame(1200);
      frame(1600);
      expect(frame(1700, ready: false, hard: true).progress, 0);
      expect(frame(1800).shouldCapture, false);
    },
  );

  for (final pauseMs in [500, 501]) {
    test(
      'first recovered frame enforces $pauseMs ms interruption boundary',
      () {
        final controller = AutoCaptureController(
          stableDuration: const Duration(milliseconds: 1200),
        );
        final start = DateTime(2026);
        AutoCaptureUpdate frame(int ms, bool ready) => controller.update(
          ready: ready,
          now: start.add(Duration(milliseconds: ms)),
          hardFailure: false,
        );
        frame(0, true);
        frame(400, true);
        frame(600, false);
        final recovered = frame(600 + pauseMs, true);
        expect(recovered.progress, pauseMs == 500 ? closeTo(1 / 3, .001) : 0);
        expect(recovered.shouldCapture, false);
        expect(frame(850 + pauseMs, true).shouldCapture, false);
      },
    );
  }

  test(
    'time in repeated bad frames and first recovery never advances progress',
    () {
      final controller = AutoCaptureController(
        stableDuration: const Duration(milliseconds: 1200),
      );
      final start = DateTime(2026);
      AutoCaptureUpdate frame(int ms, {bool ready = true}) => controller.update(
        ready: ready,
        now: start.add(Duration(milliseconds: ms)),
        hardFailure: false,
      );
      frame(0);
      frame(400);
      for (final ms in [600, 700, 900]) {
        final paused = frame(ms, ready: false);
        expect(paused.progress, closeTo(1 / 3, .001));
        expect(paused.shouldCapture, false);
      }
      expect(frame(1000).progress, closeTo(1 / 3, .001));
      expect(frame(1400).shouldCapture, false);
      expect(frame(1800).shouldCapture, true);
      expect(frame(1900).shouldCapture, false);
    },
  );

  test(
    'a brief motion pause cannot bypass stale frames or a disabled switch',
    () {
      final controller = AutoCaptureController(
        stableDuration: const Duration(milliseconds: 1200),
      );
      final start = DateTime(2026);
      AutoCaptureUpdate frame(int ms, {bool ready = true}) => controller.update(
        ready: ready,
        now: start.add(Duration(milliseconds: ms)),
        hardFailure: false,
      );
      frame(0);
      frame(500);
      frame(600, ready: false);
      expect(frame(1400).progress, 0);
      frame(1800);
      frame(1900, ready: false);
      controller.setEnabled(false);
      expect(frame(2000).progress, 0);
      expect(frame(2500).shouldCapture, false);
      controller.setEnabled(true);
      expect(frame(2600).progress, 0);
    },
  );

  test('stale, duplicate and out-of-order frames cannot trigger', () {
    final c = AutoCaptureController(
      stableDuration: const Duration(milliseconds: 1200),
    );
    final start = DateTime(2026);
    AutoCaptureUpdate frame(int ms) =>
        c.update(ready: true, now: start.add(Duration(milliseconds: ms)));
    frame(0);
    frame(500);
    expect(frame(500).progress, closeTo(500 / 1200, .001));
    expect(frame(400).progress, closeTo(500 / 1200, .001));
    expect(frame(1300).progress, 0);
    expect(frame(1300).shouldCapture, false);
  });

  test('disabled capture never triggers and reenabling starts fresh', () {
    final c = AutoCaptureController(
      stableDuration: const Duration(milliseconds: 100),
      enabled: false,
    );
    final start = DateTime(2026);
    c.update(ready: true, now: start);
    expect(
      c
          .update(
            ready: true,
            now: start.add(const Duration(milliseconds: 200)),
          )
          .shouldCapture,
      false,
    );
    c.setEnabled(true);
    expect(
      c
          .update(
            ready: true,
            now: start.add(const Duration(milliseconds: 400)),
          )
          .progress,
      0,
    );
  });

  test('does not emit a duplicate trigger', () {
    final controller = AutoCaptureController(
      stableDuration: const Duration(milliseconds: 100),
    );
    final start = DateTime(2026);
    controller.update(ready: true, now: start);
    expect(
      controller
          .update(
            ready: true,
            now: start.add(const Duration(milliseconds: 100)),
          )
          .shouldCapture,
      isTrue,
    );
    expect(
      controller
          .update(
            ready: true,
            now: start.add(const Duration(milliseconds: 200)),
          )
          .shouldCapture,
      isFalse,
    );
  });
}
