import 'dart:typed_data';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as img;

/// Application-only engine adapter. Dark pixels are candidates, not proof of
/// coffee or a detected cup interior. Source bytes/annotation space stay intact.
Future<Map<String, dynamic>> measurePhotoResidue(
  Map<String, dynamic> input,
) async {
  final decoded = img.decodeImage(input['bytes'] as Uint8List);
  if (decoded == null) throw const FormatException('Unreadable image');
  final image = img.bakeOrientation(decoded);
  final crop = (input['crop'] as List).cast<double>();
  final x = (crop[0] * image.width).floor();
  final y = (crop[1] * image.height).floor();
  final w = (crop[2] * image.width).round().clamp(1, image.width - x);
  final h = (crop[3] * image.height).round().clamp(1, image.height - y);
  final view = img.copyCrop(image, x: x, y: y, width: w, height: h);
  final full = await _measure(image);
  return {
    'version': 'atlas-residue-screen-v2',
    'full': full,
    'crop': x == 0 && y == 0 && w == image.width && h == image.height
        ? full
        : await _measure(view),
  };
}

Future<Map<String, dynamic>> _measure(img.Image image) async {
  const engine = CoffeeVisionEngine();
  final working = await engine.prepareWorkingImage(
    VisionImageInput(
      imageBytes: Uint8List.fromList(img.encodePng(image)),
      surfaceType: VisionSurfaceType.cup,
    ),
  );
  final mask = await engine.createResidueMask(workingImage: working);
  final components = await engine.detectComponents(mask: mask);
  final rect = working.contentRect;
  final pixels = mask.pixels;
  final decoded = img.decodeImage(working.bytes)!;
  final horizontal = List.filled(3, 0);
  final vertical = List.filled(3, 0);
  final horizontalTotal = List.filled(3, 0);
  final verticalTotal = List.filled(3, 0);
  var total = 0, border = 0, dark = 0, luminance = 0;
  var centerTotal = 0, centerDark = 0, centerLuminance = 0;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      final nx = ((x + .5) / mask.width - rect.left) / rect.width;
      final ny = ((y + .5) / mask.height - rect.top) / rect.height;
      if (nx < 0 || ny < 0 || nx >= 1 || ny >= 1) continue;
      final r = (ny * 3).floor(), c = (nx * 3).floor();
      horizontalTotal[r]++;
      verticalTotal[c]++;
      total++;
      final p = decoded.getPixel(x, y);
      final light = ((p.r * 299 + p.g * 587 + p.b * 114) / 1000).round();
      luminance += light;
      // A fixed central sample, NOT a localized cup interior or a new crop.
      if ((nx - .5) * (nx - .5) + (ny - .5) * (ny - .5) <= .0625) {
        centerTotal++;
        centerLuminance += light;
        centerDark += pixels[y * mask.width + x];
      }
      if (pixels[y * mask.width + x] == 0) continue;
      dark++;
      horizontal[r]++;
      vertical[c]++;
      if (nx < .1 || nx > .9 || ny < .1 || ny > .9) border++;
    }
  }
  final sorted = components.components.toList()
    ..sort((a, b) => b.pixelCount.compareTo(a.pixelCount));
  return {
    'relativeDarkRatio': mask.residueRatio,
    'meanLuminance': total == 0 ? 0.0 : luminance / total,
    'borderDarkShare': dark == 0 ? 0.0 : border / dark,
    'largestComponentRatio': sorted.isEmpty
        ? 0.0
        : sorted.first.pixelCount / total,
    'componentCount': components.componentCount,
    'centerDarkRatio': centerTotal == 0 ? 0.0 : centerDark / centerTotal,
    'centerLuminance': centerTotal == 0 ? 0.0 : centerLuminance / centerTotal,
    'horizontalDensities': [
      for (var i = 0; i < 3; i++) horizontal[i] / horizontalTotal[i],
    ],
    'verticalDensities': [
      for (var i = 0; i < 3; i++) vertical[i] / verticalTotal[i],
    ],
  };
}

/// Candidate rules only: the release gate is independent of these thresholds.
/// Each surface can be calibrated independently without changing the motor.
String residueDecision(
  Map<dynamic, dynamic> scores,
  Map<String, dynamic> physical, {
  required bool saucer,
}) {
  final views = ['full', 'crop'].map((key) => physical[key] as Map).toList();
  double n(Map v, String key) {
    final value = v[key];
    if (value is! num || !value.isFinite) {
      throw const FormatException('Invalid measurement');
    }
    return value.toDouble();
  }

  final evidence = <double>[];
  for (final key in ['full', 'crop']) {
    final rows = (scores[key] as List).cast<Map>();
    final values = rows
        .where(
          (r) => RegExp(
            r'(^|, )(cup|coffee mug|espresso|soup bowl|plate|dish)(,|$)',
          ).hasMatch(r['label'] as String),
        )
        .map((r) => (r['score'] as num).toDouble());
    evidence.add(values.fold(0.0, (a, b) => a > b ? a : b));
  }
  // Both views must support the object strongly. Low light is inconclusive;
  // it is never sufficient evidence that a cup is empty.
  final emptyRatio = saucer ? .006 : .008;
  if (evidence.every((s) => s >= .60) &&
      views.every(
        (v) =>
            n(v, 'relativeDarkRatio') < emptyRatio &&
            n(v, 'meanLuminance') >= 70,
      )) {
    return 'residueFree';
  }
  // Frozen from calibration only (2026-10-01). The central disk is a
  // framing heuristic, not detected cup geometry. Small calibration support
  // means these candidates remain experimental until the release gate passes.
  final centerConfidence = saucer ? .15 : .60;
  final centerRatio = saucer ? .30 : .001;
  final centerLight = saucer ? 140 : 180;
  if (evidence.every((s) => s >= centerConfidence) &&
      views.every(
        (v) =>
            n(v, 'centerDarkRatio') <= centerRatio &&
            n(v, 'centerLuminance') >= centerLight,
      )) {
    return 'residueFree';
  }
  if (evidence.any((s) => s >= .35) &&
      views.any(
        (v) =>
            n(v, 'relativeDarkRatio') >= .02 &&
            n(v, 'relativeDarkRatio') <= .75 &&
            n(v, 'borderDarkShare') < .85 &&
            n(v, 'largestComponentRatio') >= .005,
      )) {
    return 'supported';
  }
  return 'uncertain';
}
