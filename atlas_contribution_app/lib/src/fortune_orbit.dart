import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Presentation only: this orbit never reports analysis progress or findings.
class FortuneOrbitPainter extends CustomPainter {
  const FortuneOrbitPainter(this.seconds);
  final double seconds;
  static const sand = Color(0xffc89b7b);
  static const copper = Color(0xffb0714f);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = side * .42;
    final unit = radius * 2 / 280;
    final orbit = seconds / 7 * math.pi * 2;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * unit
        ..color = sand.withValues(alpha: .5),
    );
    final outer = radius * 1.09;
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit
      ..color = sand.withValues(alpha: .3);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(-seconds / 26 * math.pi * 2);
    final circumference = 2 * math.pi * outer;
    final segments = (circumference / (7 * unit)).round();
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: outer),
        i / segments * 2 * math.pi,
        3 / 7 / segments * 2 * math.pi,
        false,
        outerPaint,
      );
    }
    canvas.restore();

    // Both marks rotate as one carrier, matching the supplied HTML reference.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(orbit);
    final markSize = radius * .26 * 1.25;
    canvas.save();
    canvas.translate(-markSize / 2, -radius - markSize / 2);
    canvas.scale(markSize / 40);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(20, 20), radius: 16)),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(27, 15), radius: 13)),
    );
    canvas.drawPath(crescent, Paint()..color = sand);
    canvas.restore();

    canvas.save();
    canvas.translate(0, radius);
    canvas.scale(markSize / 40);
    final glow = .4 + .45 * (.5 - .5 * math.cos(seconds / 2.4 * math.pi * 2));
    canvas.drawCircle(
      Offset.zero,
      10,
      Paint()
        ..color = copper.withValues(alpha: glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final rays = Paint()
      ..color = copper
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i / 8 * math.pi * 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(direction * 12, direction * 17.5, rays);
    }
    canvas.drawCircle(Offset.zero, 8.5, Paint()..color = copper);
    canvas.drawCircle(
      const Offset(-3, -3),
      3,
      Paint()..color = sand.withValues(alpha: .55),
    );
    canvas.restore();
    canvas.restore();

    const stars = <(double, double, double, double)>[
      (.30, .22, 4, 0),
      (.68, .30, 3, .6),
      (.22, .58, 2.5, 1.2),
      (.72, .66, 3.5, 1.8),
      (.50, .44, 2, .9),
    ];
    for (final (x, y, diameter, delay) in stars) {
      final alpha =
          .2 + .8 * (.5 - .5 * math.cos((seconds - delay) / 2.4 * math.pi * 2));
      final position = centre + Offset(x - .5, y - .5) * (radius * 2);
      canvas.drawCircle(
        position,
        diameter * unit / 2,
        Paint()..color = sand.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(FortuneOrbitPainter oldDelegate) =>
      seconds != oldDelegate.seconds;
}
