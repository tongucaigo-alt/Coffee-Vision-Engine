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
