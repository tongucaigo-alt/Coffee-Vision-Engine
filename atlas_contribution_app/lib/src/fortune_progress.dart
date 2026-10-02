import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'models.dart';
import 'cropped_photo.dart';
import 'photo_crop.dart';
import 'label_picker.dart' show labelIcons;

enum FortunePhase {
  saving,
  analyzing,
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
    super.key,
  });
  final FortuneProgress progress;
  final List<ContributionPhoto> photos;
  final ImageProvider Function(ContributionPhoto) imageFor;
  final VoidCallback? onCancel;

  /// Decorative only; enable exclusively on the fortune preparation screen.
  final bool showDecorativeSymbols;

  /// Residue centres in normalized original-photo coordinates, never labels.
  final List<Offset> Function(ContributionPhoto)? symbolAnchorsFor;
  @override
  State<FortuneScan> createState() => _FortuneScanState();
}

class _FortuneScanState extends State<FortuneScan>
    with SingleTickerProviderStateMixin {
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
        if (widget.progress.phase != FortunePhase.analyzing && mounted) {
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
    final anchors = photo == null
        ? const <Offset>[]
        : widget.symbolAnchorsFor?.call(photo) ?? const <Offset>[];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        if (photo != null)
          Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: _ScanPhoto(photo: photo, image: widget.imageFor(photo)),
              ),
              if (_animate &&
                  widget.showDecorativeSymbols &&
                  photo.surface == PhotoSurface.cup)
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
                          anchors: anchors,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_animate)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, _) =>
                          CustomPaint(painter: _ScanDots(_animation.value)),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 28),
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
    required this.anchors,
  });
  final double phase;
  final int cycle;
  final int seed;
  final PhotoCrop crop;
  final List<Offset> anchors;

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
  List<Offset> _anchors = const [];
  final _positions = <Offset>[];
  final _generations = <int>[];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, bounds) {
      const iconSize = 22.0;
      const displayIconSize = iconSize * .75;
      final centre = Offset(bounds.maxWidth / 2, bounds.maxHeight / 2);
      final radius = math.max(
        0.0,
        math.min(bounds.maxWidth, bounds.maxHeight) * .36 - 22,
      );
      final size = Size(bounds.maxWidth, bounds.maxHeight);
      if (_size != size ||
          _crop != widget.crop ||
          !listEquals(_anchors, widget.anchors)) {
        _size = size;
        _crop = widget.crop;
        _anchors = List.of(widget.anchors);
        _positions.clear();
        _generations.clear();
      }
      final crop = widget.crop;
      final residue = <Offset>[];
      for (final anchor in widget.anchors) {
        if (!anchor.dx.isFinite ||
            !anchor.dy.isFinite ||
            anchor.dx < 0 ||
            anchor.dx > 1 ||
            anchor.dy < 0 ||
            anchor.dy > 1) {
          continue;
        }
        final point = Offset(
          (anchor.dx - crop.x) / crop.width * bounds.maxWidth,
          (anchor.dy - crop.y) / crop.height * bounds.maxHeight,
        );
        if (point.dx >= iconSize &&
            point.dy >= iconSize &&
            point.dx <= bounds.maxWidth - iconSize &&
            point.dy <= bounds.maxHeight - iconSize) {
          residue.add(point);
        }
        if (residue.length == 3) break;
      }
      final breaths = <double>[];
      for (var i = 0; i < 3; i++) {
        // Start the first symbol visibly, then introduce the others promptly.
        final elapsed = widget.cycle + widget.phase + .12 - i * .09;
        final generation = math.max(0, elapsed.floor());
        final localPhase = elapsed < 0 ? 0.0 : elapsed - elapsed.floor();
        breaths.add(elapsed < 0 ? 0 : math.sin(localPhase * math.pi));
        // Keep each position fixed through its breath; choose a new one only
        // while that symbol is invisible at the beginning of its next breath.
        if (i < _generations.length && _generations[i] == generation) continue;
        final random = math.Random(widget.seed + generation * 997 + i * 7919);
        var point = centre;
        for (var attempt = 0; attempt < 24; attempt++) {
          final angle = random.nextDouble() * math.pi * 2;
          final distance = radius * math.sqrt(.12 + random.nextDouble() * .88);
          point = centre + Offset(math.cos(angle), math.sin(angle)) * distance;
          if (residue.isNotEmpty && attempt < 12) {
            final anchor = residue[random.nextInt(residue.length)];
            point = Offset.lerp(anchor, point, .45)!;
            final delta = point - centre;
            if (delta.distance > radius && delta.distance > 0) {
              point = centre + delta / delta.distance * radius;
            }
          }
          if (_positions.indexed.every(
            (other) =>
                other.$1 == i || (other.$2 - point).distance >= iconSize * 1.8,
          )) {
            break;
          }
        }
        if (i < _positions.length) {
          _positions[i] = point;
          _generations[i] = generation;
        } else {
          _positions.add(point);
          _generations.add(generation);
        }
      }
      return Stack(
        key: const ValueKey('fortune-decorative-symbols'),
        children: [
          for (var i = 0; i < _positions.length; i++)
            Positioned(
              left: _positions[i].dx - displayIconSize / 2,
              top: _positions[i].dy - displayIconSize / 2,
              child: Opacity(
                opacity: math.min(1.0, breaths[i] * 3),
                child: Transform.scale(
                  scale: .82 + .38 * breaths[i],
                  child: Icon(
                    labelIcons[_labels[(_generations[i] * 3 + i) %
                        _labels.length]],
                    key: ValueKey('fortune-symbol-$i'),
                    size: displayIconSize,
                    color: const Color(0xff7CE59C),
                    shadows: const [
                      Shadow(color: Color(0xcc143b23), blurRadius: 4),
                      Shadow(color: Color(0x803dbf6e), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto({required this.photo, required this.image});
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

class _ScanDots extends CustomPainter {
  _ScanDots(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .36;
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12 + phase) * math.pi * 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = const Color(0x505de28c)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        point,
        4.2,
        Paint()
          ..color = const Color(
            0xff68D990,
          ).withValues(alpha: .65 + .35 * i / 12),
      );
    }
  }

  @override
  bool shouldRepaint(_ScanDots oldDelegate) => phase != oldDelegate.phase;
}
