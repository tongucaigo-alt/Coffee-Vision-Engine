import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as image;

import 'lf2_models.dart';
import 'lf3_models.dart';
import 'lf3_profiles.dart';

final class Lf3EvidenceBuilder {
  const Lf3EvidenceBuilder({
    this.supportDetector = const Lf3SurfaceSupportDetector(),
  });

  final Lf3SurfaceSupportDetector supportDetector;

  Lf3EvidenceFrame build(WorkingImage workingImage) {
    final decoded = _decode(workingImage);
    if (decoded.width != workingImage.workingMetadata.width ||
        decoded.height != workingImage.workingMetadata.height) {
      throw const FormatException(
        'Working image metadata does not match decoded dimensions.',
      );
    }
    final width = decoded.width;
    final height = decoded.height;
    final bounds = _pixelBounds(
      workingImage.contentRect,
      width: width,
      height: height,
    );
    final luminance = Uint8List(width * height);
    final chromaU = Int16List(width * height);
    final chromaV = Int16List(width * height);
    final histogram = Uint32List(256);
    var contentPixelCount = 0;
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        final pixel = decoded.getPixel(x, y);
        final value = pixel.luminance.round().clamp(0, 255);
        final index = y * width + x;
        luminance[index] = value;
        chromaU[index] = pixel.b.round().clamp(0, 255) - value;
        chromaV[index] = pixel.r.round().clamp(0, 255) - value;
        histogram[value]++;
        contentPixelCount++;
      }
    }
    if (contentPixelCount == 0) {
      throw const FormatException('Working image content is empty.');
    }

    final background = _percentile75(histogram, contentPixelCount);
    final global = Uint8List(width * height);
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        final index = y * width + x;
        global[index] = math.max(0, background - luminance[index]);
      }
    }
    final local = _localContrast(
      luminance,
      width: width,
      height: height,
      bounds: bounds,
    );
    final fusion = Uint8List(width * height);
    for (var index = 0; index < fusion.length; index++) {
      fusion[index] = math.max(global[index], local[index]);
    }

    return Lf3EvidenceFrame(
      width: width,
      height: height,
      contentBounds: bounds,
      globalBackgroundLuminance: background,
      luminance: luminance,
      globalContrast: global,
      localContrast: local,
      fusion: fusion,
      support: supportDetector.detect(
        luminance: luminance,
        chromaU: chromaU,
        chromaV: chromaV,
        width: width,
        height: height,
        bounds: bounds,
      ),
    );
  }

  static image.Image _decode(WorkingImage workingImage) {
    try {
      final decoded = switch (workingImage.workingMetadata.format) {
        VisionImageFormat.jpeg => image.decodeJpg(workingImage.bytes),
        VisionImageFormat.png => image.decodePng(workingImage.bytes),
      };
      if (decoded != null) return decoded;
    } on image.ImageException {
      throw const FormatException('Working image data could not be decoded.');
    } on RangeError {
      throw const FormatException('Working image data could not be decoded.');
    } on StateError {
      throw const FormatException('Working image data could not be decoded.');
    }
    throw const FormatException('Working image data could not be decoded.');
  }

  static int _percentile75(Uint32List histogram, int pixelCount) {
    final nearestRank = (pixelCount * 3 + 3) ~/ 4;
    var cumulative = 0;
    for (var value = 0; value < histogram.length; value++) {
      cumulative += histogram[value];
      if (cumulative >= nearestRank) return value;
    }
    throw StateError('Luminance histogram is empty.');
  }

  static Uint8List _localContrast(
    Uint8List luminance, {
    required int width,
    required int height,
    required Lf2PixelBounds bounds,
  }) {
    const radius = 8;
    final stride = width + 1;
    final integral = Int64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0;
      for (var x = 0; x < width; x++) {
        if (x >= bounds.left &&
            x < bounds.right &&
            y >= bounds.top &&
            y < bounds.bottom) {
          rowSum += luminance[y * width + x];
        }
        integral[(y + 1) * stride + x + 1] =
            integral[y * stride + x + 1] + rowSum;
      }
    }

    final result = Uint8List(width * height);
    for (var y = bounds.top; y < bounds.bottom; y++) {
      final top = math.max(bounds.top, y - radius);
      final bottom = math.min(bounds.bottom, y + radius + 1);
      for (var x = bounds.left; x < bounds.right; x++) {
        final left = math.max(bounds.left, x - radius);
        final right = math.min(bounds.right, x + radius + 1);
        final sum =
            integral[bottom * stride + right] -
            integral[top * stride + right] -
            integral[bottom * stride + left] +
            integral[top * stride + left];
        final count = (right - left) * (bottom - top);
        final mean = (sum + count ~/ 2) ~/ count;
        final index = y * width + x;
        result[index] = math.max(0, mean - luminance[index]);
      }
    }
    return result;
  }

  static Lf2PixelBounds _pixelBounds(
    VisionRect rect, {
    required int width,
    required int height,
  }) {
    final bounds = Lf2PixelBounds(
      left: (rect.left * width).round(),
      top: (rect.top * height).round(),
      right: (rect.right * width).round(),
      bottom: (rect.bottom * height).round(),
    );
    if (bounds.left < 0 ||
        bounds.top < 0 ||
        bounds.right > width ||
        bounds.bottom > height ||
        bounds.width <= 0 ||
        bounds.height <= 0) {
      throw ArgumentError.value(rect, 'contentRect', 'must map to pixels');
    }
    return bounds;
  }
}

final class Lf3SurfaceSupportDetector {
  const Lf3SurfaceSupportDetector();

  static const _centerOffsets = <double>[-0.12, -0.06, 0.0, 0.06, 0.12];
  static const _radiusRatios = <double>[0.30, 0.36, 0.42, 0.48];
  static const _verticalRatios = <double>[0.65, 0.80, 0.95, 1.0];
  static const _angleSamples = 64;

  Lf3SupportEvidence? detect({
    required Uint8List luminance,
    required Int16List chromaU,
    required Int16List chromaV,
    required int width,
    required int height,
    required Lf2PixelBounds bounds,
  }) {
    final expectedLength = width * height;
    if (luminance.length != expectedLength ||
        chromaU.length != expectedLength ||
        chromaV.length != expectedLength) {
      throw ArgumentError('LF-3 support evidence dimensions are inconsistent.');
    }
    _SupportCandidate? best;
    final minimumDimension = math.min(bounds.width, bounds.height);
    final baseCenterX = (bounds.left + bounds.right - 1) / 2;
    final baseCenterY = (bounds.top + bounds.bottom - 1) / 2;
    for (final offsetY in _centerOffsets) {
      for (final offsetX in _centerOffsets) {
        final centerX = baseCenterX + offsetX * bounds.width;
        final centerY = baseCenterY + offsetY * bounds.height;
        for (final radiusRatio in _radiusRatios) {
          final radiusX = minimumDimension * radiusRatio;
          for (final verticalRatio in _verticalRatios) {
            final radiusY = radiusX * verticalRatio;
            var visible = 0;
            var edges = 0;
            var contrastTotal = 0.0;
            for (var sample = 0; sample < _angleSamples; sample++) {
              final angle = math.pi * 2 * sample / _angleSamples;
              final cosValue = math.cos(angle);
              final sinValue = math.sin(angle);
              final innerX = (centerX + cosValue * radiusX * 0.90).round();
              final innerY = (centerY + sinValue * radiusY * 0.90).round();
              final outerX = (centerX + cosValue * radiusX * 1.05).round();
              final outerY = (centerY + sinValue * radiusY * 1.05).round();
              if (!_inside(innerX, innerY, bounds) ||
                  !_inside(outerX, outerY, bounds)) {
                continue;
              }
              visible++;
              final inner = innerY * width + innerX;
              final outer = outerY * width + outerX;
              final contrast =
                  (luminance[inner] - luminance[outer]).abs() +
                  (chromaU[inner] - chromaU[outer]).abs() * 0.32 +
                  (chromaV[inner] - chromaV[outer]).abs() * 0.32;
              if (contrast >= 12.0) {
                edges++;
                contrastTotal += contrast;
              }
            }
            if (visible < 56 || edges == 0) continue;
            final continuity = edges / visible;
            final meanContrast = contrastTotal / edges;
            if (continuity < 0.48 || meanContrast < 12.0) continue;
            final candidate = _SupportCandidate(
              centerX: centerX,
              centerY: centerY,
              radiusX: radiusX * 0.90,
              radiusY: radiusY * 0.90,
              visibleSampleCount: visible,
              edgeSampleCount: edges,
              edgeContinuity: continuity,
              meanBoundaryContrast: meanContrast,
            );
            if (best == null || _compare(candidate, best) < 0) best = candidate;
          }
        }
      }
    }
    if (best == null) return null;

    final pixels = Uint8List(expectedLength);
    for (var y = bounds.top; y < bounds.bottom; y++) {
      final normalizedY = (y + 0.5 - best.centerY) / best.radiusY;
      for (var x = bounds.left; x < bounds.right; x++) {
        final normalizedX = (x + 0.5 - best.centerX) / best.radiusX;
        if (normalizedX * normalizedX + normalizedY * normalizedY <= 1.0) {
          pixels[y * width + x] = 1;
        }
      }
    }
    return Lf3SupportEvidence(
      centerX: best.centerX / width,
      centerY: best.centerY / height,
      radiusX: best.radiusX / width,
      radiusY: best.radiusY / height,
      visibleSampleCount: best.visibleSampleCount,
      edgeSampleCount: best.edgeSampleCount,
      edgeContinuity: best.edgeContinuity,
      meanBoundaryContrast: best.meanBoundaryContrast,
      pixels: pixels,
    );
  }

  static bool _inside(int x, int y, Lf2PixelBounds bounds) =>
      x >= bounds.left &&
      x < bounds.right &&
      y >= bounds.top &&
      y < bounds.bottom;

  static int _compare(_SupportCandidate first, _SupportCandidate second) {
    var comparison = second.edgeContinuity.compareTo(first.edgeContinuity);
    if (comparison != 0) return comparison;
    comparison = second.meanBoundaryContrast.compareTo(
      first.meanBoundaryContrast,
    );
    if (comparison != 0) return comparison;
    comparison = (second.radiusX * second.radiusY).compareTo(
      first.radiusX * first.radiusY,
    );
    if (comparison != 0) return comparison;
    comparison = first.centerY.compareTo(second.centerY);
    if (comparison != 0) return comparison;
    return first.centerX.compareTo(second.centerX);
  }
}

final class Lf3MaskFactory {
  const Lf3MaskFactory();

  ResidueMask? create({
    required ResidueMask baseline,
    required Lf3EvidenceFrame evidence,
    required Lf3ProfileDefinition profile,
  }) {
    if (baseline.width != evidence.width ||
        baseline.height != evidence.height) {
      throw ArgumentError('LF-3 baseline and evidence dimensions differ.');
    }
    final support = evidence.support;
    if (profile.supportRequired && support == null) return null;
    final supportPixels = support?.pixels;
    final source = switch (profile.evidenceKind) {
      Lf3EvidenceKind.binary => baseline.pixels,
      _ => evidence.evidence(profile.evidenceKind),
    };
    final pixels = Uint8List(source.length);
    var pixelCount = 0;
    final threshold = profile.threshold;
    for (
      var y = evidence.contentBounds.top;
      y < evidence.contentBounds.bottom;
      y++
    ) {
      for (
        var x = evidence.contentBounds.left;
        x < evidence.contentBounds.right;
        x++
      ) {
        final index = y * evidence.width + x;
        final selected = profile.evidenceKind == Lf3EvidenceKind.binary
            ? source[index] != 0
            : source[index] >= threshold!;
        if (!selected ||
            (profile.supportRequired && supportPixels![index] == 0)) {
          continue;
        }
        pixels[index] = 1;
        pixelCount++;
      }
    }
    return ResidueMask(
      width: evidence.width,
      height: evidence.height,
      pixels: pixels,
      residueRatio: pixelCount / evidence.contentBounds.pixelCount,
    );
  }
}

final class _SupportCandidate {
  const _SupportCandidate({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
    required this.visibleSampleCount,
    required this.edgeSampleCount,
    required this.edgeContinuity,
    required this.meanBoundaryContrast,
  });

  final double centerX;
  final double centerY;
  final double radiusX;
  final double radiusY;
  final int visibleSampleCount;
  final int edgeSampleCount;
  final double edgeContinuity;
  final double meanBoundaryContrast;
}
