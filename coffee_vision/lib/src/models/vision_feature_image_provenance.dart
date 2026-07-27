import 'vision_geometry.dart';
import 'vision_image_metadata.dart';

/// Immutable image provenance for a [VisionFeatureSet].
///
/// This model records only physical source and working-image metadata. It does
/// not contain quality, confidence, semantic, symbol, or fortune information.
final class VisionFeatureImageProvenance {
  VisionFeatureImageProvenance({
    required this.sourceFormat,
    required int sourceWidth,
    required int sourceHeight,
    required this.workingFormat,
    required int workingWidth,
    required int workingHeight,
    required int workingResolution,
    required VisionRect contentRect,
  }) : sourceWidth = _validatedPositive(sourceWidth, 'sourceWidth'),
       sourceHeight = _validatedPositive(sourceHeight, 'sourceHeight'),
       workingWidth = _validatedPositive(workingWidth, 'workingWidth'),
       workingHeight = _validatedPositive(workingHeight, 'workingHeight'),
       workingResolution = _validatedPositive(
         workingResolution,
         'workingResolution',
       ),
       contentRect = _validatedContentRect(contentRect) {
    if (workingWidth != workingResolution ||
        workingHeight != workingResolution) {
      throw ArgumentError(
        'workingWidth and workingHeight must equal workingResolution.',
      );
    }
  }

  final VisionImageFormat sourceFormat;
  final int sourceWidth;
  final int sourceHeight;
  final VisionImageFormat workingFormat;
  final int workingWidth;
  final int workingHeight;
  final int workingResolution;
  final VisionRect contentRect;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionFeatureImageProvenance &&
            other.sourceFormat == sourceFormat &&
            other.sourceWidth == sourceWidth &&
            other.sourceHeight == sourceHeight &&
            other.workingFormat == workingFormat &&
            other.workingWidth == workingWidth &&
            other.workingHeight == workingHeight &&
            other.workingResolution == workingResolution &&
            other.contentRect == contentRect;
  }

  @override
  int get hashCode => Object.hash(
    sourceFormat,
    sourceWidth,
    sourceHeight,
    workingFormat,
    workingWidth,
    workingHeight,
    workingResolution,
    contentRect,
  );

  @override
  String toString() {
    return 'VisionFeatureImageProvenance('
        'sourceFormat: $sourceFormat, '
        'sourceSize: ${sourceWidth}x$sourceHeight, '
        'workingFormat: $workingFormat, '
        'workingSize: ${workingWidth}x$workingHeight, '
        'workingResolution: $workingResolution, '
        'contentRect: $contentRect)';
  }

  static int _validatedPositive(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
    return value;
  }

  static VisionRect _validatedContentRect(VisionRect value) {
    if (value.width <= 0.0 || value.height <= 0.0) {
      throw ArgumentError.value(
        value,
        'contentRect',
        'must have positive width and height',
      );
    }
    return value;
  }
}
