import 'package:flutter/material.dart';
import 'annotation_page.dart';
import 'atlas_design.dart';
import 'models.dart';
import 'theme.dart';

class AnnotationSequence extends StatefulWidget {
  const AnnotationSequence({
    required this.photos,
    required this.imageFor,
    required this.onSave,
    super.key,
  });
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
      setState(() => _index++);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _skipRemaining() async {
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
      if (mounted) Navigator.pop(context);
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
      child: AnnotationPage(
        key: ValueKey(photo.localName),
        photo: photo,
        image: widget.imageFor(photo),
        displayCrop: photo.visibleCrop,
        onSave: _save,
        onComplete: _next,
        modern: true,
        completionLabel: _index == _photos.length - 1
            ? 'İncelemeyi Tamamla'
            : 'Sonraki Fotoğraf',
        navigation: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${_index + 1} / ${_photos.length} · ${photo.title}',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _skipRemaining,
                  child: const Tooltip(
                    message: 'Kalanları Atla',
                    child: Text('Atla'),
                  ),
                ),
              ],
            ),
            if (_photos.length > 1)
              SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _photos.length; i++)
                      Semantics(
                        label: '${i + 1}. fotoğraf: ${_photos[i].title}',
                        selected: _index == i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: _busy
                                ? null
                                : () => setState(() => _index = i),
                            child: Container(
                              width: 60,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: i == _index ? atlasSage : atlasBorder,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AtlasPhoto(
                                photo: _photos[i],
                                image: widget.imageFor(_photos[i]),
                                height: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
