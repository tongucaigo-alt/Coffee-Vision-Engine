import 'dart:async';

import 'package:flutter/foundation.dart';

/// Presentation timing only: this never feeds image analysis or capture.
class CameraLightHint extends ChangeNotifier {
  Timer? _timer;
  bool _eligible = false;
  bool _visible = false;

  bool get visible => _visible;

  void update({
    required bool live,
    required bool scanVisible,
    required bool torch,
  }) {
    final eligible = live && !scanVisible && !torch;
    if (eligible == _eligible) return;
    _eligible = eligible;
    _timer?.cancel();
    _timer = null;
    if (eligible) {
      _timer = Timer(const Duration(seconds: 2), () {
        _visible = true;
        notifyListeners();
      });
    } else if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
