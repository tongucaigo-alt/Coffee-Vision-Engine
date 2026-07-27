import 'dart:typed_data';

import 'vision_geometry.dart';

/// One 8-connected group of residue pixels.
///
/// [pixels] contains row-major indices where `index = y * imageWidth + x`.
/// The detector stores these indices in ascending order, independent of its
/// internal breadth-first neighbor traversal order.
final class VisionComponent {
  factory VisionComponent({
    required int id,
    required Iterable<int> pixels,
    required VisionRect boundingBox,
    required VisionPoint centroid,
    required double areaRatio,
  }) {
    return _create(
      id: id,
      pixels: pixels,
      boundingBox: boundingBox,
      centroid: centroid,
      areaRatio: areaRatio,
    );
  }

  /// Creates a component with features requiring exact image dimensions.
  ///
  /// This factory is intended for the connected-component production path.
  factory VisionComponent.fromDetection({
    required int id,
    required Iterable<int> pixels,
    required VisionRect boundingBox,
    required VisionPoint centroid,
    required double areaRatio,
    required int imageWidth,
    required int imageHeight,
  }) {
    return _create(
      id: id,
      pixels: pixels,
      boundingBox: boundingBox,
      centroid: centroid,
      areaRatio: areaRatio,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  static VisionComponent _create({
    required int id,
    required Iterable<int> pixels,
    required VisionRect boundingBox,
    required VisionPoint centroid,
    required double areaRatio,
    int? imageWidth,
    int? imageHeight,
  }) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be greater than zero');
    }
    if (!areaRatio.isFinite || areaRatio <= 0.0 || areaRatio > 1.0) {
      throw ArgumentError.value(
        areaRatio,
        'areaRatio',
        'must be finite, greater than 0.0, and at most 1.0',
      );
    }
    if (boundingBox.width <= 0.0 || boundingBox.height <= 0.0) {
      throw ArgumentError.value(
        boundingBox,
        'boundingBox',
        'must have positive width and height',
      );
    }
    if (!boundingBox.contains(centroid)) {
      throw ArgumentError.value(
        centroid,
        'centroid',
        'must be inside boundingBox',
      );
    }
    if (imageWidth != null && imageWidth <= 0) {
      throw ArgumentError.value(
        imageWidth,
        'imageWidth',
        'must be greater than zero',
      );
    }
    if (imageHeight != null && imageHeight <= 0) {
      throw ArgumentError.value(
        imageHeight,
        'imageHeight',
        'must be greater than zero',
      );
    }

    final pixelValues = pixels.toList(growable: false);
    if (pixelValues.isEmpty) {
      throw ArgumentError.value(pixels, 'pixels', 'must not be empty');
    }
    final uniquePixels = <int>{};
    var minX = imageWidth;
    var minY = imageHeight;
    var maxX = -1;
    var maxY = -1;
    for (final pixel in pixelValues) {
      if (pixel < 0) {
        throw ArgumentError.value(
          pixel,
          'pixels',
          'must contain only non-negative indices',
        );
      }
      if (!uniquePixels.add(pixel)) {
        throw ArgumentError.value(
          pixel,
          'pixels',
          'must not contain duplicate indices',
        );
      }
      if (imageWidth != null && imageHeight != null) {
        final imagePixelCount = imageWidth * imageHeight;
        if (pixel >= imagePixelCount) {
          throw ArgumentError.value(
            pixel,
            'pixels',
            'must map inside the supplied image dimensions',
          );
        }
        final x = pixel % imageWidth;
        final y = pixel ~/ imageWidth;
        if (x < minX!) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY!) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    double? fillRatio;
    bool? touchesBorder;
    if (imageWidth != null && imageHeight != null) {
      final boundingBoxPixelArea = (maxX - minX! + 1) * (maxY - minY! + 1);
      fillRatio = pixelValues.length / boundingBoxPixelArea;
      touchesBorder =
          minX == 0 ||
          maxX == imageWidth - 1 ||
          minY == 0 ||
          maxY == imageHeight - 1;
    }

    return VisionComponent._(
      id: id,
      pixels: Uint32List.fromList(pixelValues),
      boundingBox: boundingBox,
      centroid: centroid,
      areaRatio: areaRatio,
      fillRatio: fillRatio,
      touchesBorder: touchesBorder,
    );
  }

  VisionComponent._({
    required this.id,
    required Uint32List pixels,
    required this.boundingBox,
    required this.centroid,
    required this.areaRatio,
    required double? fillRatio,
    required bool? touchesBorder,
  }) : _pixels = pixels,
       pixelCount = pixels.length,
       width = boundingBox.width,
       height = boundingBox.height,
       aspectRatio = boundingBox.width / boundingBox.height,
       _fillRatio = fillRatio,
       _touchesBorder = touchesBorder;

  final int id;
  final int pixelCount;
  final VisionRect boundingBox;
  final VisionPoint centroid;
  final double areaRatio;
  final double width;
  final double height;
  final double aspectRatio;
  final Uint32List _pixels;
  final double? _fillRatio;
  final bool? _touchesBorder;

  Uint32List get pixels => Uint32List.fromList(_pixels);

  double get fillRatio {
    return _fillRatio ??
        (throw StateError(
          'fillRatio is unavailable for a VisionComponent created without '
          'image dimensions. Use VisionComponent.fromDetection.',
        ));
  }

  bool get touchesBorder {
    return _touchesBorder ??
        (throw StateError(
          'touchesBorder is unavailable for a VisionComponent created '
          'without image dimensions. Use VisionComponent.fromDetection.',
        ));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionComponent &&
            other.id == id &&
            other.boundingBox == boundingBox &&
            other.centroid == centroid &&
            other.areaRatio == areaRatio &&
            other._fillRatio == _fillRatio &&
            other._touchesBorder == _touchesBorder &&
            _samePixels(other._pixels, _pixels);
  }

  @override
  int get hashCode => Object.hash(
    id,
    boundingBox,
    centroid,
    areaRatio,
    _fillRatio,
    _touchesBorder,
    Object.hashAll(_pixels),
  );

  @override
  String toString() {
    return 'VisionComponent(id: $id, pixelCount: $pixelCount, '
        'boundingBox: $boundingBox, centroid: $centroid, '
        'areaRatio: $areaRatio)';
  }

  static bool _samePixels(Uint32List first, Uint32List second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
