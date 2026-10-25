part of 'tarot_pages.dart';

class _TarotRevealGuidance extends StatefulWidget {
  const _TarotRevealGuidance({
    required this.position,
    required this.active,
    required this.nudge,
    required this.child,
    this.dimmed = false,
  });
  final int position, nudge;
  final bool active, dimmed;
  final Widget child;
  @override
  State<_TarotRevealGuidance> createState() => _TarotRevealGuidanceState();
}

class _TarotRevealGuidanceState extends State<_TarotRevealGuidance>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _cycle, _nudge;
  bool _foreground = true, _motion = false;
  bool get _running => widget.active && _foreground && _motion;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _cycle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _nudge =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _running) _cycle.repeat();
        });
  }

  void _sync() {
    if (_running) {
      if (!_cycle.isAnimating && !_nudge.isAnimating) _cycle.repeat();
    } else {
      _cycle.stop();
      _nudge.stop();
      _cycle.value = 0;
      _nudge.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    _sync();
  }

  @override
  void didUpdateWidget(_TarotRevealGuidance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
    if (widget.nudge != oldWidget.nudge && _running && !_nudge.isAnimating) {
      _cycle.stop();
      _cycle.value = 0;
      _nudge.forward(from: 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cycle.dispose();
    _nudge.dispose();
    super.dispose();
  }

  double _shake(double t) {
    const points = [
      (0.0, 0.0),
      (.68, 0.0),
      (.72, -1.0),
      (.76, 1.0),
      (.80, -.5),
      (.84, .5),
      (.88, 0.0),
      (1.0, 0.0),
    ];
    for (var i = 1; i < points.length; i++) {
      if (t <= points[i].$1) {
        final a = points[i - 1], b = points[i];
        final v = Curves.easeInOut.transform(
          ((t - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0),
        );
        return a.$2 + (b.$2 - a.$2) * v;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: widget.dimmed ? .72 : 1,
    child: AnimatedBuilder(
      animation: Listenable.merge([_cycle, _nudge]),
      child: widget.child,
      builder: (context, child) {
        final shake = _running && !_nudge.isAnimating
            ? _shake(_cycle.value)
            : 0.0;
        return Transform(
          key: ValueKey('tarot-guidance-motion-${widget.position}'),
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(shake * 2, 0, 0, 1)
            ..rotateZ(shake * .7 * math.pi / 180),
          child: Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              child!,
              if (widget.active)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        key: ValueKey(
                          'tarot-guidance-sheen-${widget.position}',
                        ),
                        foregroundPainter: _TarotGlassPainter(
                          phase: _cycle.value,
                          moving: _running,
                          nudgeProgress: _nudge.isAnimating
                              ? _nudge.value
                              : null,
                        ),
                        child: DecoratedBox(
                          key: ValueKey(
                            'tarot-guidance-active-${widget.position}',
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: atlasCopper, width: 2),
                            boxShadow: const [],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _TarotGlassPainter extends CustomPainter {
  const _TarotGlassPainter({
    required this.phase,
    required this.moving,
    this.nudgeProgress,
  });
  final double phase;
  final bool moving;
  final double? nudgeProgress;
  @override
  void paint(Canvas canvas, Size size) {
    if (!moving) return;
    final t = phase;
    final progress = nudgeProgress ?? ((t - .18) / .44).clamp(0.0, 1.0);
    final opacity = nudgeProgress != null
        ? math.sin(nudgeProgress! * math.pi) * .9
        : t < .18 || t >= .72
        ? 0.0
        : t < .30
        ? (t - .18) / .12 * .9
        : t <= .62
        ? .9
        : (.72 - t) / .10 * .9;
    if (opacity <= 0) return;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
    );
    canvas.translate(size.width * (-.65 + 1.85 * progress), size.height / 2);
    canvas.rotate(18 * math.pi / 180);
    final rect = Rect.fromLTWH(
      0,
      -size.height * .7,
      size.width * .48,
      size.height * 1.4,
    );
    final shader = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xfffffae1).withValues(alpha: .12 * opacity),
        Colors.white.withValues(alpha: .78 * opacity),
        const Color(0xfffffae1).withValues(alpha: .12 * opacity),
        Colors.transparent,
      ],
      stops: const [0, .24, .5, .76, 1],
    ).createShader(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TarotGlassPainter old) =>
      phase != old.phase ||
      moving != old.moving ||
      nudgeProgress != old.nudgeProgress;
}
