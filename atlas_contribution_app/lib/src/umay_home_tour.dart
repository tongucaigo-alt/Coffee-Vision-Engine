import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'atlas_design.dart';

class UmayTourStep {
  const UmayTourStep({
    required this.target,
    required this.message,
    this.fallback,
    this.radius = 18,
    this.targetLabel = 'Gösterilen tuş. Tanıtıma devam et.',
  });
  final String target, message, targetLabel;
  final String? fallback;
  final double radius;
}

/// Explicit, user-paced tours never invoke the highlighted controls.
const umayTourSteps = <UmayTourStep>[
  UmayTourStep(
    target: 'coffee-start-camera',
    message:
        'Ben Umay. Atlas’ı birlikte tanıyalım. Fincanının fotoğrafını buradan çekebilirsin.',
    fallback:
        'Ben Umay. Atlas’ı birlikte tanıyalım. Ana ekrandaki kamera tuşuyla fincanının fotoğrafını çekebilirsin.',
    radius: 28,
  ),
  UmayTourStep(
    target: 'coffee-start-gallery',
    message: 'Hazır bir fincan fotoğrafın varsa buradan ekleyebilirsin.',
    fallback:
        'Hazır bir fincan fotoğrafını ana ekrandaki galeri tuşuyla ekleyebilirsin.',
    radius: 28,
  ),
  UmayTourStep(
    target: 'atlas-nav-tarot',
    message: 'Kartlarını seçmek için Tarot’a buradan geçebilirsin.',
    fallback: 'Kartlarını seçmek için alttaki Tarot bölümüne geçebilirsin.',
  ),
  UmayTourStep(
    target: 'atlas-nav-records',
    message: 'Kaydettiğin kahve ve tarot fallarını burada bulabilirsin.',
    fallback:
        'Kaydettiğin fallarını alttaki Kayıtlarım bölümünde bulabilirsin.',
  ),
];

class UmayHomeTour extends StatefulWidget {
  const UmayHomeTour({
    required this.child,
    required this.onFinish,
    this.steps = umayTourSteps,
    this.onStepChanged,
    this.onPresented,
    this.enabled = true,
    this.suspended = false,
    super.key,
  }) : assert(steps.length > 0);

  final Widget child;
  final void Function(bool completed) onFinish;
  final List<UmayTourStep> steps;
  final ValueChanged<int>? onStepChanged;
  final VoidCallback? onPresented;
  final bool enabled, suspended;

  @override
  State<UmayHomeTour> createState() => _UmayHomeTourState();
}

class _UmayHomeTourState extends State<UmayHomeTour>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _contentKey = GlobalKey();
  final _messageScroll = ScrollController();
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2700),
  );
  Timer? _retry;
  Rect? _target;
  Size? _size;
  int _step = 0;
  int _measureTries = 0;
  int _stableMeasurements = 0;
  bool _active = true, _reduced = false, _measurePending = false;
  bool _imagesStarted = false, _imagesReady = false;
  bool _presented = false;
  bool get _visible => widget.enabled && !widget.suspended && _active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_motion.value == 0 || reduced != _reduced) {
      _reduced = reduced;
      if (reduced) {
        _motion.value = 1;
      } else if (_visible && _imagesReady) {
        _motion.forward();
      }
    }
    if (widget.enabled && !_imagesStarted) {
      _imagesStarted = true;
      unawaited(_prepareImages());
    }
    _scheduleMeasure();
  }

  Future<void> _prepareImages() async {
    await Future.wait([
      for (final side in ['left', 'right'])
        precacheImage(
          AssetImage('assets/umay/umay-speaking-$side.png'),
          context,
        ),
    ]);
    if (!mounted) return;
    setState(() => _imagesReady = true);
    if (_visible && !_reduced) _motion.forward();
  }

  @override
  void didUpdateWidget(UmayHomeTour oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _step = 0;
      _target = null;
      _presented = false;
      _measureTries = 0;
      _stableMeasurements = 0;
      if (!_imagesStarted) {
        _imagesStarted = true;
        unawaited(_prepareImages());
      }
      if (_reduced) {
        _motion.value = 1;
      } else if (_visible && _imagesReady) {
        _motion.forward(from: 0);
      }
    }
    if (!_visible) {
      _motion.stop();
      _retry?.cancel();
    } else {
      if (!_reduced && _imagesReady) _motion.forward();
      _scheduleMeasure();
    }
  }

  @override
  void didChangeMetrics() {
    _measureTries = 0;
    _scheduleMeasure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_active == active) return;
    setState(() => _active = active);
    if (active) {
      _measureTries = 0;
      if (_visible && !_reduced && _imagesReady) _motion.forward();
      _scheduleMeasure();
    } else {
      _motion.stop();
      _retry?.cancel();
    }
  }

  void _scheduleMeasure() {
    if (_measurePending || !_visible || !mounted) return;
    _measurePending = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (!mounted || !_visible) return;
      final content = _contentKey.currentContext;
      final root = content?.findRenderObject();
      final boxes = <RenderBox>[];
      void visit(Element element) {
        if (element.widget case Offstage(offstage: true)) return;
        final target = widget.steps[_step].target;
        final key = element.widget.key;
        if (element.widget.key == ValueKey(target) ||
            target.startsWith('prefix:') &&
                key is ValueKey<String> &&
                key.value.startsWith(target.substring(7)) ||
            target.startsWith('tooltip:') &&
                element.widget is Tooltip &&
                (element.widget as Tooltip).message == target.substring(8)) {
          bool? enabled;
          void check(Element node) {
            final w = node.widget;
            if (w is ButtonStyleButton) {
              enabled ??= w.onPressed != null;
            }
            if (w is IconButton) {
              enabled ??= w.onPressed != null;
            }
            node.visitChildren(check);
          }

          check(element);
          if (enabled == false) return;
          final render = element.findRenderObject();
          if (render is RenderBox && render.attached && render.hasSize) {
            boxes.add(render);
          }
          return;
        }
        element.visitChildren(visit);
      }

      if (content is Element) content.visitChildren(visit);
      Rect? rect;
      if (root is RenderBox && root.hasSize) {
        for (final box in boxes) {
          var candidate =
              box.localToGlobal(Offset.zero, ancestor: root) & box.size;
          final full = candidate;
          RenderObject child = box;
          while (child != root && child.parent != null) {
            final parent = child.parent!;
            final clip = parent.describeApproximatePaintClip(child);
            if (clip != null) {
              candidate = candidate.intersect(
                MatrixUtils.transformRect(parent.getTransformTo(root), clip),
              );
            }
            child = parent;
          }
          if (candidate.isFinite &&
              candidate.width >= full.width * .9 &&
              candidate.height >= full.height * .9 &&
              candidate.overlaps(Offset.zero & root.size)) {
            rect = candidate.intersect(Offset.zero & root.size);
            break;
          }
        }
      }
      if (rect != _target) {
        _stableMeasurements = 0;
        setState(() => _target = rect);
      } else {
        _stableMeasurements++;
      }
      _retry?.cancel();
      // A bottom sheet may still be entering when its controls first lay out.
      // Follow its geometry until it stays still, then stop polling.
      if (++_measureTries < 20 && (rect == null || _stableMeasurements < 4)) {
        _retry = Timer(const Duration(milliseconds: 100), _scheduleMeasure);
      }
    });
  }

  void _go(int step) {
    if (step == widget.steps.length) {
      widget.onFinish(true);
      return;
    }
    setState(() {
      _step = step;
      _target = null;
      _measureTries = 0;
      _stableMeasurements = 0;
    });
    if (_messageScroll.hasClients) _messageScroll.jumpTo(0);
    widget.onStepChanged?.call(step);
    if (_reduced) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _motion.dispose();
    _messageScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.enabled || widget.suspended,
    onPopInvokedWithResult: (popped, _) {
      if (popped || !widget.enabled || widget.suspended) return;
      if (_step > 0) {
        _go(_step - 1);
      } else {
        widget.onFinish(false);
      }
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (_size != constraints.biggest) {
          _size = constraints.biggest;
          _measureTries = 0;
          _scheduleMeasure();
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(
              absorbing: widget.enabled && !widget.suspended,
              child: ExcludeSemantics(
                excluding: widget.enabled && !widget.suspended,
                child: SizedBox.expand(key: _contentKey, child: widget.child),
              ),
            ),
            if (_visible && _imagesReady)
              ..._overlay(context, constraints.biggest),
          ],
        );
      },
    ),
  );

  List<Widget> _overlay(BuildContext context, Size size) {
    final media = MediaQuery.of(context);
    final safe = Rect.fromLTRB(
      12 + media.viewPadding.left,
      12 + media.viewPadding.top,
      size.width - 12 - media.viewPadding.right,
      size.height -
          12 -
          math.max(media.viewPadding.bottom, media.viewInsets.bottom),
    );
    if (safe.width < 160 || safe.height < 130) return const [];
    if (!_presented) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_visible || _presented) return;
        _presented = true;
        widget.onPresented?.call();
      });
    }
    final target = _target;
    final step = widget.steps[_step];
    final message = target != null
        ? step.message
        : step.fallback ?? step.message;
    final wideText = media.textScaler.scale(15) > 21 || size.width < 350;
    final width = math.min(380.0, safe.width);
    final avatarLeft = target == null || target.center.dx >= size.width / 2;
    final bodyWidth = width - 28 - (wideText ? 0 : 86);
    final textStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 15,
      height: 1.5,
      color: atlasInk,
      fontWeight: media.boldText ? FontWeight.bold : null,
    );
    final painter = TextPainter(
      text: TextSpan(text: message, style: textStyle),
      textScaler: media.textScaler,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: bodyWidth);
    final desiredHeight =
        painter.height + 28 + 44 + 12 + 48 + (wideText ? 20 : 0);
    painter.dispose();
    final above = target == null ? 0.0 : target.top - 14 - safe.top;
    final below = target == null ? 0.0 : safe.bottom - target.bottom - 14;
    final placeAbove =
        target != null && above >= math.min(desiredHeight, safe.height) ||
        target != null && above >= below;
    final room = target == null ? safe.height : math.max(above, below);
    final height = math.min(
      desiredHeight,
      math.min(safe.height, math.max(wideText ? 160.0 : 132.0, room)),
    );
    final left = ((target?.center.dx ?? safe.center.dx) - width / 2)
        .clamp(safe.left, safe.right - width)
        .toDouble();
    final top =
        (target == null
                ? safe.center.dy - height / 2
                : placeAbove
                ? target.top - 14 - height
                : target.bottom + 14)
            .clamp(safe.top, math.max(safe.top, safe.bottom - height))
            .toDouble();
    final card = Material(
      key: const ValueKey('umay-tour-bubble'),
      color: atlasCard,
      elevation: 7,
      shadowColor: atlasCoffee.withValues(alpha: .16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: atlasBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: wideText ? 64 : 44,
              child: Row(
                children: [
                  if (wideText) ...[
                    _avatar(avatarLeft, 56),
                    const SizedBox(width: 8),
                  ],
                  const Expanded(
                    child: Text(
                      'Umay',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: atlasCoffee,
                      ),
                    ),
                  ),
                  Text(
                    '${_step + 1}/${widget.steps.length}',
                    key: const ValueKey('umay-tour-step'),
                    style: const TextStyle(fontSize: 12, color: atlasMuted),
                  ),
                  IconButton(
                    key: const ValueKey('umay-tour-skip'),
                    tooltip: 'Tanıtımı atla',
                    onPressed: () => widget.onFinish(false),
                    iconSize: 18,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _messageScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('umay-tour-message'),
                  controller: _messageScroll,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(message, style: textStyle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('umay-tour-back'),
                      onPressed: () => _go(_step - 1),
                      child: const Text('Geri'),
                    ),
                  )
                else
                  const Spacer(),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('umay-tour-next'),
                    onPressed: () => _go(_step + 1),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      _step == widget.steps.length - 1 ? 'Bitir' : 'İleri',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final avatar = _avatar(avatarLeft, 76);
    return [
      const Positioned.fill(
        child: ModalBarrier(dismissible: false, color: Colors.transparent),
      ),
      if (target != null)
        Positioned.fromRect(
          rect: target,
          child: Semantics(
            button: true,
            label: step.targetLabel,
            child: GestureDetector(
              key: const ValueKey('umay-tour-target'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _go(_step + 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(step.radius),
                  border: Border.all(color: atlasSageInk, width: 2),
                  color: atlasSageInk.withValues(alpha: .035),
                ),
              ),
            ),
          ),
        ),
      Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) => Opacity(
            opacity: _reduced ? 1 : (_motion.value * 15).clamp(0.0, 1.0),
            child: child,
          ),
          child: wideText
              ? card
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (avatarLeft) ...[avatar, const SizedBox(width: 10)],
                    Expanded(child: card),
                    if (!avatarLeft) ...[const SizedBox(width: 10), avatar],
                  ],
                ),
        ),
      ),
    ];
  }

  Widget _avatar(bool left, double width) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) => Transform.translate(
      key: const ValueKey('umay-tour-avatar-motion'),
      offset: Offset(
        0,
        _reduced ? 0 : -3 * (1 - math.cos(_motion.value * 6 * math.pi)),
      ),
      child: child,
    ),
    child: Image.asset(
      'assets/umay/umay-speaking-${left ? 'right' : 'left'}.png',
      key: const ValueKey('umay-tour-avatar'),
      width: width,
      height: width * 1.15,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}
