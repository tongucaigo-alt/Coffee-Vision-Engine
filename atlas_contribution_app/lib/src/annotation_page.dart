import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'label_picker.dart';
import 'photo_crop.dart';
import 'cropped_photo.dart';
import 'theme.dart';

class AnnotationPage extends StatefulWidget {
  const AnnotationPage({
    required this.photo,
    required this.image,
    required this.onSave,
    this.displayCrop,
    this.modern = false,
    this.navigation,
    this.onComplete,
    this.completionLabel = 'Fotoğrafı tamamla',
    super.key,
  });
  final ContributionPhoto photo;
  final ImageProvider image;
  final PhotoCrop? displayCrop;
  final bool modern;
  final Widget? navigation;
  final VoidCallback? onComplete;
  final String completionLabel;
  final Future<void> Function(ContributionPhoto) onSave;
  @override
  State<AnnotationPage> createState() => _AnnotationPageState();
}

class _AnnotationPageState extends State<AnnotationPage> {
  late ContributionPhoto _photo = widget.photo;
  // Keep the view stable while editing. Existing annotations outside a crop
  // require the full image; they must not disappear or be clipped on save.
  late final PhotoCrop _displayCrop =
      widget.displayCrop != null &&
          widget.photo.regions.every(
            (region) => widget.displayCrop!.containsBox(region.box),
          )
      ? widget.displayCrop!
      : PhotoCrop.full;
  RegionBox? _box;
  String? _editingId;
  bool _saving = false;
  bool _markMode = false;
  Size _viewport = Size.zero;
  final _transform = TransformationController();
  final _pointers = <int, Offset>{};
  RegionBox? _beforeBox;
  String? _beforeEditingId;
  Offset _downPoint = Offset.zero;
  Size _gestureSize = Size.zero;
  int _action = -3; // -3 photo, -2 empty tap, -1 move, 0..3 resize.
  bool _multi = false, _blocked = false;
  double _pinchDistance = 1, _pinchScale = 1;
  Offset _pinchScene = Offset.zero;

  Rect _boxRect(RegionBox b, Size size) => Rect.fromLTWH(
    b.x * size.width,
    b.y * size.height,
    b.width * size.width,
    b.height * size.height,
  );

  Rect _cornerRect(RegionBox b, int corner, Size size) => Rect.fromLTWH(
    ((corner.isEven ? b.x : b.x + b.width) * size.width - 24).clamp(
      0,
      math.max(0, size.width - 48),
    ),
    ((corner < 2 ? b.y : b.y + b.height) * size.height - 24).clamp(
      0,
      math.max(0, size.height - 48),
    ),
    48,
    48,
  );

  void _setView(double scale, Offset translation) {
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        translation.dx.clamp(_viewport.width * (1 - scale), 0.0),
        translation.dy.clamp(_viewport.height * (1 - scale), 0.0),
        0,
      );
  }

  void _rebasePinch() {
    final pair = _pointers.values.take(2).toList();
    final midpoint = (pair[0] + pair[1]) / 2;
    _pinchDistance = math.max((pair[1] - pair[0]).distance, .001);
    _pinchScale = _transform.value.getMaxScaleOnAxis();
    _pinchScene = _transform.toScene(midpoint);
  }

  void _abortGesture() {
    if (_pointers.isEmpty) return;
    _box = _beforeBox;
    _editingId = _beforeEditingId;
    _blocked = true;
  }

  void _pointerDown(PointerDownEvent event) {
    if (_saving || _viewport.isEmpty) return;
    setState(() {
      if (_pointers.isEmpty) {
        _beforeBox = _box;
        _beforeEditingId = _editingId;
        _downPoint = event.localPosition;
        _gestureSize = _viewport;
        _multi = false;
        _blocked = false;
        _action = _markMode ? -2 : -3;
      }
      _pointers[event.pointer] = event.localPosition;
      if (_blocked) return;
      if (_pointers.length >= 2) {
        // Undo tentative single-finger edits before giving the gesture to the image.
        _multi = true;
        _box = _beforeBox;
        _editingId = _beforeEditingId;
        _rebasePinch();
        return;
      }
      if (!_markMode) return;
      final scene = _transform.toScene(event.localPosition);
      if (_box case final b?) {
        final rect = _boxRect(b, _viewport);
        final moveCenter = Rect.fromCenter(
          center: rect.center,
          width: rect.width / 3,
          height: rect.height / 3,
        );
        // Small regions have overlapping corner targets; keep their center movable.
        if (moveCenter.contains(scene)) {
          _action = -1;
          return;
        }
        int? nearestCorner;
        var nearestDistance = double.infinity;
        for (var i = 0; i < 4; i++) {
          if (_cornerRect(b, i, _viewport).contains(scene)) {
            final corner = Offset(
              i.isEven ? rect.left : rect.right,
              i < 2 ? rect.top : rect.bottom,
            );
            final distance = (scene - corner).distanceSquared;
            // Equal distances keep the first corner in the stable 0..3 order.
            if (distance < nearestDistance) {
              nearestCorner = i;
              nearestDistance = distance;
            }
          }
        }
        if (nearestCorner != null) {
          _action = nearestCorner;
          return;
        }
        if (rect.contains(scene)) {
          _action = -1;
          return;
        }
      }
      for (final region in _photo.regions.reversed) {
        final displayBox = _displayCrop.toDisplayBox(region.box);
        if (_boxRect(displayBox, _viewport).contains(scene)) {
          _box = displayBox;
          _editingId = region.id;
          _action = -1;
          return;
        }
      }
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    if (previous == null) return;
    _pointers[event.pointer] = event.localPosition;
    if (_saving || _blocked) return;
    if (_gestureSize != _viewport) {
      setState(_abortGesture);
      return;
    }
    if (_pointers.length >= 2) {
      final pair = _pointers.values.take(2).toList();
      final midpoint = (pair[0] + pair[1]) / 2;
      final scale =
          (_pinchScale * (pair[1] - pair[0]).distance / _pinchDistance).clamp(
            1.0,
            4.0,
          );
      _setView(scale, midpoint - _pinchScene * scale);
    } else if (!_multi) {
      final delta = event.localPosition - previous;
      if (_action == -3) {
        final value = _transform.value;
        _setView(
          value.getMaxScaleOnAxis(),
          Offset(value.entry(0, 3), value.entry(1, 3)) + delta,
        );
      } else {
        final sceneDelta =
            _transform.toScene(event.localPosition) -
            _transform.toScene(previous);
        if (_action == -1 && _box != null) {
          setState(
            () => _box = _box!.move(
              sceneDelta.dx / _viewport.width,
              sceneDelta.dy / _viewport.height,
            ),
          );
        } else if (_action >= 0 && _box != null) {
          _resize(_action, sceneDelta, _viewport);
        }
      }
    }
  }

  void _pointerEnd(PointerEvent event, {bool cancelled = false}) {
    if (!_pointers.containsKey(event.pointer)) return;
    setState(() {
      if (cancelled) _abortGesture();
      if (!cancelled &&
          !_blocked &&
          !_multi &&
          _markMode &&
          _action == -2 &&
          (event.localPosition - _downPoint).distance <= kTouchSlop) {
        if (_photo.regions.length >= maxRegions) {
          showNotice(
            context,
            'Bu fotoğrafta 10 işaret var. Birini düzenleyebilirsin.',
          );
        } else {
          final scene = _transform.toScene(event.localPosition);
          _editingId = null;
          _box = RegionBox(
            (scene.dx / _viewport.width - .075).clamp(0, .85),
            (scene.dy / _viewport.height - .075).clamp(0, .85),
            .15,
            .15,
          );
        }
      }
      _pointers.remove(event.pointer);
      if (_pointers.length >= 2 && !_blocked) _rebasePinch();
      // After a pinch, the remaining finger is inert until every finger lifts.
      if (_pointers.isEmpty) {
        _multi = false;
        _blocked = false;
      }
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<bool> _persist(ContributionPhoto next) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(next);
      if (mounted) {
        setState(() {
          _photo = next;
          _box = null;
          _editingId = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) showNotice(context, 'İşaret kaydedilemedi. Tekrar dene.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choose() async {
    if (_box == null || _saving) return;
    final label = await pickContributionLabel(context);
    if (label == null || !mounted) return;
    final regions = _photo.regions.where((r) => r.id != _editingId).toList();
    if (regions.length >= maxRegions) return;
    regions.add(
      RegionAnnotation(
        id: _editingId ?? const Uuid().v4(),
        box: _displayCrop.toFullBox(_box!),
        label: label == 'uncertain' ? null : label,
      ),
    );
    await _persist(_photo.annotated(regions, PhotoDecision.marked));
  }

  Future<void> _decision(PhotoDecision decision) async {
    if (_photo.regions.isNotEmpty) return;
    if (await _persist(_photo.annotated([], decision)) && mounted) {
      _complete();
    }
  }

  void _complete() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pop(context);
    }
  }

  void _zoom(double factor) {
    setState(_abortGesture);
    final oldScale = _transform.value.getMaxScaleOnAxis();
    final scale = (oldScale * factor).clamp(1.0, 4.0);
    final center = _viewport.center(Offset.zero);
    final scene = _transform.toScene(center);
    final x = (center.dx - scene.dx * scale).clamp(
      _viewport.width * (1 - scale),
      0.0,
    );
    final y = (center.dy - scene.dy * scale).clamp(
      _viewport.height * (1 - scale),
      0.0,
    );
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(x, y, 0);
  }

  void _resize(int corner, Offset delta, Size size) {
    final b = _box!;
    final dx = delta.dx / size.width, dy = delta.dy / size.height;
    var left = b.x, top = b.y, right = b.x + b.width, bottom = b.y + b.height;
    if (corner == 0 || corner == 2) {
      left = (left + dx).clamp(0, right - .025);
    } else {
      right = (right + dx).clamp(left + .025, 1);
    }
    if (corner < 2) {
      top = (top + dy).clamp(0, bottom - .025);
    } else {
      bottom = (bottom + dy).clamp(top + .025, 1);
    }
    setState(() => _box = RegionBox(left, top, right - left, bottom - top));
  }

  Widget _canvas() => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = _displayCrop.aspectRatio(_photo.width, _photo.height);
      final height = widget.modern
          ? constraints.maxHeight
          : math.min(440.0, constraints.maxHeight);
      final width = math.min(constraints.maxWidth, height * ratio);
      final size = Size(width, width / ratio);
      _viewport = size;
      return Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: RawGestureDetector(
            key: const ValueKey('annotation-viewport'),
            behavior: HitTestBehavior.opaque,
            gestures: {
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _pointerDown,
              onPointerMove: _pointerMove,
              onPointerUp: _pointerEnd,
              onPointerCancel: (event) => _pointerEnd(event, cancelled: true),
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 4,
                  panEnabled: false,
                  scaleEnabled: false,
                  child: SizedBox(
                    key: const ValueKey('annotation-canvas'),
                    width: size.width,
                    height: size.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CroppedPhoto(
                          image: widget.image,
                          crop: _displayCrop,
                          photoWidth: _photo.width,
                          photoHeight: _photo.height,
                          semanticLabel: _photo.title,
                        ),
                        for (final region in _photo.regions)
                          if (region.id != _editingId)
                            Positioned.fromRect(
                              rect: _boxRect(
                                _displayCrop.toDisplayBox(region.box),
                                size,
                              ),
                              child: Semantics(
                                label: region.title,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: widget.modern
                                          ? const Color(0xff8ec89c)
                                          : Colors.tealAccent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        if (_box case final b?) ...[
                          Positioned.fromRect(
                            rect: _boxRect(b, size),
                            child: Container(
                              key: const ValueKey('selected-region'),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: widget.modern
                                      ? const Color(0xffffd18a)
                                      : Colors.amberAccent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                          if (_markMode)
                            for (var i = 0; i < 4; i++)
                              Positioned.fromRect(
                                rect: _cornerRect(b, i, size),
                                child: Semantics(
                                  label: 'Çerçeve köşesi ${i + 1}',
                                  child: SizedBox(
                                    key: ValueKey('resize-corner-$i'),
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: widget.modern
                                              ? const Color(0xffffd18a)
                                              : Colors.amberAccent,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: widget.modern
          ? kToolbarHeight *
                (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 1.8)
          : null,
      title: Text(
        widget.modern ? 'Sen ne görüyorsun?' : _photo.title,
        style: widget.modern
            ? const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)
            : null,
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            children: [
              if (widget.navigation != null) widget.navigation!,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(widget.modern ? 'Taşı' : 'Fotoğraf'),
                      icon: widget.modern ? null : const Icon(LucideIcons.hand),
                    ),
                    ButtonSegment(
                      value: true,
                      label: const Text('İşaret'),
                      icon: widget.modern ? null : const Icon(LucideIcons.scan),
                    ),
                  ],
                  selected: {_markMode},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _abortGesture();
                          _markMode = value.single;
                        }),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _canvas(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Uzaklaştır',
                    onPressed: _saving ? null : () => _zoom(.8),
                    icon: const Icon(LucideIcons.zoomOut),
                  ),
                  IconButton(
                    tooltip: 'Yakınlaştır',
                    onPressed: _saving ? null : () => _zoom(1.25),
                    icon: const Icon(LucideIcons.zoomIn),
                  ),
                  IconButton(
                    tooltip: 'Fotoğrafı sığdır',
                    onPressed: _saving
                        ? null
                        : () {
                            setState(_abortGesture);
                            _transform.value = Matrix4.identity();
                          },
                    icon: const Icon(LucideIcons.maximize),
                  ),
                  if (_box != null)
                    IconButton(
                      tooltip: 'Seçimi kaldır',
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _box = null;
                              _editingId = null;
                            }),
                      icon: const Icon(LucideIcons.x),
                    ),
                ],
              ),
              Expanded(
                flex: 2,
                child: PageBody(
                  children: [
                    if (_box != null)
                      FilledButton(
                        onPressed: _saving ? null : _choose,
                        child: const Text('Bu alanı seç'),
                      ),
                    const SizedBox(height: 16),
                    for (final region in _photo.regions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: LabelIcon(region.label),
                        title: Text(region.title),
                        selected: _editingId == region.id,
                        onTap: _saving
                            ? null
                            : () => setState(() {
                                _abortGesture();
                                _editingId = region.id;
                                _box = _displayCrop.toDisplayBox(region.box);
                                _markMode = true;
                              }),
                        trailing: IconButton(
                          tooltip: '${region.title} işaretini sil',
                          onPressed: _saving
                              ? null
                              : () {
                                  final remaining = _photo.regions
                                      .where((r) => r.id != region.id)
                                      .toList();
                                  _persist(
                                    _photo.annotated(
                                      remaining,
                                      remaining.isEmpty
                                          ? PhotoDecision.unreviewed
                                          : PhotoDecision.marked,
                                    ),
                                  );
                                },
                          icon: const Icon(LucideIcons.trash2),
                        ),
                      ),
                    if (_photo.regions.isNotEmpty)
                      FilledButton(
                        onPressed: _saving ? null : _complete,
                        child: Text(widget.completionLabel),
                      ),
                    if (_photo.regions.isEmpty) ...[
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _decision(PhotoDecision.notSeen),
                        child: const Text('Bu fotoğrafta şekil seçemedim'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _decision(PhotoDecision.uncertain),
                        child: const Text('Emin değilim'),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => _decision(PhotoDecision.skipped),
                        child: const Text('Şimdilik geç'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          if (!widget.modern ||
              (constraints.maxHeight >= 700 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 21)) {
            return content;
          }
          return SingleChildScrollView(
            child: SizedBox(
              height: math.max(constraints.maxHeight, 840),
              child: content,
            ),
          );
        },
      ),
    ),
  );
}
