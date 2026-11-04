import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'opencv_traces.dart';
import 'photo_crop.dart';

const traceSymbolIconSize = 16.5;
const traceSymbolGap = 22.0 * 1.8;
// Contrasting accents from the existing palette, indexed by the underlying trace.
// Turquoise/pink, pink/cyan, blue/apricot, yellow/purple, and their counterparts.
const _symbolColorIndices = [1, 6, 5, 4, 3, 2, 1];
Color traceSymbolColorFor(int traceIndex) =>
    traceColors[_symbolColorIndices[traceIndex]];
// Largest animated glyph (1.2x), with two blur radii of breathing room.
const traceSymbolMargin = traceSymbolIconSize * 1.2 / 2 + 8;

class TraceSymbolAnchor {
  const TraceSymbolAnchor(this.traceIndex, this.position);
  final int traceIndex;
  final Offset position;
}

/// A final paint clip also contains the faint tail of the shadow.
class TraceSymbolClipper extends CustomClipper<Path> {
  TraceSymbolClipper(this.trace, this.crop);
  final TraceCandidate trace;
  final PhotoCrop crop;
  @override
  Path getClip(Size size) {
    final boundary =
        trace.result['surfaceBoundary'] ?? trace.result['cupBoundary'];
    if (boundary is! List || boundary.length != 5) return Path();
    final e = boundary.cast<num>();
    final angle = e[4] * math.pi / 180;
    final ca = math.cos(angle), sa = math.sin(angle);
    final path = Path();
    for (var i = 0; i < 128; i++) {
      final a = i * 2 * math.pi / 128;
      final x =
          e[0] + e[2] / 2 * math.cos(a) * ca - e[3] / 2 * math.sin(a) * sa;
      final y =
          e[1] + e[2] / 2 * math.cos(a) * sa + e[3] / 2 * math.sin(a) * ca;
      final px =
          (trace.area.x + x / trace.width * trace.area.width - crop.x) /
          crop.width *
          size.width;
      final py =
          (trace.area.y + y / trace.height * trace.area.height - crop.y) /
          crop.height *
          size.height;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return Path.combine(
      PathOperation.intersect,
      path,
      Path()..addRect(Offset.zero & size),
    );
  }

  @override
  bool shouldReclip(covariant TraceSymbolClipper old) =>
      old.trace != trace || old.crop != crop;
}

/// Calculated once per photo/crop/layout, never once per animation frame.
/// Every centre is a real mask pixel; the full glyph and shadow fit the ellipse.
List<TraceSymbolAnchor> traceSymbolAnchors(
  List<TraceCandidate> traces,
  PhotoCrop crop,
  Size size,
) {
  final anchors = <TraceSymbolAnchor>[];
  for (var index = 0; index < traces.length; index++) {
    final t = traces[index];
    final boundary = t.result['surfaceBoundary'] ?? t.result['cupBoundary'];
    if (boundary is! List || boundary.length != 5 || t.pixels.isEmpty) continue;
    final e = boundary.cast<num>();
    if (e.any((v) => !v.isFinite) || e[2] <= 0 || e[3] <= 0) continue;
    final dx = t.area.width / t.width / crop.width * size.width;
    final dy = t.area.height / t.height / crop.height * size.height;
    if (dx <= 0 || dy <= 0) continue;
    final origin = Offset(
      (t.area.x - crop.x) / crop.width * size.width,
      (t.area.y - crop.y) / crop.height * size.height,
    );
    final angle = e[4] * math.pi / 180;
    final ca = math.cos(angle), sa = math.sin(angle);
    bool fits(Offset point) {
      final r = Rect.fromCircle(center: point, radius: traceSymbolMargin);
      if (r.left < 0 ||
          r.top < 0 ||
          r.right > size.width ||
          r.bottom > size.height) {
        return false;
      }
      for (final corner in [
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
      ]) {
        final x = (corner.dx - origin.dx) / dx - e[0];
        final y = (corner.dy - origin.dy) / dy - e[1];
        final u = (x * ca + y * sa) / (e[2] / 2);
        final v = (-x * sa + y * ca) / (e[3] / 2);
        if (u * u + v * v > 1) return false;
      }
      return true;
    }

    var sx = 0.0, sy = 0.0;
    for (final p in t.pixels) {
      sx += p % t.width + .5;
      sy += p ~/ t.width + .5;
    }
    final centroid = Offset(sx / t.pixels.length, sy / t.pixels.length);
    Offset? best;
    var distance = double.infinity;
    for (final p in t.pixels) {
      final source = Offset(p % t.width + .5, p ~/ t.width + .5);
      final delta = (source - centroid).distanceSquared;
      if (delta >= distance) continue;
      final point = origin + Offset(source.dx * dx, source.dy * dy);
      if (fits(point)) {
        best = point;
        distance = delta;
      }
    }
    if (best != null) anchors.add(TraceSymbolAnchor(index, best));
  }
  return anchors;
}
