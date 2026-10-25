import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Presentation-only randomness. Never receives card identities or draw RNG.
class TarotAuraController extends ChangeNotifier {
  TarotAuraController({Random? random}) : _random = random ?? Random();
  final Random _random;
  Timer? _next, _end;
  Set<int> _available = {};
  Map<int, double> _targets = {};
  bool _enabled = false, _interacting = false, _disposed = false;
  bool fading = false;
  int generation = 0;
  Map<int, double> get targets => Map.unmodifiable(_targets);

  void update({
    required Set<int> available,
    required bool enabled,
    required bool interacting,
  }) {
    if (_disposed) return;
    final wasRunning = _enabled && !_interacting;
    _available = Set.of(available);
    _enabled = enabled;
    _interacting = interacting;
    if (!enabled || available.isEmpty) {
      _next?.cancel();
      _next = null;
      _clear();
      return;
    }
    final invalid = _targets.keys.where((i) => !available.contains(i)).toList();
    if (invalid.isNotEmpty) {
      _targets = {..._targets}..removeWhere((i, _) => invalid.contains(i));
      notifyListeners();
    }
    if (interacting) {
      _next?.cancel();
      _next = null;
      if (_targets.isNotEmpty && !fading) {
        fading = true;
        _end?.cancel();
        _end = Timer(const Duration(milliseconds: 200), _clear);
        notifyListeners();
      }
    } else if (!wasRunning || _next == null) {
      _schedule();
    }
  }

  void _clear() {
    _end?.cancel();
    _end = null;
    if (_targets.isEmpty && !fading) return;
    _targets = {};
    fading = false;
    if (!_disposed) notifyListeners();
  }

  void _schedule() {
    _next?.cancel();
    _next = Timer(Duration(milliseconds: 2500 + _random.nextInt(2001)), _start);
  }

  void _start() {
    _next = null;
    if (_disposed || !_enabled || _interacting || _available.isEmpty) return;
    final pool = _available.toList()..sort();
    final count = min(pool.length, _random.nextBool() ? 1 : 2);
    _targets = {
      for (var n = 0; n < count; n++)
        pool.removeAt(_random.nextInt(pool.length)):
            .45 + .30 * _random.nextDouble(),
    };
    fading = false;
    generation++;
    _end?.cancel();
    _end = Timer(const Duration(milliseconds: 1800), _clear);
    _schedule();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _next?.cancel();
    _end?.cancel();
    super.dispose();
  }
}
