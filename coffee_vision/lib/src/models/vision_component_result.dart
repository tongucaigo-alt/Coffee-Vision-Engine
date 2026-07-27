import 'vision_component.dart';

/// Deterministic connected-component output for one residue mask.
final class VisionComponentResult {
  factory VisionComponentResult({
    required ({int width, int height}) imageSize,
    required int totalResiduePixels,
    required Iterable<VisionComponent> components,
  }) {
    if (imageSize.width <= 0) {
      throw ArgumentError.value(
        imageSize.width,
        'imageSize.width',
        'must be greater than zero',
      );
    }
    if (imageSize.height <= 0) {
      throw ArgumentError.value(
        imageSize.height,
        'imageSize.height',
        'must be greater than zero',
      );
    }
    if (totalResiduePixels < 0) {
      throw ArgumentError.value(
        totalResiduePixels,
        'totalResiduePixels',
        'must not be negative',
      );
    }

    final componentList = List<VisionComponent>.unmodifiable(components);
    final componentPixelTotal = componentList.fold<int>(
      0,
      (total, component) => total + component.pixelCount,
    );
    if (componentPixelTotal != totalResiduePixels) {
      throw ArgumentError.value(
        totalResiduePixels,
        'totalResiduePixels',
        'must equal the sum of component pixel counts ($componentPixelTotal)',
      );
    }

    return VisionComponentResult._(
      imageSize: imageSize,
      totalResiduePixels: totalResiduePixels,
      components: componentList,
    );
  }

  VisionComponentResult._({
    required this.imageSize,
    required this.totalResiduePixels,
    required this.components,
  }) : componentCount = components.length;

  final ({int width, int height}) imageSize;
  final int componentCount;
  final int totalResiduePixels;
  final List<VisionComponent> components;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionComponentResult &&
            other.imageSize == imageSize &&
            other.totalResiduePixels == totalResiduePixels &&
            _sameComponents(other.components, components);
  }

  @override
  int get hashCode =>
      Object.hash(imageSize, totalResiduePixels, Object.hashAll(components));

  @override
  String toString() {
    return 'VisionComponentResult(imageSize: $imageSize, '
        'componentCount: $componentCount, '
        'totalResiduePixels: $totalResiduePixels)';
  }

  static bool _sameComponents(
    List<VisionComponent> first,
    List<VisionComponent> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
