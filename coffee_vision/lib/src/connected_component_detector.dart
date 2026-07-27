import 'dart:collection';
import 'dart:typed_data';

import 'models/residue_mask.dart';
import 'models/vision_component.dart';
import 'models/vision_component_result.dart';
import 'models/vision_geometry.dart';

/// Finds every 8-connected residue component without filtering.
final class ConnectedComponentDetector {
  const ConnectedComponentDetector();

  VisionComponentResult detect(ResidueMask mask) {
    final width = mask.width;
    final height = mask.height;
    final pixels = mask.pixels;
    final visited = Uint8List(pixels.length);
    final components = <VisionComponent>[];

    for (var startIndex = 0; startIndex < pixels.length; startIndex++) {
      if (pixels[startIndex] == 0 || visited[startIndex] != 0) continue;

      final queue = ListQueue<int>()..add(startIndex);
      visited[startIndex] = 1;
      final componentPixels = <int>[];
      var minX = width;
      var minY = height;
      var maxX = -1;
      var maxY = -1;
      var sumX = 0;
      var sumY = 0;

      while (queue.isNotEmpty) {
        final index = queue.removeFirst();
        final x = index % width;
        final y = index ~/ width;
        componentPixels.add(index);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        sumX += x;
        sumY += y;

        for (var deltaY = -1; deltaY <= 1; deltaY++) {
          for (var deltaX = -1; deltaX <= 1; deltaX++) {
            if (deltaX == 0 && deltaY == 0) continue;
            final neighborX = x + deltaX;
            final neighborY = y + deltaY;
            if (neighborX < 0 ||
                neighborX >= width ||
                neighborY < 0 ||
                neighborY >= height) {
              continue;
            }

            final neighborIndex = neighborY * width + neighborX;
            if (pixels[neighborIndex] == 0 || visited[neighborIndex] != 0) {
              continue;
            }
            visited[neighborIndex] = 1;
            queue.add(neighborIndex);
          }
        }
      }

      componentPixels.sort();
      final pixelCount = componentPixels.length;
      components.add(
        VisionComponent.fromDetection(
          id: components.length + 1,
          pixels: componentPixels,
          boundingBox: VisionRect(
            left: minX / width,
            top: minY / height,
            right: (maxX + 1) / width,
            bottom: (maxY + 1) / height,
          ),
          centroid: VisionPoint(
            x: (sumX + pixelCount * 0.5) / (pixelCount * width),
            y: (sumY + pixelCount * 0.5) / (pixelCount * height),
          ),
          areaRatio: pixelCount / pixels.length,
          imageWidth: width,
          imageHeight: height,
        ),
      );
    }

    final detectedResiduePixels = components.fold<int>(
      0,
      (total, component) => total + component.pixelCount,
    );
    if (detectedResiduePixels != mask.residuePixelCount) {
      throw StateError(
        'Connected components contain $detectedResiduePixels residue pixels, '
        'but the mask reports ${mask.residuePixelCount}.',
      );
    }

    return VisionComponentResult(
      imageSize: (width: width, height: height),
      totalResiduePixels: mask.residuePixelCount,
      components: components,
    );
  }
}
