part of 'tarot_pages.dart';

/// Paint-only guidance: no layout space, card movement or persisted state.
class _TarotRevealGuidance extends StatefulWidget {
  const _TarotRevealGuidance({
    required this.position,
    required this.active,
    required this.nudge,
    required this.child,
  });
  final int position;
  final bool active;
  final int nudge;
  final Widget child;

  @override
  State<_TarotRevealGuidance> createState() => _TarotRevealGuidanceState();
}

class _TarotRevealGuidanceState extends State<_TarotRevealGuidance>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  late final AnimationController _nudge;
  bool _foreground = true;
  bool _motion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  void _syncAnimation() {
    final run = widget.active && _foreground && _motion;
    if (run) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _nudge.stop();
      _pulse.value = 0;
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
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_TarotRevealGuidance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
    if (widget.nudge != oldWidget.nudge &&
        widget.active &&
        _foreground &&
        _motion &&
        !_nudge.isAnimating) {
      _nudge.forward(from: 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _syncAnimation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      widget.child,
      if (widget.active)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, _nudge]),
                builder: (context, _) {
                  final moving = _foreground && _motion;
                  final boost = math.sin(_nudge.value * math.pi);
                  final strength = moving
                      ? (.45 +
                                .55 * Curves.easeInOut.transform(_pulse.value) +
                                .55 * boost)
                            .clamp(0.0, 1.0)
                      : 1.0;
                  return CustomPaint(
                    painter: _TarotGuidanceGlow(moving ? strength : 0),
                    child: DecoratedBox(
                      key: ValueKey('tarot-guidance-active-${widget.position}'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: atlasCopper.withValues(alpha: strength),
                          width: 2,
                        ),
                        boxShadow: const [],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
    ],
  );
}

class _TarotGuidanceGlow extends CustomPainter {
  const _TarotGuidanceGlow(this.strength);
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength == 0) return;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds.inflate(8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(1), const Radius.circular(9)),
      Paint()
        ..color = atlasCopper.withValues(alpha: .65 * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TarotGuidanceGlow oldDelegate) =>
      strength != oldDelegate.strength;
}

class _TarotHomeCards extends StatelessWidget {
  const _TarotHomeCards();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 152,
    child: Center(
      child: SizedBox(
        width: 164,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final offset in [-29.0, 29.0])
              Transform.translate(
                offset: Offset(offset, 8),
                child: Transform.rotate(
                  angle: offset < 0 ? -.18 : .18,
                  child: const SizedBox(
                    width: 82,
                    child: TarotCardView(showFront: false),
                  ),
                ),
              ),
            const SizedBox(width: 92, child: TarotCardView(showFront: false)),
          ],
        ),
      ),
    ),
  );
}

class _TarotMoodPicker extends StatelessWidget {
  const _TarotMoodPicker({
    required this.mood,
    required this.saving,
    required this.onSelect,
    this.error,
  });
  final TarotMood? mood;
  final bool saving;
  final String? error;
  final ValueChanged<TarotMood> onSelect;
  static const _icons = {
    TarotMood.happy: Icons.sentiment_satisfied_alt_outlined,
    TarotMood.calm: Icons.spa_outlined,
    TarotMood.unsure: Icons.help_outline,
    TarotMood.tense: Icons.thunderstorm_outlined,
    TarotMood.tired: Icons.bedtime_outlined,
  };
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('tarot-mood-picker'),
    children: [
      const Divider(color: atlasBorder, height: 1),
      const SizedBox(height: 4),
      const Text(
        'İstersen bana nasıl hissettiğini söyleyebilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Literata', fontSize: 19, height: 1.5),
      ),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(13) > 19.5
              ? (constraints.maxWidth < 340 ? 1 : 2)
              : 3;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in TarotMood.values)
                SizedBox(
                  width: width,
                  child: MergeSemantics(
                    child: Semantics(
                      selected: value == mood,
                      child: OutlinedButton(
                        key: ValueKey('tarot-mood-${value.name}'),
                        onPressed: saving ? null : () => onSelect(value),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          foregroundColor: atlasSageInk,
                          backgroundColor: value == mood
                              ? atlasSageSurface
                              : atlasCream,
                          disabledForegroundColor: atlasSageInk,
                          side: BorderSide(
                            color: value == mood ? atlasSageInk : atlasBorder,
                            width: value == mood ? 1.5 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icons[value], size: 18),
                            const SizedBox(height: 2),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 3,
                              children: [
                                if (value == mood)
                                  const Icon(Icons.check, size: 14),
                                Text(
                                  value.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 6),
      const Text(
        'Seçim yapmadan da kartlarını açabilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(color: atlasMuted, fontSize: 12, height: 1.5),
      ),
      if (error != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: atlasCopperInk, height: 1.5),
          ),
        ),
      ],
    ],
  );
}

/// Presentation only: formatting never changes the saved reading or its request.
class _TarotReadingText extends StatelessWidget {
  const _TarotReadingText(this.text);
  final String text;

  List<InlineSpan> _inline(String line) {
    final spans = <InlineSpan>[];
    var end = 0;
    for (final match in RegExp(
      r'\*\*(.+?)\*\*|\*([^*\n]+)\*',
    ).allMatches(line)) {
      if (match.start > end) {
        spans.add(TextSpan(text: line.substring(end, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1) ?? match.group(2),
          style: TextStyle(
            fontWeight: match.group(1) != null ? FontWeight.w600 : null,
            fontStyle: match.group(2) != null ? FontStyle.italic : null,
          ),
        ),
      );
      end = match.end;
    }
    if (end < line.length) spans.add(TextSpan(text: line.substring(end)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split(RegExp(r'\r?\n'));
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final markdown = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(line);
      final bold = RegExp(r'^\*\*(.+)\*\*$').firstMatch(line);
      final position = const {
        'Geçmiş',
        'Şimdi',
        'Olası Yön',
        'Günlük Odak',
        'Ortak Hikâye',
        'Kartların ortak hikâyesi',
      }.contains(line.trim());
      final heading = markdown != null || bold != null || position;
      spans.add(
        TextSpan(
          children: _inline(markdown?.group(1) ?? bold?.group(1) ?? line),
          style: heading
              ? const TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 20,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: atlasCoffee,
                )
              : null,
        ),
      );
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      key: const ValueKey('tarot-reading-text'),
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 16,
        height: 1.65,
        color: atlasInk,
      ),
    );
  }
}

class _TarotBadge extends StatelessWidget {
  const _TarotBadge(this.label, {this.copper = false});
  final String label;
  final bool copper;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: copper ? atlasCopper.withValues(alpha: .1) : atlasSageSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: copper ? atlasCopperInk : atlasSageInk,
      ),
    ),
  );
}

String _tarotStatus(TarotDraw draw) => switch (draw.result.state) {
  TarotResultState.completed => 'Yorum hazır',
  TarotResultState.running => 'Yorum hazırlanıyor',
  TarotResultState.failed => 'Yorum tamamlanamadı',
  TarotResultState.cancelled => 'Yorum iptal edildi',
  TarotResultState.interrupted => 'Yorum yarım kaldı',
  TarotResultState.idle =>
    draw.ready ? 'Yorum bekliyor' : 'Açılım tamamlanmadı',
};

class _TarotHomeFramePainter extends CustomPainter {
  const _TarotHomeFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 100 || size.height < 100) return;
    final bounds = Offset.zero & size;
    final readingArea = Rect.fromLTRB(
      20,
      16,
      size.width - 20,
      size.height - 16,
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(bounds),
        Path()..addRect(readingArea),
      ),
    );
    final copper = Paint()
      ..color = const Color(0x46b0714f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..strokeCap = StrokeCap.round;
    final sage = Paint()
      ..color = const Color(0x507ba294)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..strokeCap = StrokeCap.round;
    final leafFill = Paint()
      ..color = const Color(0x287ba294)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(6), const Radius.circular(26)),
      copper,
    );
    // Short inner corner lines echo the concentric rings of the Atlas emblem.
    for (final right in [false, true]) {
      for (final bottom in [false, true]) {
        canvas.save();
        canvas.translate(right ? size.width : 0, bottom ? size.height : 0);
        canvas.scale(right ? -1 : 1, bottom ? -1 : 1);
        canvas.drawPath(
          Path()
            ..moveTo(10, 46)
            ..lineTo(10, 32)
            ..quadraticBezierTo(10, 10, 32, 10)
            ..lineTo(46, 10),
          copper,
        );
        canvas.restore();
      }
    }
    for (final bottom in [false, true]) {
      canvas.save();
      if (bottom) {
        canvas.translate(0, size.height);
        canvas.scale(1, -1);
      }
      final center = size.width / 2;
      canvas.drawRect(
        Rect.fromLTWH(center - 47, 0, 94, 14),
        Paint()..color = atlasCream,
      );
      for (final right in [false, true]) {
        canvas.save();
        canvas.translate(center, 8);
        canvas.scale(right ? 1 : -1, 1);
        canvas.drawPath(
          Path()
            ..moveTo(9, 0)
            ..quadraticBezierTo(27, 3, 43, -1),
          sage,
        );
        for (var i = 0; i < 3; i++) {
          final x = 15.0 + i * 9;
          _leaf(canvas, Offset(x, 1), false, leafFill, sage);
          _leaf(canvas, Offset(x + 4, 1), true, leafFill, sage);
        }
        canvas.restore();
      }
      canvas.drawPath(
        Path()
          ..moveTo(center, 4)
          ..lineTo(center + 3, 8)
          ..lineTo(center, 12)
          ..lineTo(center - 3, 8)
          ..close(),
        copper,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _leaf(Canvas canvas, Offset root, bool down, Paint fill, Paint vein) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.scale(1, down ? -1 : 1);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(-1, -4, 2, -6, 6, -6)
      ..cubicTo(6, -2, 3, 0, 0, 0)
      ..close();
    canvas.drawPath(leaf, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(4.5, -4.5),
      vein,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TarotHomeFramePainter oldDelegate) => false;
}
