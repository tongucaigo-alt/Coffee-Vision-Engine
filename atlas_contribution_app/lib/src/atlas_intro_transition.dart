import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'atlas_design.dart';
import 'atlas_intro_composition.dart';

/// A broad, soft wash reaches the outside of the scene before the coffee cup.
/// It paints over the existing player; no extra video or audio is created.
class AtlasParchmentDissolve extends StatelessWidget {
  const AtlasParchmentDissolve({
    required this.progress,
    required this.child,
    super.key,
  });
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topLeft,
    fit: StackFit.expand,
    children: [
      child,
      if (progress > 0)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                key: const ValueKey('atlas-parchment-wash'),
                painter: _ParchmentWash(progress.clamp(0.0, 1.0)),
              ),
            ),
          ),
        ),
    ],
  );
}

class _ParchmentWash extends CustomPainter {
  const _ParchmentWash(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    if (progress >= .98) {
      canvas.drawRect(bounds, Paint()..color = atlasCream);
      return;
    }
    final scene = AtlasIntroComposition.contentRect(size);
    final focus = Offset(
      scene.left + scene.width * .73,
      scene.top + scene.height * .48,
    );
    final reach = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ].map((corner) => (corner - focus).distance).reduce(math.max);
    final eased = Curves.easeInOutCubic.transform(progress);
    final radius = reach * (1.8 - 1.72 * eased);
    final finish = ((progress - .72) / .25).clamp(0.0, 1.0);
    final centerAlpha = Curves.easeInOut.transform(finish);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        focus,
        radius,
        [
          atlasCream.withValues(alpha: centerAlpha),
          atlasCream.withValues(alpha: centerAlpha),
          atlasCream,
        ],
        const [0, .58, 1],
      );
    canvas.drawRect(bounds, paint);

    // A fixed, faint grain avoids shimmer and disappears into the home canvas.
    final grain = Paint();
    for (var row = 0; row < 28; row++) {
      for (var column = 0; column < 18; column++) {
        final seed = (row * 131 + column * 47) % 101;
        final point = Offset(
          (column + .15 + (seed % 13) / 18) * size.width / 18,
          (row + .2 + (seed % 11) / 16) * size.height / 28,
        );
        final distance = (point - focus).distance / radius;
        final wash = ((distance - .58) / .42).clamp(0.0, 1.0);
        grain.color = atlasCoffee.withValues(
          alpha: .035 * wash * (1 - progress),
        );
        canvas.drawCircle(point, .35 + (seed % 3) * .15, grain);
      }
    }
  }

  @override
  bool shouldRepaint(_ParchmentWash oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Created once when a natural opening reaches its destination. Child state is
/// retained across bootstrap rebuilds; hints wait until the page is fully clear.
class AtlasIntroArrival extends StatefulWidget {
  const AtlasIntroArrival({required this.child, super.key});
  final Widget child;

  static bool isRevealedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ArrivalVisibility>()
          ?.revealed ??
      true;

  @override
  State<AtlasIntroArrival> createState() => _AtlasIntroArrivalState();
}

class _AtlasIntroArrivalState extends State<AtlasIntroArrival>
    with SingleTickerProviderStateMixin {
  late final _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _started = true;
      _arrival.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _arrival.forward();
    });
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: atlasCream,
    child: AnimatedBuilder(
      animation: _arrival,
      child: widget.child,
      builder: (context, child) => IgnorePointer(
        ignoring: !_arrival.isCompleted,
        child: ExcludeSemantics(
          excluding: !_arrival.isCompleted,
          child: _ArrivalVisibility(
            revealed: _arrival.isCompleted,
            child: Opacity(
              key: const ValueKey('atlas-home-arrival'),
              opacity: Curves.easeOutCubic.transform(_arrival.value),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ArrivalVisibility extends InheritedWidget {
  const _ArrivalVisibility({required this.revealed, required super.child});
  final bool revealed;

  @override
  bool updateShouldNotify(_ArrivalVisibility oldWidget) =>
      oldWidget.revealed != revealed;
}
