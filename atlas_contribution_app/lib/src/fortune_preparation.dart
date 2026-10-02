import 'package:flutter/material.dart';
import 'fortune_progress.dart';
import 'models.dart';

/// One presentation owner across the save route and the AI route.
/// Contains no persisted data and never starts an AI request itself.
class FortunePreparationController extends ChangeNotifier {
  FortunePreparationController(this.progress);
  final ValueNotifier<FortuneProgress> progress;
  bool attached = false, active = false, cancelled = false;
  List<ContributionPhoto> photos = const [];
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
  }) {
    if (!active) {
      cancelled = false;
      _images = {};
    }
    // Linked review copies have different file paths. Retain the initial image
    // providers so the save-to-AI handoff does not reload the same photograph.
    _images = {
      for (final photo in photos)
        _imageKey(photo): _images[_imageKey(photo)] ?? imageFor(photo),
    };
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
    active = false;
    cancelled = false;
    onCancel = null;
    anchorsFor = null;
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
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: flow.active,
            child: IgnorePointer(ignoring: flow.active, child: widget.child),
          ),
          if (flow.active)
            Scaffold(
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
                  photos: flow.photos,
                  imageFor: flow.imageFor!,
                  symbolAnchorsFor: flow.anchorsFor,
                  showDecorativeSymbols: true,
                  onCancel: flow.cancelled ? null : flow.cancel,
                ),
              ),
            ),
        ],
      );
    },
  );
}
