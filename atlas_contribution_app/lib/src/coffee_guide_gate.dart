import 'package:flutter/material.dart';
import 'coffee_guide_page.dart';
import 'coffee_guide_store.dart';

/// One check per root-widget lifetime; resume/rebuild/navigation is not a launch.
class CoffeeGuideGate extends StatefulWidget {
  const CoffeeGuideGate({required this.store, required this.child, super.key});
  final CoffeeGuideStore store;
  final Widget child;

  @override
  State<CoffeeGuideGate> createState() => _CoffeeGuideGateState();
}

class _CoffeeGuideGateState extends State<CoffeeGuideGate> {
  CoffeeGuideState? _state;
  bool _show = true;
  Future<void>? _presentationWrite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    CoffeeGuideState state;
    try {
      state = await widget.store.read();
    } catch (_) {
      state = const CoffeeGuideState();
    }
    if (!mounted) return;
    setState(() {
      _show = !state.dontShowAgain;
      _state = _show ? state.presented() : state;
    });
    if (_show) {
      // Count an actual rendered guide even if the process closes mid-tour.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _show) {
          _presentationWrite = widget.store.save(_state!).catchError((
            Object _,
          ) {
            // Completion retries the full state; it must never block entry.
          });
        }
      });
    }
  }

  Future<void> _finish(bool suppress) async {
    await _presentationWrite;
    var failed = false;
    try {
      await widget.store.save(
        CoffeeGuideState(
          shownCount: _state!.shownCount,
          dontShowAgain: _state!.shownCount >= 2 && suppress,
        ),
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _show = false);
    if (failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rehber tercihi kaydedilemedi. Sonraki açılışta yeniden gösterilebilir.',
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_show) return widget.child;
    return CoffeeGuidePage(
      allowSuppression: _state!.shownCount >= 2,
      onComplete: _finish,
    );
  }
}
