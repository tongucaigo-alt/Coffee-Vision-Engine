import 'atlas_atmosphere.dart';
import 'package:flutter/material.dart';
import 'atlas_design.dart';
import 'coffee_loading_animation.dart';
import 'fortune_progress.dart';
import 'models.dart';
import 'opencv_traces.dart';

/// One presentation owner across the save route and the AI route.
/// Contains no persisted data and never starts an AI request itself.
class FortunePreparationController extends ChangeNotifier {
  FortunePreparationController(this.progress) {
    progress.addListener(_trackPhase);
  }
  final ValueNotifier<FortuneProgress> progress;
  final Stopwatch _clock = Stopwatch();
  final Map<String, int> _durations = {};
  String _phase = 'saving';
  int _phaseStart = 0;
  void _trackPhase() {
    if (!active) return;
    final elapsed = _clock.elapsedMilliseconds;
    _durations[_phase] = (_durations[_phase] ?? 0) + elapsed - _phaseStart;
    _phaseStart = elapsed;
    _phase = progress.value.phase.name;
  }

  Map<String, int> get stageDurations {
    _trackPhase();
    return Map.of(_durations);
  }

  @override
  void dispose() {
    progress.removeListener(_trackPhase);
    _clock.stop();
    super.dispose();
  }

  bool attached = false, active = false, cancelled = false;
  List<ContributionPhoto> photos = const [];
  TraceSet traces = TraceSet.empty;
  bool _markedOnly = false, _tracesComplete = false, _displayAllowed = true;
  final Set<String> _readyImages = {};
  int _epoch = 0;
  int get epoch => _epoch;
  List<ContributionPhoto> get displayPhotos => !_markedOnly
      ? photos
      : photos
            .where(
              (p) =>
                  _readyImages.contains(tracePhotoIdentity(p)) &&
                  traces.selected.any((t) => t.photoIndex == traces.indexOf(p)),
            )
            .toList();
  bool get readyToShow =>
      !_markedOnly ||
      (_displayAllowed &&
          (displayPhotos.isNotEmpty ||
              (_tracesComplete && traces.selected.isEmpty)));
  void permitDisplay() {
    if (!active || cancelled) return;
    _displayAllowed = true;
    notifyListeners();
  }

  void imageReady(ContributionPhoto photo) {
    if (!active ||
        cancelled ||
        !photos.any(
          (p) => tracePhotoIdentity(p) == tracePhotoIdentity(photo),
        )) {
      return;
    }
    _readyImages.add(tracePhotoIdentity(photo));
    notifyListeners();
  }

  void updateTraces(TraceSet value, {bool complete = false, int? epoch}) {
    if (!active || cancelled) return;
    if (epoch != null && epoch != _epoch) return;
    if (value.photos.any(
      (p) => !photos.any((q) => tracePhotoIdentity(p) == tracePhotoIdentity(q)),
    )) {
      return;
    }
    // Reloading the same calibrated cache must not erase already visible aids
    // at the save-to-AI handoff while the next photo is being announced.
    if (!complete && traces.selected.isNotEmpty) {
      final merged = <TraceCandidate>[];
      for (var index = 0; index < value.photos.length; index++) {
        final current = value.selected
            .where((t) => t.photoIndex == index)
            .toList();
        if (current.isNotEmpty) {
          merged.addAll(current);
        } else {
          final oldIndex = traces.indexOf(value.photos[index]);
          merged.addAll(
            traces.selected
                .where((t) => t.photoIndex == oldIndex)
                .map((t) => TraceCandidate(index, t.result, t.data, t.area)),
          );
        }
      }
      traces = TraceSet(value.photos, merged, failures: value.failures);
    } else {
      traces = value;
    }
    _tracesComplete = complete;
    notifyListeners();
  }

  ImageProvider Function(ContributionPhoto)? imageFor;
  List<Offset> Function(ContributionPhoto)? anchorsFor;
  VoidCallback? onCancel;
  Map<String, ImageProvider> _images = {};
  String _imageKey(ContributionPhoto p) => '${p.fileKey}|${p.checksum}';

  void begin({
    required List<ContributionPhoto> photos,
    required ImageProvider Function(ContributionPhoto) imageFor,
    required VoidCallback onCancel,
    List<Offset> Function(ContributionPhoto)? anchorsFor,
    bool requireMarkedPhotos = false,
  }) {
    final samePhotos =
        this.photos.length == photos.length &&
        this.photos.every(
          (p) =>
              photos.any((q) => tracePhotoIdentity(p) == tracePhotoIdentity(q)),
        );
    if (!active || !samePhotos) _epoch++;
    if (active && !samePhotos) {
      traces = TraceSet.empty;
      _readyImages.clear();
      _tracesComplete = false;
      _displayAllowed = !requireMarkedPhotos;
    }
    if (!active) {
      _clock
        ..reset()
        ..start();
      _durations.clear();
      _phaseStart = 0;
      _phase = progress.value.phase.name;
      cancelled = false;
      _images = {};
      traces = TraceSet.empty;
      _tracesComplete = false;
      _displayAllowed = !requireMarkedPhotos;
      _readyImages.clear();
    }
    // Linked review copies have different file paths. Retain the initial image
    // providers so the save-to-AI handoff does not reload the same photograph.
    _images = {
      for (final photo in photos)
        _imageKey(photo): _images[_imageKey(photo)] ?? imageFor(photo),
    };
    _markedOnly = requireMarkedPhotos;
    active = true;
    this.photos = List.unmodifiable(photos);
    this.imageFor = (photo) => _images[_imageKey(photo)]!;
    this.anchorsFor = anchorsFor;
    this.onCancel = onCancel;
    notifyListeners();
  }

  void cancel() {
    if (!active || cancelled) return;
    cancelled = true;
    progress.value = const FortuneProgress(FortunePhase.cancelled);
    onCancel?.call();
    notifyListeners();
  }

  void finish() {
    if (!active) return;
    _epoch++;
    _trackPhase();
    _clock.stop();
    active = false;
    cancelled = false;
    onCancel = null;
    anchorsFor = null;
    traces = TraceSet.empty;
    photos = const [];
    imageFor = null;
    _images = {};
    notifyListeners();
  }
}

/// Placed above the Navigator, so route changes cannot recreate the animation.
class FortunePreparationHost extends StatefulWidget {
  const FortunePreparationHost({
    required this.controller,
    required this.child,
    super.key,
  });
  final FortunePreparationController controller;
  final Widget child;
  @override
  State<FortunePreparationHost> createState() => _FortunePreparationHostState();
}

class _FortunePreparationHostState extends State<FortunePreparationHost> {
  final Set<String> _decoding = {};
  void _warmImages(FortunePreparationController flow) {
    for (final p in flow.photos) {
      final id = tracePhotoIdentity(p);
      if (!flow.traces.selected.any(
            (t) => t.photoIndex == flow.traces.indexOf(p),
          ) ||
          flow._readyImages.contains(id) ||
          !_decoding.add(id)) {
        continue;
      }
      final provider = flow.imageFor!(p);
      precacheImage(provider, context).then((_) {
        _decoding.remove(id);
        if (mounted) flow.imageReady(p);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.attached = true;
  }

  @override
  void dispose() {
    widget.controller.attached = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final flow = widget.controller;
      if (flow.active) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && flow.active && !flow.cancelled) _warmImages(flow);
        });
      }
      final showing = flow.active;
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: showing,
            child: IgnorePointer(
              ignoring: showing,
              child: TickerMode(enabled: !showing, child: widget.child),
            ),
          ),
          if (showing)
            if (!flow.readyToShow)
              Scaffold(
                key: const ValueKey('fortune-waiting-host'),
                backgroundColor: atlasCream,
                body: ValueListenableBuilder<FortuneProgress>(
                  valueListenable: flow.progress,
                  builder: (_, progress, _) => _FortuneWaiting(
                    progress: flow.cancelled
                        ? const FortuneProgress(FortunePhase.cancelled)
                        : progress,
                  ),
                ),
              )
            else
              AtlasAtmosphereSurface(
                scene: AtlasAtmosphereScene.coffeePreparation,
                active: !flow.cancelled,
                child: Scaffold(
                  key: const ValueKey('fortune-preparation-host'),
                  appBar: AppBar(
                    automaticallyImplyLeading: false,
                    title: const Text('Fincanının Hikâyesi'),
                  ),
                  body: ValueListenableBuilder<FortuneProgress>(
                    valueListenable: flow.progress,
                    builder: (_, progress, _) => FortuneScan(
                      key: const ValueKey('continuous-fortune-scan'),
                      progress: flow.cancelled
                          ? const FortuneProgress(FortunePhase.cancelled)
                          : progress,
                      photos: flow.displayPhotos,
                      traces: flow.traces,
                      noTracesMessage:
                          flow._markedOnly &&
                          flow._tracesComplete &&
                          flow.traces.selected.isEmpty,
                      imageFor: flow.imageFor!,
                      symbolAnchorsFor: flow.anchorsFor,
                      showDecorativeSymbols: true,
                      onCancel: flow.cancelled ? null : flow.cancel,
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

/// The preparation host already blocks the review route; its PopScope remains
/// the cancellation owner while local traces and images become ready.
class _FortuneWaiting extends StatelessWidget {
  const _FortuneWaiting({required this.progress});
  final FortuneProgress progress;

  @override
  Widget build(BuildContext context) {
    final terminal = switch (progress.phase) {
      FortunePhase.cancelled ||
      FortunePhase.failed ||
      FortunePhase.completed => true,
      _ => false,
    };
    final message = terminal
        ? progress.message
        : progress.phase == FortunePhase.saving
        ? 'Sıraya alınıyor…'
        : 'Hazırlanıyor…';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth * .52)
                .clamp(160.0, 220.0)
                .clamp(0.0, constraints.maxHeight * .4);
            return Center(
              child: Column(
                key: const ValueKey('fortune-waiting-group'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoffeeLoadingAnimation(
                    key: const ValueKey('fortune-waiting-animation'),
                    active: !terminal,
                    reducedMotion: MediaQuery.disableAnimationsOf(context),
                    size: size,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      key: const ValueKey('fortune-waiting-status'),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: atlasInk),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
