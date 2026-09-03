import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/foundation.dart';

import 'atlas_three_angle_capture_models.dart';

typedef AtlasCupCaptureOperation = Future<CameraCaptureResult?> Function();
typedef AtlasCaptureRelease =
    Future<void> Function(Iterable<CameraCaptureResult> captures);

final class AtlasThreeAngleCaptureController extends ChangeNotifier {
  AtlasThreeAngleCaptureController(this._release);

  final AtlasCaptureRelease _release;

  AtlasThreeAngleCaptureState _state = AtlasThreeAngleCaptureState();
  bool _closed = false;

  AtlasThreeAngleCaptureState get state => _state;

  Future<bool> capture(
    AtlasCupCaptureRole role,
    AtlasCupCaptureOperation operation,
  ) async {
    if (_closed || _state.isBusy) return false;
    if (_state.captureFor(role) == null && _state.nextIncompleteRole != role) {
      throw ArgumentError.value(
        role,
        'role',
        'must be the next incomplete role or a completed retake',
      );
    }

    final previous = _state.captureFor(role);
    _setState(_state.startCapture(role));
    CameraCaptureResult? captured;
    try {
      captured = await operation();
    } catch (_) {
      if (!_closed) {
        _setState(
          _state.failCapture(
            'Fotoğraf çekimi tamamlanamadı. Lütfen tekrar deneyin.',
          ),
        );
      }
      return true;
    }

    if (_closed) {
      if (captured != null) await _safeRelease([captured]);
      return true;
    }
    if (captured == null) {
      _setState(_state.cancelCapture());
      return true;
    }

    _setState(_state.store(role, captured));
    if (previous != null && !identical(previous, captured)) {
      await _safeRelease([previous]);
    }
    return true;
  }

  AtlasThreeAngleCupCaptureResult takeCompletedResult() {
    if (_closed || _state.isBusy || !_state.isComplete) {
      throw StateError('All three captures must be complete and idle.');
    }
    final result = AtlasThreeAngleCupCaptureResult(_state.slots);
    _setState(AtlasThreeAngleCaptureState());
    return result;
  }

  Future<bool> discard() async {
    if (_closed || _state.isBusy) return false;
    final captures = [for (final slot in _state.slots) ?slot.capture];
    _setState(AtlasThreeAngleCaptureState());
    await _safeRelease(captures);
    return true;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final captures = [for (final slot in _state.slots) ?slot.capture];
    _state = AtlasThreeAngleCaptureState();
    await _safeRelease(captures);
    super.dispose();
  }

  Future<void> _safeRelease(Iterable<CameraCaptureResult> captures) async {
    try {
      await _release(captures);
    } catch (_) {
      // A cleanup failure must not invalidate an approved capture.
    }
  }

  void _setState(AtlasThreeAngleCaptureState next) {
    if (_closed) return;
    _state = next;
    notifyListeners();
  }
}
