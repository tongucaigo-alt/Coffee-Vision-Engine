import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'atlas_design.dart';

/// Decorative preparation indicator. Its clock is independent of photo changes.
class CoffeeLoadingAnimation extends StatefulWidget {
  const CoffeeLoadingAnimation({
    required this.active,
    required this.reducedMotion,
    this.size = 72,
    super.key,
  });
  final bool active, reducedMotion;
  final double size;

  @override
  State<CoffeeLoadingAnimation> createState() => _CoffeeLoadingAnimationState();
}

class _CoffeeLoadingAnimationState extends State<CoffeeLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  bool _loaded = false;

  void _syncPlayback() {
    if (!_loaded) return;
    if (widget.reducedMotion) {
      _controller.stop();
      _controller.value = .4;
    } else if (widget.active) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant CoffeeLoadingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Lottie.asset(
            'assets/animations/coffee-love.json',
            controller: _controller,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              if (!mounted) return;
              _loaded = true;
              _controller.duration = composition.duration;
              _syncPlayback();
            },
            errorBuilder: (_, _, _) => Icon(
              Icons.coffee_outlined,
              size: widget.size * 40 / 72,
              color: atlasCoffee,
            ),
          ),
        ),
      ),
    ),
  );
}
