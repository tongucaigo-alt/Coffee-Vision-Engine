import 'dart:typed_data';
import 'dart:ui';

class ResidueRegionMask {
  ResidueRegionMask({
    required this.normalizedBounds,
    required this.width,
    required this.height,
    required List<int> intensities,
    required this.coverage,
    required this.residueBounds,
    required this.componentCount,
  }) : assert(intensities.length == width * height),
       intensities = Uint8List.fromList(intensities);

  final Rect normalizedBounds;
  final int width;
  final int height;
  final Uint8List intensities;
  final double coverage;
  final Rect? residueBounds;
  final int componentCount;

  int get activeCellCount => intensities.where((value) => value > 0).length;

  int intensityAt(int column, int row) => intensities[row * width + column];
}
