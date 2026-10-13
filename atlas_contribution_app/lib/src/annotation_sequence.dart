import 'package:flutter/material.dart';
import 'annotation_page.dart';
import 'photo_navigation.dart';
import 'atlas_design.dart';
import 'models.dart';
import 'theme.dart';
import 'opencv_traces.dart';

class AnnotationSequence extends StatefulWidget {
  const AnnotationSequence({
    required this.photos,
    required this.imageFor,
    required this.onSave,
    this.loadTraces,
    this.onTraceShown,
    super.key,
  });
  final Future<TraceSet> Function()? loadTraces;
  final Future<void> Function(ContributionPhoto)? onTraceShown;
  final List<ContributionPhoto> photos;
  final ImageProvider Function(ContributionPhoto) imageFor;
  final Future<void> Function(ContributionPhoto) onSave;
  @override
  State<AnnotationSequence> createState() => _AnnotationSequenceState();
}

class _AnnotationSequenceState extends State<AnnotationSequence> {
  late final _photos = List<ContributionPhoto>.of(widget.photos);
  int _index = 0;
  bool _busy = false;
  TraceSet _traces = TraceSet.empty;
  final _exposed = <String>{};
  bool _loadingTraces = false;

  @override
  void initState() {
    super.initState();
    if (widget.loadTraces != null) _loadTraces();
  }

  Future<void> _loadTraces() async {
    _loadingTraces = true;
    try {
      final traces = await widget.loadTraces!();
      if (!mounted) return;
      _traces = traces;
      await _exposeCurrent();
    } catch (_) {
      // Optional visual aid; normal annotation remains available on failure.
    } finally {
      if (mounted) setState(() => _loadingTraces = false);
    }
  }

  Future<void> _exposeCurrent() async {
    final photo = _photos[_index];
    final index = _traces.indexOf(photo);
    if (!_traces.selected.any((trace) => trace.photoIndex == index) ||
        _exposed.contains(tracePhotoIdentity(photo))) {
      return;
    }
    try {
      // Persist provenance before the overlay becomes visible. Failure keeps
      // the clean photo available rather than creating an unaudited exposure.
      await widget.onTraceShown?.call(photo);
      if (!mounted) return;
      setState(() => _exposed.add(tracePhotoIdentity(photo)));
    } catch (_) {
      // Existing observations and gestures are unaffected by audit failure.
    }
  }

  void _select(int index) {
    setState(() => _index = index);
    _exposeCurrent();
  }

  Future<void> _save(ContributionPhoto p) async {
    setState(() => _busy = true);
    try {
      await widget.onSave(p);
      _photos[_photos.indexWhere((v) => v.localName == p.localName)] = p;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (_index < _photos.length - 1) {
      _select(_index + 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _skipRemaining({bool? generate}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (p.decision != PhotoDecision.unreviewed) continue;
        final next = p.annotated(
          p.regions,
          p.regions.isEmpty ? PhotoDecision.skipped : PhotoDecision.marked,
        );
        await widget.onSave(next);
        _photos[i] = next;
      }
      if (mounted) Navigator.pop(context, generate);
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Gözlemler kaydedilemedi. Kaydedilen işaretler korunuyor; tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photos[_index];
    return PopScope(
      canPop: !_busy,
      child: Theme(
        data: coffeeFlowTheme(Theme.of(context)),
        child: AnnotationPage(
          key: ValueKey(photo.localName),
          photo: photo,
          image: widget.imageFor(photo),
          displayCrop: photo.visibleCrop,
          traces: _exposed.contains(tracePhotoIdentity(photo)) ? _traces : null,
          onSave: _save,
          onComplete: _next,
          modern: true,
          onFinish: _busy ? null : () => _skipRemaining(generate: true),
          onSaveOnly: _busy ? null : () => _skipRemaining(generate: false),
          onSkip: _busy ? null : () => _skipRemaining(),
          completionLabel: _index == _photos.length - 1
              ? 'Tamamla'
              : 'Sonraki Fotoğraf',
          navigation: Stack(
            fit: StackFit.expand,
            children: [
              PhotoNavigation(
                index: _index,
                count: _photos.length,
                onSelect: _busy ? null : _select,
                overlay: true,
                bottomInset: MediaQuery.textScalerOf(context).scale(14) > 19
                    ? 80
                    : 8,
              ),
              if (_loadingTraces)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
