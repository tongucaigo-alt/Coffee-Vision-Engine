import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'atlas_design.dart';

/// Paint-only decoration: never participates in the home's intrinsic geometry.
class AtlasHomeAtmosphere extends StatefulWidget {
  const AtlasHomeAtmosphere({super.key});
  @override
  State<AtlasHomeAtmosphere> createState() => _AtlasHomeAtmosphereState();
}

class _AtlasHomeAtmosphereState extends State<AtlasHomeAtmosphere>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _spark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Timer? _timer;
  int _star = 0;
  bool _foreground = true;
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

  void _sync() {
    final active =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!active) {
      _timer?.cancel();
      _timer = null;
      _spark.stop();
      _spark.value = 0;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        _star = (_star + 1) % 3;
        _spark.forward(from: 0);
      });
    }
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
    _spark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _PaperLightPainter()),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _StarsPainter(_spark, () => _star)),
          ),
        ],
      ),
    ),
  );
}

class _PaperLightPainter extends CustomPainter {
  const _PaperLightPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-1, -1),
          radius: 1.5,
          colors: [Color(0x14d9aa6d), Color(0x00d9aa6d)],
        ).createShader(bounds),
    );
    final random = math.Random(96);
    for (var i = 0; i < 1600; i++) {
      final x = random.nextDouble() * size.width,
          y = random.nextDouble() * size.height;
      final edge =
          x < 24 || x > size.width - 24 || y < 24 || y > size.height - 24;
      canvas.drawCircle(
        Offset(x, y),
        .25 + random.nextDouble() * .45,
        Paint()..color = atlasCoffee.withValues(alpha: edge ? .02 : .005),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperLightPainter old) => false;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.animation, this.index) : super(repaint: animation);
  final Animation<double> animation;
  final int Function() index;
  @override
  void paint(Canvas canvas, Size size) {
    final opacity = math.sin(math.pi * animation.value) * .22;
    if (opacity <= 0) return;
    final points = [
      Offset(14, size.height * .25),
      Offset(size.width - 14, size.height * .42),
      Offset(14, size.height * .7),
    ];
    final p = points[index()];
    final paint = Paint()..color = atlasCopper.withValues(alpha: opacity);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - 3)
        ..quadraticBezierTo(p.dx + .8, p.dy - .8, p.dx + 2, p.dy)
        ..quadraticBezierTo(p.dx + .8, p.dy + .8, p.dx, p.dy + 3)
        ..quadraticBezierTo(p.dx - .8, p.dy + .8, p.dx - 2, p.dy)
        ..quadraticBezierTo(p.dx - .8, p.dy - .8, p.dx, p.dy - 3)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.animation != animation;
}

class AtlasHomeHalo extends StatelessWidget {
  const AtlasHomeHalo({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x20d9aa6d), Color(0x00d9aa6d)],
                ),
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// Shared pastel leaf frame and central coffee bean for both homes.
class AtlasHomeFramePainter extends CustomPainter {
  const AtlasHomeFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 100 || size.height < 100) return;
    final bounds = Offset.zero & size;
    final readingArea = Rect.fromLTRB(
      20,
      16,
      size.width - 20,
      size.height - 16,
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(bounds),
        Path()..addRect(readingArea),
      ),
    );
    final copper = Paint()
      ..color = const Color(0x5cb0714f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..strokeCap = StrokeCap.round;
    final sage = Paint()
      ..color = const Color(0xb87ba294)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..strokeCap = StrokeCap.round;
    final leafFill = Paint()
      ..color = const Color(0x8c7ba294)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(6), const Radius.circular(26)),
      copper,
    );
    // Short inner corner lines echo the concentric rings of the Atlas emblem.
    for (final right in [false, true]) {
      for (final bottom in [false, true]) {
        canvas.save();
        canvas.translate(right ? size.width : 0, bottom ? size.height : 0);
        canvas.scale(right ? -1 : 1, bottom ? -1 : 1);
        canvas.drawPath(
          Path()
            ..moveTo(10, 46)
            ..lineTo(10, 32)
            ..quadraticBezierTo(10, 10, 32, 10)
            ..lineTo(46, 10),
          copper,
        );
        canvas.restore();
      }
    }
    for (final bottom in [false, true]) {
      canvas.save();
      if (bottom) {
        canvas.translate(0, size.height);
        canvas.scale(1, -1);
      }
      final center = size.width / 2;
      canvas.drawRect(
        Rect.fromLTWH(center - 47, 0, 94, 14),
        Paint()..color = atlasCream,
      );
      for (final right in [false, true]) {
        canvas.save();
        canvas.translate(center, 8);
        canvas.scale(right ? 1 : -1, 1);
        canvas.drawPath(
          Path()
            ..moveTo(9, 0)
            ..quadraticBezierTo(27, 3, 43, -1),
          sage,
        );
        for (var i = 0; i < 3; i++) {
          final x = 15.0 + i * 9;
          _leaf(canvas, Offset(x, 1), false, leafFill, sage);
          _leaf(canvas, Offset(x + 4, 1), true, leafFill, sage);
        }
        canvas.restore();
      }
      canvas.save();
      canvas.translate(center, 8);
      canvas.rotate(-.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 10),
        Paint()..color = atlasCoffee.withValues(alpha: .64),
      );
      canvas.drawPath(
        Path()
          ..moveTo(.6, -3.8)
          ..cubicTo(-2, -1.2, 2, 1.2, -.6, 3.8),
        Paint()
          ..color = atlasCard.withValues(alpha: .85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  void _leaf(Canvas canvas, Offset root, bool down, Paint fill, Paint vein) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.scale(1, down ? -1 : 1);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(-1, -4, 2, -6, 6, -6)
      ..cubicTo(6, -2, 3, 0, 0, 0)
      ..close();
    canvas.drawPath(leaf, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(4.5, -4.5),
      vein,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AtlasHomeFramePainter oldDelegate) => false;
}
