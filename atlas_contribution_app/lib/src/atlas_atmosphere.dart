import 'dart:async';
import 'dart:ui' show ClipOp;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'atlas_palette.dart';

enum AtlasAtmosphereScene {
  coffeeHome,
  coffeePreparation,
  coffeePhoto,
  tarotHome,
  tarotSelection,
}

enum AtlasAtmosphereRegionKind { protected, hero, steam, heading }

/// A layout-transparent marker. It never changes its child's constraints.
class AtlasAtmosphereRegion extends SingleChildRenderObjectWidget {
  const AtlasAtmosphereRegion({
    required this.kind,
    required super.child,
    super.key,
  });
  final AtlasAtmosphereRegionKind kind;
  @override
  RenderObject createRenderObject(BuildContext context) => _RegionBox(kind);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) => (renderObject as _RegionBox).kind = kind;
}

class _RegionBox extends RenderProxyBox {
  _RegionBox(this.kind);
  AtlasAtmosphereRegionKind kind;
}

@immutable
class AtlasAtmosphereGeometry {
  const AtlasAtmosphereGeometry({
    this.ready = false,
    this.protected = const [],
    this.text = const [],
    this.hero,
    this.steam,
    this.photo,
    this.artwork,
    this.artworkHalfWidth,
    this.heading,
  });
  final bool ready;
  final List<Rect> protected, text;
  final Rect? hero, steam, photo;
  final Rect? artwork;
  final double? artworkHalfWidth;
  final Rect? heading;
  @override
  bool operator ==(Object other) =>
      other is AtlasAtmosphereGeometry &&
      ready == other.ready &&
      listEquals(protected, other.protected) &&
      listEquals(text, other.text) &&
      hero == other.hero &&
      steam == other.steam &&
      photo == other.photo &&
      artwork == other.artwork &&
      artworkHalfWidth == other.artworkHalfWidth &&
      heading == other.heading;
  @override
  int get hashCode => Object.hash(
    ready,
    Object.hashAll(protected),
    Object.hashAll(text),
    hero,
    steam,
    photo,
    artwork,
    artworkHalfWidth,
    heading,
  );
}

/// Shared, image-relative light proportions, calibrated from the approved
/// Tarot screen. Controls and their protection rectangles never enter this
/// calculation. The cream stop is 50% of the elliptical radius.
Rect? atlasHomeHaloBounds(AtlasAtmosphereGeometry geometry) {
  final hero = geometry.hero;
  if (hero == null) return null;
  final art = geometry.artwork ?? hero;
  final top = art.top - 50, bottom = art.bottom + 8;
  final radiusY = (bottom - top) / 2;
  final centerY = (top + bottom) / 2;
  final relativeY = (hero.center.dy - centerY) / radiusY;
  final creamFactor = math.sqrt(math.max(.01, .25 - relativeY * relativeY));
  final halfWidth = geometry.artworkHalfWidth ?? art.width / 2;
  final radiusX = (halfWidth + 39) / creamFactor;
  return Rect.fromCenter(
    center: Offset(hero.center.dx, centerY),
    width: radiusX * 2,
    height: radiusY * 2,
  );
}

/// The foreground is the only non-positioned child, so its geometry is unchanged.
class AtlasAtmosphereSurface extends StatefulWidget {
  const AtlasAtmosphereSurface({
    required this.scene,
    required this.child,
    this.active = true,
    super.key,
  });
  final AtlasAtmosphereScene? scene;
  final Widget child;
  final bool active;
  @override
  State<AtlasAtmosphereSurface> createState() => _AtlasAtmosphereSurfaceState();
}

class _AtlasAtmosphereSurfaceState extends State<AtlasAtmosphereSurface> {
  final _root = GlobalKey(), _content = GlobalKey();
  final _geometry = ValueNotifier(const AtlasAtmosphereGeometry());
  bool _pending = false;
  void _schedule() {
    if (_pending || !mounted || widget.scene == null) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      final root = _root.currentContext?.findRenderObject();
      final content = _content.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize || content == null) return;
      final bounds = Offset.zero & root.size;
      final protected = <Rect>[], text = <Rect>[];
      Rect? hero, steam, photo, heading;
      Rect? artwork;
      final artQuads = <List<Offset>>[];
      final home =
          widget.scene == AtlasAtmosphereScene.coffeeHome ||
          widget.scene == AtlasAtmosphereScene.tarotHome;
      Rect rect(RenderBox box) => MatrixUtils.transformRect(
        box.getTransformTo(root),
        Offset.zero & box.size,
      );
      void visit(RenderObject object, [bool inHero = false]) {
        if (!object.attached || (object is RenderOffstage && object.offstage)) {
          return;
        }
        if (object is RenderBox && object.hasSize && object.size.isFinite) {
          final area = rect(object);
          if (!area.overlaps(bounds)) return;
          if (object is _RegionBox) {
            if (object.kind == AtlasAtmosphereRegionKind.heading) {
              heading = area;
            }
            if (object.kind == AtlasAtmosphereRegionKind.hero) {
              hero = area;
              inHero = true;
            }
            if (object.kind == AtlasAtmosphereRegionKind.steam) {
              steam = area;
              protected.add(
                Rect.fromLTRB(
                  area.left,
                  area.center.dy,
                  area.right,
                  area.bottom,
                ).inflate(8),
              );
              return;
            }
            if (object.kind == AtlasAtmosphereRegionKind.protected &&
                (widget.scene == AtlasAtmosphereScene.coffeePhoto ||
                    widget.scene == AtlasAtmosphereScene.coffeePreparation)) {
              photo ??= area;
            }
            if (object.kind != AtlasAtmosphereRegionKind.hero &&
                object.kind != AtlasAtmosphereRegionKind.heading) {
              protected.add(area.inflate(8));
            }
          }
          final isButton =
              object is RenderSemanticsAnnotations &&
              object.properties.button == true;
          if (object is RenderParagraph && !isButton) {
            final transform = object.getTransformTo(root);
            final boxes = object.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: object.text.toPlainText().length,
              ),
            );
            for (final box in boxes) {
              final glyphs = MatrixUtils.transformRect(
                transform,
                box.toRect(),
              ).inflate(8);
              protected.add(glyphs);
              text.add(glyphs);
            }
          } else if (object is RenderEditable || isButton) {
            protected.add(area.inflate(8));
            text.add(area.inflate(8));
          } else if (object is RenderImage) {
            protected.add(area.inflate(8));
            if (home && inHero) {
              artwork = artwork?.expandToInclude(area) ?? area;
              final transform = object.getTransformTo(root);
              artQuads.add([
                for (final corner in [
                  Offset.zero,
                  Offset(object.size.width, 0),
                  Offset(object.size.width, object.size.height),
                  Offset(0, object.size.height),
                ])
                  MatrixUtils.transformPoint(transform, corner),
              ]);
            }
          }
        }
        if (object is RenderIndexedStack) {
          var index = 0;
          object.visitChildren((child) {
            if (index++ == object.index) visit(child, inHero);
          });
        } else {
          object.visitChildren((child) => visit(child, inHero));
        }
      }

      visit(content);
      double? artworkHalfWidth;
      if (hero != null) {
        final y = hero!.center.dy, x = hero!.center.dx;
        for (final quad in artQuads) {
          for (var i = 0; i < quad.length; i++) {
            final a = quad[i], b = quad[(i + 1) % quad.length];
            if ((a.dy <= y && b.dy > y) || (b.dy <= y && a.dy > y)) {
              final edge = a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
              artworkHalfWidth = math.max(
                artworkHalfWidth ?? 0,
                (edge - x).abs(),
              );
            }
          }
        }
      }
      final next = AtlasAtmosphereGeometry(
        ready: true,
        protected: List.unmodifiable(protected),
        text: List.unmodifiable(text),
        hero: hero,
        steam: steam,
        photo: photo,
        artwork: artwork,
        artworkHalfWidth: artworkHalfWidth,
        heading: heading,
      );
      if (_geometry.value != next) _geometry.value = next;
    });
  }

  @override
  void didUpdateWidget(covariant AtlasAtmosphereSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene) {
      _geometry.value = const AtlasAtmosphereGeometry();
      _schedule();
    }
  }

  @override
  void dispose() {
    _geometry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scene == null) return widget.child;
    _schedule();
    final theme = Theme.of(context);
    return Stack(
      key: _root,
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: atlasCream,
            child: ValueListenableBuilder<AtlasAtmosphereGeometry>(
              valueListenable: _geometry,
              builder: (_, geometry, _) => AtlasHomeAtmosphere(
                scene: widget.scene!,
                geometry: geometry,
                active: widget.active,
              ),
            ),
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _schedule();
            return false;
          },
          child: _LayoutProbe(
            key: _content,
            onLayout: _schedule,
            child: Theme(
              data: theme.copyWith(
                scaffoldBackgroundColor: Colors.transparent,
                appBarTheme: theme.appBarTheme.copyWith(
                  backgroundColor: Colors.transparent,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required super.child, super.key});
  final VoidCallback onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LayoutProbeBox(onLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _LayoutProbeBox object,
  ) => object.onLayout = onLayout;
}

class _LayoutProbeBox extends RenderProxyBox {
  _LayoutProbeBox(this.onLayout);
  VoidCallback onLayout;
  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}

/// A paint-only clock: timer frames repaint these boundaries, never the page.
/// Timers are suspended when the route, tab, or application is hidden.
class AtlasHomeAtmosphere extends StatefulWidget {
  const AtlasHomeAtmosphere({
    this.scene = AtlasAtmosphereScene.coffeeHome,
    this.geometry = const AtlasAtmosphereGeometry(ready: true),
    this.active = true,
    super.key,
  });
  final AtlasAtmosphereScene scene;
  final AtlasAtmosphereGeometry geometry;
  final bool active;
  @override
  State<AtlasHomeAtmosphere> createState() => _AtlasHomeAtmosphereState();
}

class _AtlasHomeAtmosphereState extends State<AtlasHomeAtmosphere>
    with WidgetsBindingObserver {
  final _seconds = ValueNotifier(0.0);
  Timer? _timer;
  bool _foreground = true, _reduced = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AtlasHomeAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _reduced = MediaQuery.disableAnimationsOf(context);
    final enabled =
        widget.active &&
        widget.geometry.ready &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !_reduced &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!enabled) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    final start = _seconds.value;
    _timer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) => _seconds.value = start + timer.tick * .05,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _AtmospherePainter(
                widget.scene,
                widget.geometry,
                null,
                _reduced,
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: _AtmospherePainter(
                widget.scene,
                widget.geometry,
                _seconds,
                _reduced,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter(this.scene, this.geometry, this.clock, this.still)
    : super(repaint: clock);
  final AtlasAtmosphereScene scene;
  final AtlasAtmosphereGeometry geometry;
  final ValueListenable<double>? clock;
  final bool still;
  bool get tarot =>
      scene == AtlasAtmosphereScene.tarotHome ||
      scene == AtlasAtmosphereScene.tarotSelection;
  static const steamInk = Color(0xff917154),
      warmLight = Color(0xfffff4dc),
      champagne = Color(0xffe2c58c),
      starInk = Color(0xffb58c48);
  Paint stroke(Color color, double alpha, [double width = .8]) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  void exclude(Canvas canvas, List<Rect> areas) {
    for (final area in areas) {
      canvas.clipRect(area, clipOp: ClipOp.difference);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!geometry.ready || size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (clock == null) {
      _paper(canvas, size);
      if (scene == AtlasAtmosphereScene.coffeeHome) {
        _softLight(canvas, size, 0);
        _beans(canvas, size);
      }
    } else {
      final seconds = clock!.value;
      if (tarot) {
        _softLight(canvas, size, seconds);
        _stars(canvas, size, seconds);
      } else {
        canvas.save();
        exclude(canvas, geometry.protected);
        _steam(canvas, size, seconds);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  void _paper(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-1, -1),
          radius: 1.5,
          colors: [Color(0x10d9aa6d), Color(0x00d9aa6d)],
        ).createShader(Offset.zero & size),
    );
  }

  // Keep complete accents in genuinely empty space, rather than cutting their
  // silhouettes around protected labels or controls.
  bool _accentFits(Size size, Offset center, double radius) {
    final area = Rect.fromCircle(center: center, radius: radius).inflate(8);
    return (Offset.zero & size).contains(area.topLeft) &&
        (Offset.zero & size).contains(area.bottomRight) &&
        !geometry.protected.any((protected) => protected.overlaps(area));
  }

  List<Offset> _homeAccents(Size size, {required bool mirrored}) {
    final heading = geometry.heading;
    if (heading == null) return const [];
    const left = 24.0;
    final right = size.width - 24;
    return [
      Offset(mirrored ? right : left, heading.top - 16),
      Offset(mirrored ? left : right, heading.center.dy),
      Offset(mirrored ? right : left, heading.bottom + 16),
    ];
  }

  void _beans(Canvas canvas, Size size) {
    final positions = _homeAccents(size, mirrored: true);
    for (var i = 0; i < positions.length; i++) {
      if (!_accentFits(size, positions[i], 5.5)) continue;
      canvas.save();
      canvas.translate(positions[i].dx, positions[i].dy);
      canvas.rotate(i == 1 ? -.55 : .55);
      canvas.drawOval(
        const Rect.fromLTWH(-3, -4.5, 6, 9),
        Paint()..color = atlasCopper.withValues(alpha: .42),
      );
      canvas.drawPath(
        Path()
          ..moveTo(.7, -4)
          ..cubicTo(-2.3, -1.1, 2.2, 1.1, -.7, 4),
        stroke(atlasCream, .93, .75),
      );
      canvas.restore();
    }
  }

  void _steam(Canvas canvas, Size size, double seconds) {
    if (scene == AtlasAtmosphereScene.coffeePhoto) return;
    final home = scene == AtlasAtmosphereScene.coffeeHome;
    final anchor = home ? geometry.hero : geometry.steam;
    if (anchor == null) return;
    final phase = still ? .5 : (seconds % 9) / 9;
    final fade = still ? .8 : math.sin(math.pi * phase);
    final maxAlpha = home ? .16 : .19;
    final bottom = home ? anchor.top - 8 : anchor.top + anchor.height * .38;
    final height = home ? math.min(58.0, math.max(0.0, bottom - 18)) : 36.0;
    if (height < 20) return;
    for (var i = 0; i < 3; i++) {
      final x = anchor.center.dx + (i - 1) * 18;
      final y = bottom - phase * 4;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..cubicTo(
            x - 15,
            y - height * .3,
            x + 13,
            y - height * .65,
            x + 3,
            y - height,
          ),
        stroke(steamInk, maxAlpha * fade * (1 - i * .08), .8),
      );
    }
  }

  void _softLight(Canvas canvas, Size size, double seconds) {
    // The illustrated home buttons already include their own relief and shadow.
    if (scene == AtlasAtmosphereScene.coffeeHome ||
        scene == AtlasAtmosphereScene.tarotHome) {
      return;
    }
    final hero = geometry.hero;
    if (hero == null || !hero.overlaps(Offset.zero & size)) return;
    final home =
        scene == AtlasAtmosphereScene.tarotHome ||
        scene == AtlasAtmosphereScene.coffeeHome;
    final coffee = scene == AtlasAtmosphereScene.coffeeHome;
    final breath = still ? .5 : (1 - math.cos(seconds * math.pi * 2 / 10)) / 2;
    // The home light must extend beyond opaque artwork and brighten parchment;
    // a low-opacity brown wash disappears behind the logo on the warmer base.
    final alpha = home
        ? (coffee ? .86 : .84 + .04 * breath)
        : .15 + .025 * breath;
    final ink = home ? warmLight : champagne;
    var rect = home ? atlasHomeHaloBounds(geometry)! : hero.inflate(32);
    // Non-home scenes keep their existing label protection. Home lights are
    // image-relative and do not resize or shift when a corner control appears.
    if (!home) {
      for (final area in geometry.text) {
        if (area.right <= rect.left || area.left >= rect.right) continue;
        if (area.bottom <= hero.top && area.bottom > rect.top) {
          rect = Rect.fromLTRB(rect.left, area.bottom, rect.right, rect.bottom);
        }
        if (area.top >= hero.bottom && area.top < rect.bottom) {
          rect = Rect.fromLTRB(rect.left, rect.top, rect.right, area.top);
        }
      }
    }
    if (rect.isEmpty) return;
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(rect.width / 2, rect.height / 2);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: home
              ? [
                  ink.withValues(alpha: alpha),
                  ink.withValues(alpha: alpha * .88),
                  const Color(0xffffdf93).withValues(alpha: alpha * .38),
                  ink.withValues(alpha: 0),
                ]
              : [
                  ink.withValues(alpha: alpha),
                  ink.withValues(alpha: alpha * .45),
                  ink.withValues(alpha: 0),
                ],
          stops: home ? const [0, .50, .78, 1] : const [0, .55, 1],
        ).createShader(const Rect.fromLTWH(-1, -1, 2, 2)),
    );
    canvas.restore();
  }

  void _stars(Canvas canvas, Size size, double seconds) {
    final positions = scene == AtlasAtmosphereScene.tarotHome
        ? _homeAccents(size, mirrored: false)
        : [
            Offset(
              size.width * .20,
              (geometry.hero?.top ?? size.height * .6) - 40,
            ),
            Offset(
              size.width * .82,
              (geometry.hero?.top ?? size.height * .6) - 26,
            ),
            Offset(
              size.width * .22,
              (geometry.hero?.bottom ?? size.height * .8) + 20,
            ),
          ];
    for (var i = 0; i < positions.length; i++) {
      final local = (seconds - i * 4) % 12;
      final pulse = still
          ? 0.0
          : local < 3
          ? math.sin(local / 3 * math.pi)
          : 0.0;
      final p = positions[i];
      if (!_accentFits(size, p, 4.5)) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      final star = Path()
        ..moveTo(0, -4)
        ..quadraticBezierTo(.5, -.5, 3, 0)
        ..quadraticBezierTo(.5, .5, 0, 4)
        ..quadraticBezierTo(-.5, .5, -3, 0)
        ..quadraticBezierTo(-.5, -.5, 0, -4)
        ..close();
      canvas.drawPath(
        star,
        Paint()..color = starInk.withValues(alpha: .65 + .15 * pulse),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) =>
      old.scene != scene ||
      old.geometry != geometry ||
      old.clock != clock ||
      old.still != still;
}
