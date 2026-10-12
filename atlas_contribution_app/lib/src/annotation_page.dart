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
import 'opencv_traces.dart';
import 'trace_overlay.dart';
import 'atlas_design.dart';
import 'coffee_controls.dart';

class AnnotationPage extends StatefulWidget {
  const AnnotationPage({
    required this.photo,
    required this.image,
    required this.onSave,
    this.displayCrop,
    this.traces,
    this.modern = false,
    this.navigation,
    this.onComplete,
    this.onFinish,
    this.onSaveOnly,
    this.onSkip,
    this.completionLabel = 'Fotoğrafı tamamla',
    super.key,
  });
  final ContributionPhoto photo;
  final ImageProvider image;
  final PhotoCrop? displayCrop;
  final TraceSet? traces;
  final bool modern;
  final Widget? navigation;
  final VoidCallback? onComplete, onFinish, onSaveOnly, onSkip;
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
  late bool _markMode = widget.modern;
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
    var choose = false, saveMove = false;
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
          choose = widget.modern;
          _box = RegionBox(
            (scene.dx / _viewport.width - .075).clamp(0, .85),
            (scene.dy / _viewport.height - .075).clamp(0, .85),
            .15,
            .15,
          );
        }
      }
      if (widget.modern &&
          !cancelled &&
          !_blocked &&
          !_multi &&
          _editingId != null &&
          _box != null) {
        final moved = (event.localPosition - _downPoint).distance > kTouchSlop;
        saveMove = moved && (_action == -1 || _action >= 0);
      }
      _pointers.remove(event.pointer);
      if (_pointers.length >= 2 && !_blocked) _rebasePinch();
      // After a pinch, the remaining finger is inert until every finger lifts.
      if (_pointers.isEmpty) {
        _multi = false;
        _blocked = false;
      }
    });
    if (choose) _choose();
    if (saveMove) {
      final regions = _photo.regions
          .map(
            (r) => r.id == _editingId
                ? RegionAnnotation(
                    id: r.id,
                    box: _displayCrop.toFullBox(_box!),
                    label: r.label,
                  )
                : r,
          )
          .toList();
      _persist(_photo.annotated(regions, PhotoDecision.marked));
    }
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
                        if (widget.traces case final traces?)
                          TraceOverlay(
                            set: traces,
                            photo: _photo,
                            crop: _displayCrop,
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
  Widget _selectedName(
    RegionAnnotation region,
    BoxConstraints constraints,
    double insetY,
  ) => ValueListenableBuilder<Matrix4>(
    valueListenable: _transform,
    builder: (context, matrix, _) {
      final ratio = _displayCrop.aspectRatio(_photo.width, _photo.height);
      final width = math.min(
        constraints.maxWidth,
        constraints.maxHeight * ratio,
      );
      final size = Size(width, width / ratio);
      final origin = Offset(
        (constraints.maxWidth - width) / 2,
        (constraints.maxHeight - size.height) / 2,
      );
      final visible = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        size.width,
        size.height,
      );
      final style = DefaultTextStyle.of(context).style.merge(
        const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          height: 1.3,
          color: atlasCoffee,
          fontWeight: FontWeight.w700,
        ),
      );
      final text = TextPainter(
        text: TextSpan(text: region.title, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, width - 16));
      final labelSize = Size(
        math.min(width, text.width.ceilToDouble() + 14),
        text.height.ceilToDouble() + 8,
      );
      final box = _box ?? _displayCrop.toDisplayBox(region.box);
      final transformed = MatrixUtils.transformRect(
        matrix,
        _boxRect(box, size),
      ).shift(origin);
      final modeText = TextPainter(
        text: const TextSpan(
          text: 'Taşı İşaret',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final obstacles = <Rect>[
        Rect.fromLTWH(
          8,
          insetY,
          math.max(96, modeText.width + 40),
          math.max(48, modeText.height + 16),
        ),
        Rect.fromLTWH(
          constraints.maxWidth - 152,
          constraints.maxHeight - insetY - 48,
          144,
          48,
        ),
        for (var i = 0; i < 4; i++)
          MatrixUtils.transformRect(
            matrix,
            _cornerRect(box, i, size),
          ).shift(origin),
      ];
      Rect candidate(Offset at) => Rect.fromLTWH(
        at.dx.clamp(
          visible.left,
          math.max(visible.left, visible.right - labelSize.width),
        ),
        at.dy.clamp(
          visible.top,
          math.max(visible.top, visible.bottom - labelSize.height),
        ),
        labelSize.width,
        labelSize.height,
      );
      final candidates = <Rect>[
        candidate(
          Offset(transformed.left, transformed.top - labelSize.height - 26),
        ),
        candidate(Offset(transformed.left, transformed.bottom + 26)),
        candidate(Offset(transformed.right + 26, transformed.center.dy)),
        candidate(
          Offset(
            transformed.left - labelSize.width - 26,
            transformed.center.dy,
          ),
        ),
        for (var row = 0; row < 6; row++)
          for (var col = 0; col < 4; col++)
            candidate(
              Offset(
                visible.left + col * math.max(0, width - labelSize.width) / 3,
                visible.top +
                    row * math.max(0, size.height - labelSize.height) / 5,
              ),
            ),
      ];
      double overlap(Rect rect) => obstacles.fold(0.0, (sum, obstacle) {
        final intersection = rect.intersect(obstacle);
        return sum +
            (intersection.isEmpty
                ? 0
                : intersection.width * intersection.height);
      });
      var best = candidates.first;
      for (final rect in candidates) {
        if (overlap(rect) < overlap(best)) best = rect;
        if (overlap(best) == 0) break;
      }
      return Positioned.fromRect(
        rect: best,
        child: IgnorePointer(
          child: Container(
            key: const ValueKey('coffee-selected-name'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: atlasCream,
              border: Border.all(color: atlasSage),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(region.title, style: style),
          ),
        ),
      );
    },
  );

  Future<void> _remove(RegionAnnotation region) async {
    final remaining = _photo.regions.where((r) => r.id != region.id).toList();
    await _persist(
      _photo.annotated(
        remaining,
        remaining.isEmpty ? PhotoDecision.unreviewed : PhotoDecision.marked,
      ),
    );
  }

  Widget _modernBody() {
    final selected = _photo.regions
        .where((r) => r.id == _editingId)
        .firstOrNull;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        key: const ValueKey('coffee-annotation-body'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              key: const ValueKey('coffee-photo-frame'),
              decoration: BoxDecoration(
                color: atlasCard,
                border: Border.all(color: atlasBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = _displayCrop.aspectRatio(
                    _photo.width,
                    _photo.height,
                  );
                  final photoWidth = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight * ratio,
                  );
                  final insetY =
                      (constraints.maxHeight - photoWidth / ratio) / 2 + 8;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _canvas(),
                      if (selected != null)
                        _selectedName(selected, constraints, insetY),
                      Positioned(
                        top: insetY,
                        left: 8,
                        child: Material(
                          key: const ValueKey('coffee-mode-control'),
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            segments: const [
                              ButtonSegment(value: false, label: Text('Taşı')),
                              ButtonSegment(value: true, label: Text('İşaret')),
                            ],
                            selected: {_markMode},
                            onSelectionChanged: _saving
                                ? null
                                : (v) => setState(() {
                                    _abortGesture();
                                    _markMode = v.single;
                                  }),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: insetY,
                        child: Material(
                          key: const ValueKey('coffee-zoom-control'),
                          color: atlasCream.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Uzaklaştır',
                                onPressed: _saving ? null : () => _zoom(.8),
                                icon: const Icon(LucideIcons.zoomOut, size: 20),
                              ),
                              IconButton(
                                tooltip: 'Yakınlaştır',
                                onPressed: _saving ? null : () => _zoom(1.25),
                                icon: const Icon(LucideIcons.zoomIn, size: 20),
                              ),
                              IconButton(
                                tooltip: 'Fotoğrafı sığdır',
                                onPressed: _saving
                                    ? null
                                    : () {
                                        setState(_abortGesture);
                                        _transform.value = Matrix4.identity();
                                      },
                                icon: const Icon(
                                  LucideIcons.maximize,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.navigation != null) widget.navigation!,
          if (_photo.regions.isEmpty)
            CoffeeActions([
              CoffeeAction(
                'Göremedim',
                _saving ? null : () => _decision(PhotoDecision.notSeen),
              ),
              CoffeeAction(
                'Emin değilim',
                _saving ? null : () => _decision(PhotoDecision.uncertain),
              ),
              CoffeeAction(
                'Bu fotoğrafı geç',
                _saving ? null : () => _decision(PhotoDecision.skipped),
              ),
            ])
          else ...[
            Row(
              children: [
                Semantics(
                  label: '${_photo.regions.length} şekil seçildi',
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${_photo.regions.length}',
                      style: const TextStyle(fontSize: 12, color: atlasSage),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 48 + 16 * (scale - 1).clamp(0, 2),
                    child: ListView.separated(
                      key: const ValueKey('coffee-selected-symbols'),
                      scrollDirection: Axis.horizontal,
                      itemCount: _photo.regions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final region = _photo.regions[i];
                        return ChoiceChip(
                          showCheckmark: false,
                          avatar: LabelIcon(region.label, size: 20),
                          label: Text(region.title),
                          selected: _editingId == region.id,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() {
                                  _abortGesture();
                                  _editingId = region.id;
                                  _box = _displayCrop.toDisplayBox(region.box);
                                  _markMode = true;
                                }),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: selected?.title ?? 'Bir şekil seç',
                    child: Text(
                      selected?.title ?? 'Bir şekil seç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: atlasCoffee),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: selected == null || _saving ? null : _choose,
                  child: const Text('Değiştir'),
                ),
                TextButton(
                  onPressed: selected == null || _saving
                      ? null
                      : () => _remove(selected),
                  child: const Text('Kaldır'),
                ),
              ],
            ),
          ],
          if (_box != null && _editingId == null)
            TextButton(
              onPressed: _saving ? null : _choose,
              child: const Text('Bu alanı seç'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: widget.modern
          ? 56 +
                24 *
                    (MediaQuery.textScalerOf(context).scale(16) / 16 - 1).clamp(
                      0,
                      1,
                    )
          : null,
      title: Text(
        widget.modern ? 'Sen ne görüyorsun?' : _photo.title,
        style: widget.modern
            ? const TextStyle(
                fontFamily: 'Literata',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
    ),
    bottomNavigationBar: widget.modern
        ? SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: AtlasPrimaryButton.icon(
                      onPressed: _saving ? null : widget.onFinish,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Falımı Oluştur'),
                    ),
                  ),
                  CoffeeActions([
                    CoffeeAction(
                      'Yalnız Kaydet',
                      _saving ? null : widget.onSaveOnly,
                    ),
                    CoffeeAction(
                      'Kalanları geç',
                      _saving ? null : widget.onSkip,
                    ),
                  ]),
                ],
              ),
            ),
          )
        : null,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.modern) return _modernBody();
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
                      AtlasPrimaryButton(
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
                      AtlasPrimaryButton(
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
