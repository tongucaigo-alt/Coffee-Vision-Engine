import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../atlas_design.dart';
import '../atlas_landing_layout.dart';
import 'tarot_models.dart';
import 'tarot_runtime.dart';

part 'tarot_presentation.dart';

const _gold = atlasCopper;
const _back = 'assets/tarot/KART_ARKASI.webp';
String _dateLabel(String iso) {
  final date = DateTime.parse(iso).toLocal();
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _historyDate(TarotDraw draw) =>
    draw.spread == TarotSpread.daily && draw.day != null
    ? draw.day!.split('-').reversed.join('.')
    : _dateLabel(draw.createdAt);

String _errorText(Object error) =>
    error is StateError || error is FormatException
    ? (error is StateError
          ? error.message.toString()
          : (error as FormatException).message)
    : 'İşlem tamamlanamadı. Kayıtların silinmedi; yeniden deneyebilirsin.';

class TarotHomePage extends StatefulWidget {
  const TarotHomePage({required this.runtime, super.key});
  final TarotRuntime runtime;
  @override
  State<TarotHomePage> createState() => _TarotHomePageState();
}

class _TarotHomePageState extends State<TarotHomePage> {
  List<TarotDraw>? _draws;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final draws = await widget.runtime.store.draws();
      if (mounted) {
        setState(() {
          _draws = draws;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  Future<void> _open(TarotSpread spread, {TarotDraw? draw}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next =
          draw ??
          await widget.runtime.store.start(spread, widget.runtime.catalog);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TarotDrawPage(
            runtime: widget.runtime,
            draw: next,
            shuffleOnOpen: draw == null && next.selected.isEmpty,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _draws
        ?.where(
          (d) =>
              d.spread == TarotSpread.three &&
              d.result.state != TarotResultState.completed,
        )
        .firstOrNull;
    return AtlasLandingLayout(
      scrollKey: const ValueKey('tarot-home-scroll'),
      frame: const CustomPaint(
        key: ValueKey('tarot-home-frame'),
        painter: _TarotHomeFramePainter(),
      ),
      content: Column(
        children: [
          const _TarotHomeCards(),
          const SizedBox(height: 16),
          const Text(
            'Kartların hikâyesi',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Literata', fontSize: 24, height: 1.3),
          ),
          const SizedBox(height: 8),
          const Text(
            'Geçmiş · Şimdi · Olası Yön',
            textAlign: TextAlign.center,
            style: TextStyle(color: atlasSageInk, height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kartlarını kendin seç.',
            textAlign: TextAlign.center,
            style: TextStyle(color: atlasMuted, height: 1.5),
          ),
          if (_draws == null && _error == null)
            const SizedBox(
              height: 16,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) ...[
            AtlasNotice(_error!),
            TextButton(
              onPressed: _load,
              child: const Text('Kayıtları Yeniden Oku'),
            ),
          ],
        ],
      ),
      secondary: TextButton.icon(
        key: const ValueKey('tarot-start-daily'),
        onPressed: _busy || _draws == null
            ? null
            : () => _open(TarotSpread.daily),
        icon: const Icon(Icons.wb_twilight_outlined),
        label: const Text('Günün Kartı'),
      ),
      primary: AtlasActionWidth(
        child: FilledButton.icon(
          key: const ValueKey('tarot-start-three'),
          onPressed: _busy || _draws == null
              ? null
              : () => _open(TarotSpread.three),
          style: AtlasLandingLayout.primaryStyle(),
          icon: const Icon(Icons.style_outlined),
          label: const Text('Üç Kart · Karıştır', textAlign: TextAlign.center),
        ),
      ),
      notice: true,
      resume: pending == null
          ? null
          : IconButton(
              key: const ValueKey('tarot-resume'),
              tooltip: 'Kaldığın yerden devam et',
              onPressed: _busy
                  ? null
                  : () => _open(pending.spread, draw: pending),
              style: IconButton.styleFrom(
                foregroundColor: atlasCoffee,
                minimumSize: const Size(48, 48),
              ),
              icon: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: atlasCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 22),
              ),
            ),
    );
  }
}

class TarotDrawPage extends StatefulWidget {
  const TarotDrawPage({
    required this.runtime,
    required this.draw,
    this.shuffleOnOpen = false,
    super.key,
  });
  final TarotRuntime runtime;
  final TarotDraw draw;
  final bool shuffleOnOpen;
  @override
  State<TarotDrawPage> createState() => _TarotDrawPageState();
}

class _TarotDrawPageState extends State<TarotDrawPage>
    with SingleTickerProviderStateMixin {
  late TarotDraw _draw;
  late final AnimationController _shuffle;
  final _scroll = ScrollController();
  bool _busy = false, _revealing = false, _reading = false;
  bool _moodSaving = false;
  String? _moodError;
  String? _error;
  bool get _locked =>
      _busy ||
      _revealing ||
      _shuffle.isAnimating ||
      widget.runtime.busy(_draw.id);
  @override
  void initState() {
    super.initState();
    _draw = widget.draw;
    _reading = _draw.result.state == TarotResultState.completed;
    _shuffle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shuffle.addStatusListener((_) {
      if (mounted) setState(() {});
    });
    widget.runtime.addListener(_reload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.shuffleOnOpen &&
          !MediaQuery.disableAnimationsOf(context)) {
        _shuffle.forward();
      }
    });
  }

  Future<void> _reload() async {
    try {
      final next = await widget.runtime.store.get(_draw.id);
      if (mounted && next != null) setState(() => _draw = next);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  @override
  void dispose() {
    widget.runtime.removeListener(_reload);
    unawaited(widget.runtime.cancel(_draw.id).catchError((Object _) {}));
    _shuffle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_locked) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _errorText(e);
          _revealing = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(int index) => _act(() async {
    final next = await widget.runtime.store.select(_draw.id, index);
    if (mounted) setState(() => _draw = next);
  });
  Future<void> _reveal(int position) => _act(() async {
    final next = await widget.runtime.store.reveal(_draw.id, position);
    if (mounted) {
      setState(() {
        _revealing = !MediaQuery.disableAnimationsOf(context);
        _draw = next;
      });
    }
  });
  Future<void> _reshuffle() => _act(() async {
    final next = await widget.runtime.store.reshuffle(
      _draw.id,
      widget.runtime.catalog,
    );
    if (mounted) {
      setState(() => _draw = next);
      if (!MediaQuery.disableAnimationsOf(context)) _shuffle.forward(from: 0);
    }
  });
  Future<void> _generate() => _act(() async {
    await widget.runtime.generate(_draw.id);
    await _reload();
    if (mounted && _draw.result.state == TarotResultState.completed) {
      setState(() => _reading = true);
    }
  });
  Future<void> _setMood(TarotMood mood) async {
    if (_moodSaving) return;
    final nextMood = _draw.mood == mood ? null : mood;
    setState(() {
      _moodSaving = true;
      _moodError = null;
    });
    try {
      await widget.runtime.store.setMood(_draw.id, nextMood);
      // Read the latest queued state rather than replacing a concurrent reveal.
      await _reload();
    } catch (_) {
      if (mounted) {
        setState(
          () => _moodError =
              'Seçimin kaydedilemedi. Kartlarını açmaya devam edebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _moodSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _draw.result.state == TarotResultState.completed;
    final generating = widget.runtime.busy(_draw.id);
    final selectedAll = _draw.selected.length == _draw.requiredCards;
    return Scaffold(
      appBar: AppBar(
        title: Text(_draw.title),
        actions: [
          if (complete)
            IconButton(
              tooltip: _draw.starred ? 'Yıldızı kaldır' : 'Yıldızla',
              onPressed: _locked
                  ? null
                  : () => _act(() async {
                      await widget.runtime.store.star(_draw.id, !_draw.starred);
                      await _reload();
                    }),
              icon: Icon(
                _draw.starred ? Icons.star : Icons.star_border,
                color: atlasSageInk,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    !selectedAll
                        ? 'Kapalı kartlardan ${_draw.requiredCards == 3 ? 'üçünü' : 'birini'} seç.'
                        : !_draw.ready
                        ? '${_draw.positions[_draw.revealed]} kartına dokunarak aç.'
                        : 'Kartlarının hikâyesi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 22,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _draw.spread == TarotSpread.daily
                        ? 'Günlük odağın · ${_draw.day ?? 'Kartını sen seç'}'
                        : 'Geçmiş · Şimdi · Olası Yön',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: atlasSageInk, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  _slots(compact: _reading && complete),
                  if (selectedAll && !_reading) ...[
                    const SizedBox(height: 4),
                    _TarotMoodPicker(
                      mood: _draw.mood,
                      saving: _moodSaving,
                      error: _moodError,
                      onSelect: _setMood,
                    ),
                  ] else if (_reading && _draw.mood != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ruh hâlin: ${_draw.mood!.label}',
                      key: const ValueKey('tarot-mood-summary'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: atlasSageInk, height: 1.5),
                    ),
                  ],
                  if (!selectedAll) ...[
                    const SizedBox(height: 18),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_draw.selected.length} / ${_draw.requiredCards} kart seçildi',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _deck(),
                    const Text(
                      'Desteyi yana kaydır · Dokunduğun kart korunur',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: atlasSageInk,
                        height: 1.5,
                      ),
                    ),
                    if (_draw.selected.isEmpty)
                      TextButton.icon(
                        onPressed: _locked ? null : _reshuffle,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Yeniden Karıştır'),
                      ),
                  ],
                  if (_draw.ready) ...[
                    SizedBox(height: _reading ? 22 : 8),
                    if (generating) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Flexible(child: Text('Kimi yorumunu hazırlıyor…')),
                        ],
                      ),
                      TextButton(
                        onPressed: () => widget.runtime.cancel(_draw.id),
                        child: const Text('Yorum İşlemini İptal Et'),
                      ),
                    ] else if (complete && !_reading)
                      AtlasPrimaryButton(
                        onPressed: _locked
                            ? null
                            : () => setState(() => _reading = true),
                        child: const Text('Yorumunu Oku'),
                      )
                    else if (!complete)
                      AtlasPrimaryButton(
                        key: const ValueKey('tarot-generate'),
                        onPressed: _locked ? null : _generate,
                        child: Text(
                          _draw.result.state == TarotResultState.idle
                              ? 'Yorumunu Oluştur'
                              : 'Yeniden Dene',
                        ),
                      ),
                    if (_reading && complete) ...[
                      Container(
                        key: const ValueKey('tarot-reading'),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: atlasCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: atlasBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Yorumun',
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontSize: 21,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _TarotReadingText(_draw.result.text!),
                          ],
                        ),
                      ),
                    ],
                    if (_draw.result.error != null) ...[
                      const SizedBox(height: 12),
                      AtlasNotice(_draw.result.error!),
                    ],
                    SizedBox(height: _reading ? 16 : 8),
                    const Text(
                      'Tarot eğlence ve öz değerlendirme içindir. Yorum bir düşünme davetidir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: atlasSageInk,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AtlasNotice(_error!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slots({bool compact = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final count = _draw.requiredCards;
      final width = ((constraints.maxWidth - 12 * (count - 1)) / count).clamp(
        0.0,
        compact ? (count == 1 ? 120.0 : 88.0) : (count == 1 ? 192.0 : 144.0),
      );
      if (count > 1 &&
          (MediaQuery.textScalerOf(context).scale(12) > 18 ||
              constraints.maxWidth < 320)) {
        return Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 96, child: _slotArtwork(i, count)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _draw.positions[i],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: atlasSageInk,
                            ),
                          ),
                          if (i < _draw.revealed) ...[
                            const SizedBox(height: 8),
                            Text(
                              _draw.chosen[i].card.name,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _TarotBadge(
                              _draw.chosen[i].reversed ? 'Ters' : 'Düz',
                              copper: _draw.chosen[i].reversed,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            SizedBox(
              width: width,
              child: Column(
                children: [
                  Text(
                    _draw.positions[i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: atlasSageInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _slotArtwork(i, count),
                  if (i < _draw.revealed) ...[
                    const SizedBox(height: 8),
                    Text(
                      _draw.chosen[i].card.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TarotBadge(
                      _draw.chosen[i].reversed ? 'Ters' : 'Düz',
                      copper: _draw.chosen[i].reversed,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
  Widget _slotArtwork(int i, int count) => AnimatedSwitcher(
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
    ),
    transitionBuilder: (child, animation) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: i >= _draw.selected.length
        ? AspectRatio(
            key: ValueKey('empty-$i'),
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: .6)),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: _gold,
                    fontFamily: 'Literata',
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          )
        : Semantics(
            key: ValueKey('chosen-$i'),
            button:
                _draw.revealed == i &&
                !_locked &&
                _draw.selected.length == count,
            label: i < _draw.revealed
                ? '${_draw.positions[i]}: ${_draw.chosen[i].card.name}, ${_draw.chosen[i].reversed ? 'ters' : 'düz'}'
                : '${_draw.positions[i]}, kapalı kart',
            child: GestureDetector(
              key: ValueKey('tarot-slot-$i'),
              onTap:
                  !_locked &&
                      _draw.revealed == i &&
                      _draw.selected.length == count
                  ? () => _reveal(i)
                  : null,
              child: TarotCardView(
                card: _draw.chosen[i],
                showFront: i < _draw.revealed,
                onFlipComplete: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _revealing = false);
                    }
                  });
                },
              ),
            ),
          ),
  );

  Widget _deck() => AnimatedBuilder(
    animation: _shuffle,
    builder: (context, child) => Transform.translate(
      offset: Offset(
        math.sin(_shuffle.value * math.pi * 6) * 14 * (1 - _shuffle.value),
        0,
      ),
      child: child,
    ),
    child: Container(
      height: 220,
      decoration: BoxDecoration(
        color: atlasSageSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) => ListView.builder(
          key: const ValueKey('tarot-deck'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: _draw.deck.length,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemBuilder: (context, index) {
            final used = _draw.selected.contains(index);
            final center =
                (_scroll.hasClients ? _scroll.offset : 0) / 100 + 1.5;
            final distance = (index - center).clamp(-3.0, 3.0);
            return SizedBox(
              width: 100,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, distance.abs() * 5),
                  child: Transform.rotate(
                    angle: distance * (math.pi / 90),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Semantics(
                        button: !used && !_locked,
                        label: used
                            ? 'Seçildi'
                            : 'Kapalı kart ${index + 1}, 78 karttan biri',
                        child: GestureDetector(
                          key: ValueKey('tarot-deck-$index'),
                          onTap: used || _locked ? null : () => _select(index),
                          child: used
                              ? const SizedBox(
                                  width: 96,
                                  height: 144,
                                  child: Center(
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      color: _gold,
                                    ),
                                  ),
                                )
                              : const TarotCardView(showFront: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Native finite flip. Reopening an already revealed card does not replay it.
class TarotCardView extends StatefulWidget {
  const TarotCardView({
    required this.showFront,
    this.card,
    this.onFlipComplete,
    super.key,
  });
  final bool showFront;
  final TarotDeckCard? card;
  final VoidCallback? onFlipComplete;
  @override
  State<TarotCardView> createState() => _TarotCardViewState();
}

class _TarotCardViewState extends State<TarotCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      value: widget.showFront ? 1 : 0,
      duration: const Duration(milliseconds: 600),
    );
    _flip.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFlipComplete?.call();
    });
  }

  @override
  void didUpdateWidget(TarotCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showFront != widget.showFront) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _flip.value = widget.showFront ? 1 : 0;
      } else if (widget.showFront) {
        _flip.forward();
      } else {
        _flip.reverse();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && _flip.isAnimating) {
      _flip.value = widget.showFront ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2 / 3,
    child: LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_flip.value);
          final front = t >= .5 && widget.card != null;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, .0018)
            ..rotateY(t * math.pi);
          Widget artwork = Image.asset(
            front ? 'assets/tarot/${widget.card!.card.image}' : _back,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            cacheWidth:
                (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 1024),
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.style_outlined, color: _gold)),
          );
          if (front) {
            artwork = Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: RotatedBox(
                quarterTurns: widget.card!.reversed ? 2 : 0,
                child: artwork,
              ),
            );
          }
          return CustomPaint(
            foregroundPainter: _TarotAuraPainter(
              _flip.isAnimating ? _flip.value : 0,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: Container(
                decoration: BoxDecoration(
                  color: front ? atlasCard : atlasCoffee,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _gold.withValues(alpha: .55)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1a4a342a),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: artwork,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _TarotAuraPainter extends CustomPainter {
  const _TarotAuraPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final strength = math.sin(progress * math.pi);
    final center = size.center(Offset.zero);
    final radius = size.width * .6;
    final paint = Paint()
      ..color = _gold.withValues(alpha: strength * .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 2; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 + i * 8,
          height: size.height * .9 + i * 8,
        ),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final angle = i * 2.39996 + progress * 1.5;
      canvas.drawCircle(
        center +
            Offset(
              math.cos(angle) * radius,
              math.sin(angle) * size.height * .48,
            ),
        i % 3 == 0 ? 1.8 : 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TarotAuraPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class TarotHistoryPage extends StatefulWidget {
  const TarotHistoryPage({
    required this.runtime,
    this.embedded = false,
    super.key,
  });
  final bool embedded;
  final TarotRuntime runtime;
  @override
  State<TarotHistoryPage> createState() => _TarotHistoryPageState();
}

class _TarotHistoryPageState extends State<TarotHistoryPage> {
  List<TarotDraw>? _draws;
  bool _starredOnly = false, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final draws = await widget.runtime.store.draws();
      if (mounted) {
        setState(() {
          _draws = draws;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  Future<void> _delete(TarotDraw draw) async {
    final today = draw.day == localTarotDay(widget.runtime.store.now());
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarot kaydını sil?'),
        content: Text(
          today
              ? 'Bu kayıt kalıcı silinir. Bugün yeni Günün Kartı seçilmez; yarın yeniden seçebilirsin.'
              : 'Bu tarot kaydı kalıcı silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.runtime.store.delete(draw.id);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _draws?.where((d) => !_starredOnly || d.starred).toList();
    final content = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: !_starredOnly,
                      onSelected: (_) => setState(() => _starredOnly = false),
                    ),
                    ChoiceChip(
                      label: Text(
                        'Yıldızlılar · ${_draws?.where((d) => d.starred).length ?? 0}/20',
                      ),
                      selected: _starredOnly,
                      onSelected: (_) => setState(() => _starredOnly = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tarot kayıtları bu telefonda saklanır. Silme senin kontrolünde.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  AtlasNotice(_error!),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Yeniden Oku'),
                  ),
                ],
                if (rows == null && _error == null)
                  const Center(child: CircularProgressIndicator()),
                if (rows?.isEmpty == true)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Burada henüz tarot kaydı yok.'),
                  ),
                for (final draw in rows ?? <TarotDraw>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${draw.title} · ${_historyDate(draw)}',
                                    style: const TextStyle(
                                      fontFamily: 'Literata',
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (draw.starred)
                                  const Icon(Icons.star, color: atlasSageInk),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < draw.chosen.length; i++)
                                  ExcludeSemantics(
                                    child: SizedBox(
                                      width: 40,
                                      child: TarotCardView(
                                        key: ValueKey(
                                          'tarot-history-${draw.id}-$i',
                                        ),
                                        card: draw.chosen[i],
                                        showFront: i < draw.revealed,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              draw.chosen.indexed
                                  .map(
                                    (entry) => entry.$1 < draw.revealed
                                        ? '${entry.$2.card.name} (${entry.$2.reversed ? 'Ters' : 'Düz'})'
                                        : 'Kapalı kart',
                                  )
                                  .join(' · '),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _TarotBadge(
                                _tarotStatus(draw),
                                copper:
                                    draw.result.state !=
                                    TarotResultState.completed,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => TarotDrawPage(
                                                runtime: widget.runtime,
                                                draw: draw,
                                              ),
                                            ),
                                          );
                                          await _load();
                                        },
                                  child: Text(
                                    draw.result.state ==
                                            TarotResultState.completed
                                        ? 'Yorumunu Oku'
                                        : 'Devam Et',
                                  ),
                                ),
                                if (draw.result.state ==
                                    TarotResultState.completed)
                                  IconButton(
                                    tooltip: draw.starred
                                        ? 'Yıldızı kaldır'
                                        : 'Yıldızla',
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            setState(() => _busy = true);
                                            try {
                                              await widget.runtime.store.star(
                                                draw.id,
                                                !draw.starred,
                                              );
                                              await _load();
                                            } catch (e) {
                                              if (mounted) {
                                                setState(
                                                  () => _error = _errorText(e),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() => _busy = false);
                                              }
                                            }
                                          },
                                    icon: Icon(
                                      draw.starred
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: atlasSageInk,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Kaydı sil',
                                  onPressed:
                                      _busy || widget.runtime.busy(draw.id)
                                      ? null
                                      : () => _delete(draw),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Tarot Geçmişi')),
            body: content,
          );
  }
}
