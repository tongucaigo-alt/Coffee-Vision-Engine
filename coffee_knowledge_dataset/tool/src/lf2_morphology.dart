import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';

import 'lf2_models.dart';
import 'lf2_profiles.dart';

/// Deterministic LF-2 morphology over one immutable public Vision mask.
final class Lf2MorphologyExtractor {
  const Lf2MorphologyExtractor();

  Lf2ExtractionResult extract({
    required String profileId,
    required String sourceId,
    required ResidueMask mask,
    required VisionRect contentRect,
    required Lf2ProfileDefinition profile,
  }) {
    if (profileId != profile.id) {
      throw ArgumentError.value(
        profileId,
        'profileId',
        'must equal profile.id',
      );
    }
    if (sourceId.isEmpty || sourceId.trim() != sourceId) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must be exact');
    }
    if (profile.closingRadius <= 0) {
      throw ArgumentError.value(
        profile.closingRadius,
        'profile.closingRadius',
        'must be positive',
      );
    }
    if (!profile.minimumRegionRatio.isFinite ||
        profile.minimumRegionRatio <= 0.0 ||
        profile.minimumRegionRatio > 1.0) {
      throw ArgumentError.value(
        profile.minimumRegionRatio,
        'profile.minimumRegionRatio',
        'must be finite and in (0.0, 1.0]',
      );
    }

    final bounds = _pixelBounds(
      contentRect,
      width: mask.width,
      height: mask.height,
    );
    final original = mask.pixels;
    final closed = _close(
      original,
      width: mask.width,
      height: mask.height,
      bounds: bounds,
      radius: profile.closingRadius,
    );
    final supports = _components(closed, width: mask.width, bounds: bounds);
    final supportLabels = Int32List(mask.width * mask.height);
    supportLabels.fillRange(0, supportLabels.length, -1);
    for (var supportIndex = 0; supportIndex < supports.length; supportIndex++) {
      for (final pixel in supports[supportIndex]) {
        supportLabels[pixel] = supportIndex;
      }
    }

    final originalBySupport = <List<int>>[
      for (var index = 0; index < supports.length; index++) <int>[],
    ];
    var originalResiduePixelCount = 0;
    var assignedResiduePixelCount = 0;
    var duplicateResidueAssignmentCount = 0;
    final assignments = Uint8List(original.length);
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        final pixel = y * mask.width + x;
        if (original[pixel] == 0) continue;
        originalResiduePixelCount++;
        final supportIndex = supportLabels[pixel];
        if (supportIndex < 0) continue;
        if (assignments[pixel] != 0) {
          duplicateResidueAssignmentCount++;
          continue;
        }
        assignments[pixel] = 1;
        assignedResiduePixelCount++;
        originalBySupport[supportIndex].add(pixel);
      }
    }

    final candidates = <_CandidateDraft>[];
    var emittedResiduePixelCount = 0;
    var suppressedResiduePixelCount = 0;
    for (var supportIndex = 0; supportIndex < supports.length; supportIndex++) {
      final supportId = supportIndex + 1;
      final supportIdentity = '$profileId#$sourceId#support#$supportId';
      final residuePixels = originalBySupport[supportIndex];
      final residueRatio = residuePixels.length / bounds.pixelCount;
      if (residuePixels.isNotEmpty &&
          residueRatio >= profile.minimumRegionRatio) {
        emittedResiduePixelCount += residuePixels.length;
        candidates.add(
          _draft(
            polarity: Lf2Polarity.residue,
            supportIdentity: supportIdentity,
            pixels: residuePixels,
            width: mask.width,
            height: mask.height,
            contentPixelCount: bounds.pixelCount,
            residueContactSectorCount: 0,
          ),
        );
      } else {
        suppressedResiduePixelCount += residuePixels.length;
      }

      final negativePixels = Uint8List(original.length);
      for (final pixel in supports[supportIndex]) {
        if (original[pixel] == 0) negativePixels[pixel] = 1;
      }
      final negativeComponents = _components(
        negativePixels,
        width: mask.width,
        bounds: bounds,
      );
      for (final pixels in negativeComponents) {
        if (pixels.length / bounds.pixelCount < profile.minimumRegionRatio ||
            _touchesBoundary(pixels, width: mask.width, bounds: bounds)) {
          continue;
        }
        final sectors = _residueContactSectors(
          pixels,
          original: original,
          supportLabels: supportLabels,
          supportIndex: supportIndex,
          width: mask.width,
          height: mask.height,
        );
        if (sectors < 2) continue;
        candidates.add(
          _draft(
            polarity: Lf2Polarity.negativeSpace,
            supportIdentity: supportIdentity,
            pixels: pixels,
            width: mask.width,
            height: mask.height,
            contentPixelCount: bounds.pixelCount,
            residueContactSectorCount: sectors,
          ),
        );
      }
    }

    candidates.sort((first, second) {
      final polarity = first.polarity.index.compareTo(second.polarity.index);
      if (polarity != 0) return polarity;
      return first.minimumRowMajorPixelIndex.compareTo(
        second.minimumRowMajorPixelIndex,
      );
    });
    final observations = <Lf2CandidateObservation>[];
    for (var index = 0; index < candidates.length; index++) {
      observations.add(candidates[index].toObservation(index + 1));
    }

    return Lf2ExtractionResult(
      candidates: observations,
      originalResiduePixelCount: originalResiduePixelCount,
      assignedResiduePixelCount: assignedResiduePixelCount,
      emittedResiduePixelCount: emittedResiduePixelCount,
      suppressedResiduePixelCount: suppressedResiduePixelCount,
      duplicateResidueAssignmentCount: duplicateResidueAssignmentCount,
    );
  }

  static Uint8List _close(
    Uint8List original, {
    required int width,
    required int height,
    required Lf2PixelBounds bounds,
    required int radius,
  }) {
    final radiusSquared = radius * radius;
    final distanceToResidue = _squaredDistanceToValue(
      original,
      value: 1,
      width: width,
      height: height,
    );
    final dilated = Uint8List(original.length);
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        final pixel = y * width + x;
        if (distanceToResidue[pixel] <= radiusSquared) dilated[pixel] = 1;
      }
    }

    final distanceToFalse = _squaredDistanceToValue(
      dilated,
      value: 0,
      width: width,
      height: height,
    );
    final closed = Uint8List(original.length);
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        final pixel = y * width + x;
        final outsideDistance = math.min(
          math.min(
            (x - bounds.left + 1) * (x - bounds.left + 1),
            (bounds.right - x) * (bounds.right - x),
          ),
          math.min(
            (y - bounds.top + 1) * (y - bounds.top + 1),
            (bounds.bottom - y) * (bounds.bottom - y),
          ),
        );
        final eroded =
            dilated[pixel] != 0 &&
            math.min(distanceToFalse[pixel], outsideDistance) > radiusSquared;
        if (original[pixel] != 0 || eroded) closed[pixel] = 1;
      }
    }
    return closed;
  }

  static Int32List _squaredDistanceToValue(
    Uint8List pixels, {
    required int value,
    required int width,
    required int height,
  }) {
    const infinity = 1 << 28;
    final vertical = Int32List(pixels.length);
    final input = Int32List(math.max(width, height));
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        input[y] = pixels[y * width + x] == value ? 0 : infinity;
      }
      final transformed = _distanceTransform1d(input, height, infinity);
      for (var y = 0; y < height; y++) {
        vertical[y * width + x] = transformed[y];
      }
    }

    final result = Int32List(pixels.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        input[x] = vertical[y * width + x];
      }
      final transformed = _distanceTransform1d(input, width, infinity);
      for (var x = 0; x < width; x++) {
        result[y * width + x] = transformed[x];
      }
    }
    return result;
  }

  static Int32List _distanceTransform1d(
    Int32List values,
    int length,
    int infinity,
  ) {
    final result = Int32List(length);
    var hasFeature = false;
    for (var index = 0; index < length; index++) {
      if (values[index] < infinity) {
        hasFeature = true;
        break;
      }
    }
    if (!hasFeature) {
      result.fillRange(0, length, infinity);
      return result;
    }

    final locations = Int32List(length);
    final boundaries = Float64List(length + 1);
    var envelopeIndex = 0;
    locations[0] = 0;
    boundaries[0] = double.negativeInfinity;
    boundaries[1] = double.infinity;
    for (var location = 1; location < length; location++) {
      var boundary = _intersection(values, location, locations[envelopeIndex]);
      while (boundary <= boundaries[envelopeIndex]) {
        envelopeIndex--;
        boundary = _intersection(values, location, locations[envelopeIndex]);
      }
      envelopeIndex++;
      locations[envelopeIndex] = location;
      boundaries[envelopeIndex] = boundary;
      boundaries[envelopeIndex + 1] = double.infinity;
    }

    envelopeIndex = 0;
    for (var location = 0; location < length; location++) {
      while (boundaries[envelopeIndex + 1] < location) {
        envelopeIndex++;
      }
      final delta = location - locations[envelopeIndex];
      final distance = delta * delta + values[locations[envelopeIndex]];
      result[location] = distance >= infinity ? infinity : distance;
    }
    return result;
  }

  static double _intersection(Int32List values, int first, int second) {
    return ((values[first] + first * first) -
            (values[second] + second * second)) /
        (2 * first - 2 * second);
  }

  static List<List<int>> _components(
    Uint8List pixels, {
    required int width,
    required Lf2PixelBounds bounds,
  }) {
    final visited = Uint8List(pixels.length);
    final components = <List<int>>[];
    for (var y = bounds.top; y < bounds.bottom; y++) {
      for (var x = bounds.left; x < bounds.right; x++) {
        final start = y * width + x;
        if (pixels[start] == 0 || visited[start] != 0) continue;
        final queue = <int>[start];
        visited[start] = 1;
        final component = <int>[];
        for (var cursor = 0; cursor < queue.length; cursor++) {
          final pixel = queue[cursor];
          component.add(pixel);
          final pixelX = pixel % width;
          final pixelY = pixel ~/ width;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final neighborX = pixelX + dx;
              final neighborY = pixelY + dy;
              if (neighborX < bounds.left ||
                  neighborX >= bounds.right ||
                  neighborY < bounds.top ||
                  neighborY >= bounds.bottom) {
                continue;
              }
              final neighbor = neighborY * width + neighborX;
              if (pixels[neighbor] == 0 || visited[neighbor] != 0) continue;
              visited[neighbor] = 1;
              queue.add(neighbor);
            }
          }
        }
        component.sort();
        components.add(component);
      }
    }
    return components;
  }

  static bool _touchesBoundary(
    List<int> pixels, {
    required int width,
    required Lf2PixelBounds bounds,
  }) {
    for (final pixel in pixels) {
      final x = pixel % width;
      final y = pixel ~/ width;
      if (x == bounds.left ||
          x == bounds.right - 1 ||
          y == bounds.top ||
          y == bounds.bottom - 1) {
        return true;
      }
    }
    return false;
  }

  static int _residueContactSectors(
    List<int> pixels, {
    required Uint8List original,
    required Int32List supportLabels,
    required int supportIndex,
    required int width,
    required int height,
  }) {
    const directions = [
      (-1, -1),
      (0, -1),
      (1, -1),
      (1, 0),
      (1, 1),
      (0, 1),
      (-1, 1),
      (-1, 0),
    ];
    final sectors = <int>{};
    for (final pixel in pixels) {
      final x = pixel % width;
      final y = pixel ~/ width;
      for (var sector = 0; sector < directions.length; sector++) {
        final direction = directions[sector];
        final neighborX = x + direction.$1;
        final neighborY = y + direction.$2;
        if (neighborX < 0 ||
            neighborX >= width ||
            neighborY < 0 ||
            neighborY >= height) {
          continue;
        }
        final neighbor = neighborY * width + neighborX;
        if (original[neighbor] != 0 &&
            supportLabels[neighbor] == supportIndex) {
          sectors.add(sector);
        }
      }
    }
    return sectors.length;
  }

  static _CandidateDraft _draft({
    required Lf2Polarity polarity,
    required String supportIdentity,
    required List<int> pixels,
    required int width,
    required int height,
    required int contentPixelCount,
    required int residueContactSectorCount,
  }) {
    var minimumX = width;
    var minimumY = height;
    var maximumX = -1;
    var maximumY = -1;
    var xTotal = 0.0;
    var yTotal = 0.0;
    for (final pixel in pixels) {
      final x = pixel % width;
      final y = pixel ~/ width;
      minimumX = math.min(minimumX, x);
      minimumY = math.min(minimumY, y);
      maximumX = math.max(maximumX, x);
      maximumY = math.max(maximumY, y);
      xTotal += x + 0.5;
      yTotal += y + 0.5;
    }
    return _CandidateDraft(
      polarity: polarity,
      supportIdentity: supportIdentity,
      minimumRowMajorPixelIndex: pixels.first,
      left: minimumX / width,
      top: minimumY / height,
      right: (maximumX + 1) / width,
      bottom: (maximumY + 1) / height,
      centroidX: xTotal / pixels.length / width,
      centroidY: yTotal / pixels.length / height,
      pixelCount: pixels.length,
      areaRatio: pixels.length / contentPixelCount,
      residueContactSectorCount: residueContactSectorCount,
      pixelFingerprint: _fingerprint(pixels),
    );
  }

  static String _fingerprint(List<int> pixels) {
    const mask = 0xffffffffffffffff;
    var hash = 0xcbf29ce484222325;
    for (final pixel in pixels) {
      hash ^= pixel;
      hash = (hash * 0x100000001b3) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
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

final class _CandidateDraft {
  const _CandidateDraft({
    required this.polarity,
    required this.supportIdentity,
    required this.minimumRowMajorPixelIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.centroidX,
    required this.centroidY,
    required this.pixelCount,
    required this.areaRatio,
    required this.residueContactSectorCount,
    required this.pixelFingerprint,
  });

  final Lf2Polarity polarity;
  final String supportIdentity;
  final int minimumRowMajorPixelIndex;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double centroidX;
  final double centroidY;
  final int pixelCount;
  final double areaRatio;
  final int residueContactSectorCount;
  final String pixelFingerprint;

  Lf2CandidateObservation toObservation(int candidateId) {
    return Lf2CandidateObservation(
      candidateId: candidateId,
      polarity: polarity,
      supportIdentity: supportIdentity,
      minimumRowMajorPixelIndex: minimumRowMajorPixelIndex,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      centroidX: centroidX,
      centroidY: centroidY,
      pixelCount: pixelCount,
      areaRatio: areaRatio,
      residueContactSectorCount: residueContactSectorCount,
      pixelFingerprint: pixelFingerprint,
    );
  }
}
