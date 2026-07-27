import 'vision_image_input.dart';
import 'vision_image_metadata.dart';

final class VisionObservation {
  VisionObservation({
    required this.surfaceType,
    required double confidence,
    required List<String> notes,
    required this.imageMetadata,
  }) : confidence = _validatedConfidence(confidence),
       notes = List.unmodifiable(notes);

  final VisionSurfaceType surfaceType;
  final double confidence;
  final List<String> notes;
  final VisionImageMetadata imageMetadata;

  static double _validatedConfidence(double confidence) {
    if (!confidence.isFinite || confidence < 0.0 || confidence > 1.0) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be between 0.0 and 1.0',
      );
    }
    return confidence;
  }
}
