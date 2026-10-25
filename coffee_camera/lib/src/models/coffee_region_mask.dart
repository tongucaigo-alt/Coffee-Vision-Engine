import 'dart:typed_data';
import 'dart:ui';

class CoffeeRegionMask {
  CoffeeRegionMask({
    required this.normalizedBounds,
    required this.width,
    required this.height,
    required Uint8List intensities,
    required this.coverage,
    this.requiresStrictPhotoVerification = false,
  }) : assert(intensities.length == width * height),
       intensities = Uint8List.fromList(intensities);

  final Rect normalizedBounds;
  final int width;
  final int height;
  final Uint8List intensities;
  final double coverage;

  /// Dense, textured grounds can be drawn without relaxing the host's final
  /// photo filter. Such masks must not supply the legacy acceptance evidence.
  final bool requiresStrictPhotoVerification;

  int get activeCellCount => intensities.where((value) => value > 0).length;

  int intensityAt(int column, int row) => intensities[row * width + column];

  Offset normalizedPointFor(int column, int row) {
    return Offset(
      normalizedBounds.left + normalizedBounds.width * ((column + 0.5) / width),
      normalizedBounds.top + normalizedBounds.height * ((row + 0.5) / height),
    );
  }
}
