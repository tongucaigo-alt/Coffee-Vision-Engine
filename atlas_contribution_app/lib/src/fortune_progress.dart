import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'cropped_photo.dart';
import 'photo_crop.dart';

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
    super.key,
  });
  final FortuneProgress progress;
  final List<ContributionPhoto> photos;
  final ImageProvider Function(ContributionPhoto) imageFor;
  final VoidCallback? onCancel;
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
  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((s) {
      if (s == AnimationStatus.completed && _animate) {
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
      _animation.forward();
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        if (photo != null)
          Stack(
            alignment: Alignment.center,
            children: [
              _ScanPhoto(photo: photo, image: widget.imageFor(photo)),
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

class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto({required this.photo, required this.image});
  final ContributionPhoto photo;
  final ImageProvider image;
  @override
  Widget build(BuildContext context) {
    final proposed = photo.displayCrop ?? PhotoCrop.full;
    final crop = photo.regions.every((r) => proposed.containsBox(r.box))
        ? proposed
        : PhotoCrop.full;
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
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        3,
        Paint()
          ..color = const Color(
            0xff4A7C59,
          ).withValues(alpha: .25 + .65 * i / 12),
      );
    }
  }

  @override
  bool shouldRepaint(_ScanDots oldDelegate) => phase != oldDelegate.phase;
}
