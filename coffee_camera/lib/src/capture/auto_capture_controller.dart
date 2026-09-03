enum AutoCapturePhase { idle, stabilizing, triggered }

class AutoCaptureUpdate {
  const AutoCaptureUpdate({
    required this.phase,
    required this.progress,
    required this.shouldCapture,
  });

  final AutoCapturePhase phase;
  final double progress;
  final bool shouldCapture;
}

class AutoCaptureController {
  AutoCaptureController({required this.stableDuration, this.enabled = true});

  final Duration stableDuration;
  bool enabled;
  DateTime? _readySince;
  bool _triggered = false;

  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    reset();
  }

  AutoCaptureUpdate update({required bool ready, required DateTime now}) {
    if (!enabled || !ready) {
      reset();
      return const AutoCaptureUpdate(
        phase: AutoCapturePhase.idle,
        progress: 0,
        shouldCapture: false,
      );
    }

    _readySince ??= now;
    final elapsed = now.difference(_readySince!);
    final progress = (elapsed.inMicroseconds / stableDuration.inMicroseconds)
        .clamp(0.0, 1.0);
    if (progress >= 1 && !_triggered) {
      _triggered = true;
      return const AutoCaptureUpdate(
        phase: AutoCapturePhase.triggered,
        progress: 1,
        shouldCapture: true,
      );
    }
    return AutoCaptureUpdate(
      phase: _triggered
          ? AutoCapturePhase.triggered
          : AutoCapturePhase.stabilizing,
      progress: progress,
      shouldCapture: false,
    );
  }

  void reset() {
    _readySince = null;
    _triggered = false;
  }
}
