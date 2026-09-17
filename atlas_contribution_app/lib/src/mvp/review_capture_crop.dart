import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../photo_crop.dart';

List<int> _orientedDimensions(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('Camera crop source is unreadable');
  }
  final oriented = img.bakeOrientation(decoded);
  return [oriented.width, oriented.height];
}

/// Carries the approved camera viewport onto the orientation-baked full photo.
/// The camera has already mapped preview mirroring into [capture.cropRect].
/// Applying EXIF rotation or mirroring again here would move the user's marks.
Future<PhotoCrop?> reviewCaptureCrop(
  Uint8List source,
  CameraCaptureResult capture, {
  required int photoWidth,
  required int photoHeight,
}) async {
  final rect = capture.cropRect;
  if (rect == null && capture.croppedImagePath == null) return null;
  if (rect == null || capture.croppedImagePath == null) {
    throw const FormatException('Incomplete camera crop metadata');
  }
  if (source.length != capture.fileSizeBytes ||
      photoWidth <= 0 ||
      photoHeight <= 0 ||
      ![
        rect.left,
        rect.top,
        rect.width,
        rect.height,
      ].every((v) => v.isFinite) ||
      rect.isEmpty ||
      rect.left < 0 ||
      rect.top < 0) {
    throw const FormatException('Invalid camera crop metadata');
  }

  final oriented = await compute(_orientedDimensions, source);
  final codec = await ui.instantiateImageCodec(source);
  late int sourceWidth;
  late int sourceHeight;
  try {
    final frame = await codec.getNextFrame();
    try {
      sourceWidth = frame.image.width;
      sourceHeight = frame.image.height;
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }

  // Both the preview's decoder and persisted photo's decoder must describe the
  // same oriented image. Persisted dimensions may differ by resize rounding.
  final sameAspect =
      (photoWidth * sourceHeight - photoHeight * sourceWidth).abs() <=
      (sourceWidth > sourceHeight ? sourceWidth : sourceHeight);
  if (sourceWidth != capture.widthPixels ||
      sourceHeight != capture.heightPixels ||
      sourceWidth != oriented[0] ||
      sourceHeight != oriented[1] ||
      photoWidth > sourceWidth ||
      photoHeight > sourceHeight ||
      !sameAspect ||
      rect.right > sourceWidth ||
      rect.bottom > sourceHeight ||
      (capture.croppedWidthPixels != null &&
          capture.croppedWidthPixels != math.max(1, rect.width.round())) ||
      (capture.croppedHeightPixels != null &&
          capture.croppedHeightPixels != math.max(1, rect.height.round()))) {
    throw const FormatException('Camera crop coordinate frame mismatch');
  }

  final x = rect.left / sourceWidth;
  final y = rect.top / sourceHeight;
  // The pixel bounds are valid; independently normalized values can still sum
  // to 1 + one floating-point rounding unit at the right or bottom edge.
  return PhotoCrop(
    x,
    y,
    math.min(rect.width / sourceWidth, 1 - x),
    math.min(rect.height / sourceHeight, 1 - y),
  );
}
