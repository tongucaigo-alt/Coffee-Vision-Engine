import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'models.dart';
import 'cropped_photo.dart';
import 'photo_crop.dart';
import 'opencv_traces.dart';
import 'trace_overlay.dart';
import 'trace_symbols.dart';
import 'label_picker.dart' show labelIcons;
import 'coffee_loading_animation.dart';
import 'atlas_atmosphere.dart';

enum FortunePhase {
  saving,
  analyzing,
  highlighting,
  queued,
  generating,
  repairing,
  completed,
  failed,
  cancelled,
}

class FortuneProgress {
  const FortuneProgress(this.phase, {this.photoId});
  final FortunePhase phase;
  final String? photoId;
  String get message => switch (phase) {
    FortunePhase.saving => 'Gözlemlerin kaydediliyor',
    FortunePhase.analyzing => 'Telve dağılımı inceleniyor',
    FortunePhase.highlighting => 'Telve izleri belirginleştiriliyor',
    FortunePhase.queued => 'Fincanının hikâyesi sırada',
    FortunePhase.generating => 'Fincanının hikâyesi hazırlanıyor',
    FortunePhase.repairing => 'Hikâyen gözden geçiriliyor',
    FortunePhase.completed => 'Falın hazır',
    FortunePhase.failed => 'İşlem tamamlanamadı; kaydın korunuyor',
    FortunePhase.cancelled => 'İşlem durduruldu; kaydın korunuyor',
  };
}

class FortuneScan extends StatefulWidget {
  const FortuneScan({
    required this.progress,
    required this.photos,
    required this.imageFor,
    this.onCancel,
    this.showDecorativeSymbols = false,
    this.symbolAnchorsFor,
    this.traces,
    this.noTracesMessage = false,
    super.key,
  });
  final TraceSet? traces;
  final bool noTracesMessage;
  final FortuneProgress progress;
  final List<ContributionPhoto> photos;
  final ImageProvider Function(ContributionPhoto) imageFor;
  final VoidCallback? onCancel;

  /// Decorative only; enable exclusively on the fortune preparation screen.
  final bool showDecorativeSymbols;

  /// Legacy presentation hint retained for callers; placement uses TraceSet.
  final List<Offset> Function(ContributionPhoto)? symbolAnchorsFor;
  @override
  State<FortuneScan> createState() => _FortuneScanState();
}

class _FortuneScanState extends State<FortuneScan>
    with TickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _reduce = false;
  bool get _animate =>
      !_reduce &&
      ![
        FortunePhase.completed,
        FortunePhase.failed,
        FortunePhase.cancelled,
      ].contains(widget.progress.phase);
  @override
  void didUpdateWidget(covariant FortuneScan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animate) {
      if (!_animation.isAnimating) _animation.forward();
    } else {
      _animation.stop();
    }
  }

  int _photo = 0;
  int _symbolCycle = 0;
  final int _symbolSeed = math.Random().nextInt(1 << 30);
  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((s) {
      if (s == AnimationStatus.completed && _animate) {
        _symbolCycle++;
        if (widget.progress.phase != FortunePhase.analyzing &&
            widget.progress.phase != FortunePhase.highlighting &&
            mounted) {
          setState(() => _photo++);
        }
        _animation.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (!_animate) {
      _animation.stop();
    } else {
      if (!_animation.isAnimating) _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final photo = photos.isEmpty
        ? null
        : photos.firstWhere(
            (p) =>
                p.id == widget.progress.photoId ||
                p.localName == widget.progress.photoId,
            orElse: () => photos[_photo % photos.length],
          );
    final localTraces = photo == null || widget.traces == null
        ? const <TraceCandidate>[]
        : widget.traces!.selected
              .where((t) => t.photoIndex == widget.traces!.indexOf(photo))
              .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        if (widget.noTracesMessage)
          const Text(
            'Bu fotoğraflarda belirgin telve izi çıkarılamadı. Hikâyen mevcut bilgilerle hazırlanıyor.',
            textAlign: TextAlign.center,
          ),
        if (photo != null)
          Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: AtlasAtmosphereRegion(
                  kind: AtlasAtmosphereRegionKind.protected,
                  child: _ScanPhoto(
                    photo: photo,
                    image: widget.imageFor(photo),
                    traces: widget.traces,
                  ),
                ),
              ),
              if (_animate &&
                  widget.showDecorativeSymbols &&
                  localTraces.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (_, _) => _FortuneSymbols(
                          phase: _animation.value,
                          cycle: _symbolCycle,
                          seed: _symbolSeed,
                          crop: _scanCrop(photo),
                          traces: localTraces,
                          photoIdentity: tracePhotoIdentity(photo),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Center(
          key: const ValueKey('fortune-loading-area'),
          child: AtlasAtmosphereRegion(
            kind: AtlasAtmosphereRegionKind.steam,
            child: CoffeeLoadingAnimation(
              key: const ValueKey('fortune-coffee-loading'),
              active: _animate,
              reducedMotion: _reduce,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            widget.progress.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onCancel != null)
          TextButton(onPressed: widget.onCancel, child: const Text('Durdur')),
      ],
    );
  }
}

PhotoCrop _scanCrop(ContributionPhoto photo) {
  final proposed = photo.displayCrop ?? PhotoCrop.full;
  return photo.regions.every((r) => proposed.containsBox(r.box))
      ? proposed
      : PhotoCrop.full;
}

class _FortuneSymbols extends StatefulWidget {
  const _FortuneSymbols({
    required this.phase,
    required this.cycle,
    required this.seed,
    required this.crop,
    required this.traces,
    required this.photoIdentity,
  });
  final double phase;
  final int cycle, seed;
  final PhotoCrop crop;
  final List<TraceCandidate> traces;
  final String photoIdentity;
  @override
  State<_FortuneSymbols> createState() => _FortuneSymbolsState();
}

class _FortuneSymbolsState extends State<_FortuneSymbols> {
  late final _labels = <String>[
    'fish',
    'heart',
    'eye',
    'bird',
    'moon',
    'sun',
    'tree',
    'flower',
    'crown',
    'anchor',
  ]..shuffle(math.Random(widget.seed));
  Size? _size;
  PhotoCrop? _crop;
  String? _photoIdentity;
  List<TraceCandidate> _traces = const [];
  List<TraceSymbolAnchor> _anchors = const [];
  final _slots = List<TraceSymbolAnchor?>.filled(3, null);
  final _generations = List<int>.filled(3, -1);
  final _rounds = <String, int>{};
  final _lastCycles = <String, int>{};

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, bounds) {
      final size = Size(bounds.maxWidth, bounds.maxHeight);
      // Photo count must not lock six anchors into the same group of three.
      if (_lastCycles[widget.photoIdentity] != widget.cycle) {
        _rounds[widget.photoIdentity] =
            (_rounds[widget.photoIdentity] ?? -1) + 1;
        _lastCycles[widget.photoIdentity] = widget.cycle;
      }
      if (_size != size ||
          _crop != widget.crop ||
          _photoIdentity != widget.photoIdentity ||
          !listEquals(_traces, widget.traces)) {
        _size = size;
        _crop = widget.crop;
        _photoIdentity = widget.photoIdentity;
        _traces = List.of(widget.traces);
        _anchors = traceSymbolAnchors(_traces, widget.crop, size);
        for (var i = 0; i < 3; i++) {
          _slots[i] = null;
          _generations[i] = -1;
        }
      }
      final breaths = <double>[];
      for (var i = 0; i < 3; i++) {
        final elapsed = widget.cycle + widget.phase + .12 - i * .09;
        final generation = math.max(0, elapsed.floor());
        final localPhase = elapsed < 0 ? 0.0 : elapsed - elapsed.floor();
        breaths.add(elapsed < 0 ? 0 : math.sin(localPhase * math.pi));
        if (_generations[i] == generation) continue;
        _generations[i] = generation;
        _slots[i] = null;
        final round =
            _rounds[widget.photoIdentity]! + generation - widget.cycle;
        for (var offset = 0; offset < _anchors.length; offset++) {
          final anchor = _anchors[(round + i + offset) % _anchors.length];
          if (_slots.indexed.every(
            (slot) =>
                slot.$1 == i ||
                slot.$2 == null ||
                (slot.$2!.traceIndex != anchor.traceIndex &&
                    (slot.$2!.position - anchor.position).distance >=
                        traceSymbolGap),
          )) {
            _slots[i] = anchor;
            break;
          }
        }
      }
      return ClipPath(
        clipper: TraceSymbolClipper(_traces.first, widget.crop),
        child: Stack(
          key: const ValueKey('fortune-decorative-symbols'),
          children: [
            for (var i = 0; i < 3; i++)
              if (_slots[i] case final anchor?)
                Positioned(
                  left: anchor.position.dx - traceSymbolIconSize / 2,
                  top: anchor.position.dy - traceSymbolIconSize / 2,
                  child: Opacity(
                    opacity: math.min(1.0, breaths[i] * 3),
                    child: Transform.scale(
                      scale: .82 + .38 * breaths[i],
                      child: Icon(
                        labelIcons[_labels[(_generations[i] * 3 + i) %
                            _labels.length]],
                        key: ValueKey('fortune-symbol-$i'),
                        size: traceSymbolIconSize,
                        color: traceSymbolColorFor(anchor.traceIndex),
                        shadows: [
                          Shadow(
                            color: traceSymbolColorFor(
                              anchor.traceIndex,
                            ).withValues(alpha: .50),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto({required this.photo, required this.image, this.traces});
  final TraceSet? traces;
  final ContributionPhoto photo;
  final ImageProvider image;
  @override
  Widget build(BuildContext context) {
    final crop = _scanCrop(photo);
    return Semantics(
      label: photo.title,
      image: true,
      child: AspectRatio(
        aspectRatio: crop.aspectRatio(photo.width, photo.height),
        child: LayoutBuilder(
          builder: (_, size) => ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CroppedPhoto(
                    image: image,
                    photoWidth: photo.width,
                    photoHeight: photo.height,
                    crop: crop,
                  ),
                ),
                if (traces != null)
                  Positioned.fill(
                    child: TraceOverlay(set: traces!, photo: photo, crop: crop),
                  ),
                for (final r in photo.regions)
                  Positioned(
                    left: crop.toDisplayBox(r.box).x * size.maxWidth,
                    top: crop.toDisplayBox(r.box).y * size.maxHeight,
                    width: crop.toDisplayBox(r.box).width * size.maxWidth,
                    height: crop.toDisplayBox(r.box).height * size.maxHeight,
                    child: Semantics(
                      label: r.title,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xff4A7C59),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xff4A7C59).withValues(alpha: .12),
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
  }
}
