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

/// Consumes distinct analysis frames, never UI ticks or a wall-clock deadline.
class AutoCaptureController {
  AutoCaptureController({required this.stableDuration, this.enabled = true});

  static const maximumFrameGap = Duration(milliseconds: 750);
  final Duration stableDuration;
  bool enabled;
  DateTime? _lastFrameAt;
  Duration _readyDuration = Duration.zero;
  bool _previousReady = false;
  int _softFailures = 0;
  bool _triggered = false;

  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    reset();
  }

  AutoCaptureUpdate update({
    required bool ready,
    required DateTime now,
    bool hardFailure = true,
  }) {
    if (!enabled) {
      reset();
      return _snapshot();
    }
    final previous = _lastFrameAt;
    // Duplicate/out-of-order frames cannot accrue time or emit a trigger.
    if (previous != null && !now.isAfter(previous)) return _snapshot();
    final gap = previous == null ? Duration.zero : now.difference(previous);
    if (gap > maximumFrameGap) reset();
    _lastFrameAt = now;
    if (_triggered) return _snapshot();

    if (!ready) {
      _softFailures++;
      if (hardFailure || _softFailures >= 2) {
        reset();
        _lastFrameAt = now;
      } else {
        _previousReady = false;
      }
      return _snapshot();
    }
    if (_previousReady && gap <= maximumFrameGap) _readyDuration += gap;
    _previousReady = true;
    _softFailures = 0;
    if (_readyDuration >= stableDuration) {
      _triggered = true;
      return _snapshot(shouldCapture: true);
    }
    return _snapshot();
  }

  AutoCaptureUpdate _snapshot({bool shouldCapture = false}) =>
      AutoCaptureUpdate(
        phase: _triggered
            ? AutoCapturePhase.triggered
            : _previousReady || _softFailures > 0
            ? AutoCapturePhase.stabilizing
            : AutoCapturePhase.idle,
        progress:
            (_readyDuration.inMicroseconds / stableDuration.inMicroseconds)
                .clamp(0.0, 1.0),
        shouldCapture: shouldCapture,
      );

  void reset() {
    _lastFrameAt = null;
    _readyDuration = Duration.zero;
    _previousReady = false;
    _softFailures = 0;
    _triggered = false;
  }
}
