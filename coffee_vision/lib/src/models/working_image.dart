import 'dart:typed_data';

import 'vision_geometry.dart';
import 'vision_image_metadata.dart';

/// Square, padded image data prepared for Coffee Vision processing.
///
/// [metadata] remains a backward-compatible alias for [workingMetadata]. The
/// factory always supplies the original [sourceMetadata], output
/// [workingMetadata], and the real normalized [contentRect]. Legacy callers
/// that only provide [metadata] get a full-frame content rectangle and use the
/// same metadata for both source and working values.
final class WorkingImage {
  WorkingImage({
    required Uint8List bytes,
    required VisionImageMetadata metadata,
    VisionImageMetadata? sourceMetadata,
    VisionImageMetadata? workingMetadata,
    VisionRect? contentRect,
    required int resolution,
  }) : _bytes = _validatedCopy(bytes),
       sourceMetadata = sourceMetadata ?? metadata,
       workingMetadata = workingMetadata ?? metadata,
       contentRect =
           contentRect ??
           VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
       resolution = _validatedResolution(resolution);

  final Uint8List _bytes;
  final VisionImageMetadata sourceMetadata;
  final VisionImageMetadata workingMetadata;
  final VisionRect contentRect;
  final int resolution;

  /// Backward-compatible access to the produced working-image metadata.
  VisionImageMetadata get metadata => workingMetadata;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkingImage &&
            other.resolution == resolution &&
            _sameMetadata(other.sourceMetadata, sourceMetadata) &&
            _sameMetadata(other.workingMetadata, workingMetadata) &&
            other.contentRect == contentRect &&
            _sameBytes(other._bytes, _bytes);
  }

  @override
  int get hashCode => Object.hash(
    sourceMetadata.format,
    sourceMetadata.width,
    sourceMetadata.height,
    workingMetadata.format,
    workingMetadata.width,
    workingMetadata.height,
    contentRect,
    resolution,
    Object.hashAll(_bytes),
  );

  static Uint8List _validatedCopy(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }
    return Uint8List.fromList(bytes);
  }

  static int _validatedResolution(int resolution) {
    if (resolution <= 0) {
      throw ArgumentError.value(
        resolution,
        'resolution',
        'must be greater than zero',
      );
    }
    return resolution;
  }

  static bool _sameMetadata(
    VisionImageMetadata first,
    VisionImageMetadata second,
  ) {
    return first.format == second.format &&
        first.width == second.width &&
        first.height == second.height;
  }

  static bool _sameBytes(Uint8List first, Uint8List second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
