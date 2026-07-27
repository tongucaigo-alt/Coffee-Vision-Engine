import 'dart:typed_data';

enum VisionSurfaceType { cup, saucer }

final class VisionImageInput {
  VisionImageInput({
    required Uint8List imageBytes,
    required this.surfaceType,
    this.sourceId,
  }) : _imageBytes = _validatedCopy(imageBytes);

  final Uint8List _imageBytes;
  final VisionSurfaceType surfaceType;
  final String? sourceId;

  Uint8List get imageBytes => Uint8List.fromList(_imageBytes);

  static Uint8List _validatedCopy(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      throw ArgumentError.value(imageBytes, 'imageBytes', 'must not be empty');
    }
    return Uint8List.fromList(imageBytes);
  }
}
