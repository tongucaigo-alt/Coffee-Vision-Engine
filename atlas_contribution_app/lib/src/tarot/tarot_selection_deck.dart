part of 'tarot_pages.dart';

class _TarotSelectionDeck extends StatefulWidget {
  const _TarotSelectionDeck({
    required this.controller,
    required this.selected,
    required this.locked,
    required this.onSelect,
  });
  final ScrollController controller;
  final Set<int> selected;
  final bool locked;
  final ValueChanged<int> onSelect;
  @override
  State<_TarotSelectionDeck> createState() => _TarotSelectionDeckState();
}

class _TarotSelectionDeckState extends State<_TarotSelectionDeck>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _step = 52.0, _width = 84.0, _height = 126.0, _padding = 12.0;
  static const _contentWidth = _padding * 2 + 77 * _step + _width;
  late final TarotAuraController _aura;
  late final AnimationController _wave, _fade;
  double _viewport = 0;
  bool _foreground = true, _motion = false, _scrolling = false, _queued = false;
  int _pointers = 0, _generation = 0;
  double get _offset =>
      widget.controller.hasClients ? widget.controller.offset : 0;
  bool get _enabled => _foreground && _motion && !widget.locked;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    _aura = TarotAuraController()..addListener(_auraChanged);
    widget.controller.addListener(_scrolled);
  }

  Set<int> _available() => {
    for (var i = 0; i < 78; i++)
      if (!widget.selected.contains(i) &&
          _viewport > 0 &&
          _padding + i * _step + _width >= _offset + 48 &&
          _padding + i * _step <= _offset + _viewport - 48)
        i,
  };
  void _sync() => _aura.update(
    available: _available(),
    enabled: _enabled,
    interacting: _pointers > 0 || _scrolling,
  );
  void _queueSync() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _sync();
    });
  }

  void _auraChanged() {
    if (_aura.targets.isEmpty) {
      _wave.stop();
      _fade.stop();
      _wave.value = 0;
      _fade.value = 1;
    } else if (_aura.fading) {
      _wave.stop();
      _fade.reverse(from: 1);
    } else if (_generation != _aura.generation) {
      _generation = _aura.generation;
      _fade.value = 1;
      _wave.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  void _scrolled() {
    if (mounted) {
      setState(() {});
      _queueSync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    _queueSync();
  }

  @override
  void didUpdateWidget(_TarotSelectionDeck old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_scrolled);
      widget.controller.addListener(_scrolled);
    }
    _queueSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
    });
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_scrolled);
    _aura.removeListener(_auraChanged);
    _aura.dispose();
    _wave.dispose();
    _fade.dispose();
    super.dispose();
  }

  double _distance(int i) =>
      (i - ((_offset + _viewport / 2 - _padding - _width / 2) / _step)).clamp(
        -3.0,
        3.0,
      );
  Widget _positioned(int i, Widget child, {required Key key}) => Positioned(
    key: key,
    left: _padding + i * _step,
    top: 47 + _distance(i).abs() * 5,
    width: _width,
    height: _height,
    child: Transform.rotate(angle: _distance(i) * math.pi / 90, child: child),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('tarot-deck'),
    height: 220,
    child: ColoredBox(
      color: atlasCream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.maxWidth;
          _queueSync();
          final first = ((_offset - _padding - _width) / _step).floor().clamp(
            0,
            77,
          );
          final last = ((_offset + _viewport - _padding) / _step).ceil().clamp(
            0,
            77,
          );
          final start = math.max(0, first - 2), end = math.min(77, last + 2);
          return Listener(
            onPointerDown: (_) {
              _pointers++;
              _sync();
            },
            onPointerUp: (_) {
              _pointers = math.max(0, _pointers - 1);
              _sync();
            },
            onPointerCancel: (_) {
              _pointers = math.max(0, _pointers - 1);
              _sync();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (event) {
                if (event is ScrollStartNotification) {
                  _scrolling = true;
                  _sync();
                }
                if (event is ScrollEndNotification) {
                  _scrolling = false;
                  _sync();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: widget.controller,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _contentWidth,
                  height: 220,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Every aura is behind every card, including neighbouring cards.
                      for (final entry in _aura.targets.entries)
                        if (entry.key >= start && entry.key <= end)
                          _positioned(
                            entry.key,
                            IgnorePointer(
                              child: ExcludeSemantics(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([_wave, _fade]),
                                  builder: (context, _) => CustomPaint(
                                    key: ValueKey('tarot-aura-${entry.key}'),
                                    painter: _TarotDeckAuraPainter(
                                      _wave.value,
                                      entry.value * _fade.value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            key: ValueKey('tarot-aura-layer-${entry.key}'),
                          ),
                      for (var i = start; i <= end; i++)
                        _positioned(
                          i,
                          Builder(
                            builder: (cardContext) {
                              final used = widget.selected.contains(i);
                              void select() {
                                if (!used && !widget.locked) widget.onSelect(i);
                              }

                              return Semantics(
                                sortKey: OrdinalSortKey(i.toDouble()),
                                button: !used && !widget.locked,
                                label: used
                                    ? 'Seçildi'
                                    : 'Kapalı kart ${i + 1}, 78 karttan biri',
                                onTap: used || widget.locked ? null : select,
                                onDidGainAccessibilityFocus: () =>
                                    Scrollable.ensureVisible(
                                      cardContext,
                                      alignment: .5,
                                      duration: Duration.zero,
                                    ),
                                child: AbsorbPointer(
                                  absorbing: used || widget.locked,
                                  child: GestureDetector(
                                    key: ValueKey('tarot-deck-$i'),
                                    behavior: HitTestBehavior.opaque,
                                    excludeFromSemantics: true,
                                    onTap: used || widget.locked
                                        ? null
                                        : select,
                                    child: used
                                        ? const Center(
                                            child: Icon(
                                              Icons.check_circle_outline,
                                              color: _gold,
                                            ),
                                          )
                                        : const TarotCardView(showFront: false),
                                  ),
                                ),
                              );
                            },
                          ),
                          key: ValueKey('tarot-deck-item-$i'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _TarotDeckAuraPainter extends CustomPainter {
  const _TarotDeckAuraPainter(this.phase, this.intensity);
  final double phase, intensity;
  @override
  void paint(Canvas canvas, Size size) {
    final envelope = phase < .25
        ? phase / .25
        : phase < .53
        ? 1.0
        : (1 - phase) / .47;
    final strength = envelope.clamp(0.0, 1.0) * intensity;
    if (strength <= 0) return;
    final rect = (Offset.zero & size).inflate(16);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(3),
        const Radius.circular(12),
      ),
      Paint()
        ..color = const Color(0xffc9a05a).withValues(alpha: strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(4),
        const Radius.circular(12),
      ),
      Paint()
        ..color = const Color(0xffc9a05a).withValues(alpha: strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TarotDeckAuraPainter old) =>
      phase != old.phase || intensity != old.intensity;
}
