import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../config/coffee_camera_config.dart';
import '../models/target_geometry.dart';
import '../models/preview_transform.dart';

class ProcessedCapture {
  const ProcessedCapture({
    required this.originalPath,
    required this.originalWidth,
    required this.originalHeight,
    required this.originalBytes,
    this.croppedPath,
    this.cropRect,
    this.croppedWidth,
    this.croppedHeight,
    this.croppedBytes,
  });

  final String originalPath;
  final int originalWidth;
  final int originalHeight;
  final int originalBytes;
  final String? croppedPath;
  final Rect? cropRect;
  final int? croppedWidth;
  final int? croppedHeight;
  final int? croppedBytes;
}

class CapturedImageProcessor {
  const CapturedImageProcessor();

  Future<ProcessedCapture> process({
    required String path,
    required Size viewportSize,
    required CoffeeCameraConfig config,
    Rect? normalizedCupBounds,
    Rect? normalizedSubjectBounds,
    bool previewMirrored = false,
    bool createCrop = true,
    TargetGeometry? targetGeometry,
    double? cropPaddingRatio,
    String cropFileSuffix = 'cup_crop',
  }) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final image = await _decode(bytes);
    try {
      if (!createCrop || viewportSize.isEmpty) {
        return ProcessedCapture(
          originalPath: path,
          originalWidth: image.width,
          originalHeight: image.height,
          originalBytes: bytes.length,
        );
      }

      final cropRect = _cropRect(
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        viewportSize: viewportSize,
        config: config,
        normalizedBounds: normalizedSubjectBounds ?? normalizedCupBounds,
        previewMirrored: previewMirrored,
        targetGeometry: targetGeometry,
        cropPaddingRatio: cropPaddingRatio,
      );
      final cropped = await _cropImage(image, cropRect);
      try {
        final pngData = await cropped.toByteData(
          format: ui.ImageByteFormat.png,
        );
        final pngBytes = pngData?.buffer.asUint8List();
        if (pngBytes == null) {
          return ProcessedCapture(
            originalPath: path,
            originalWidth: image.width,
            originalHeight: image.height,
            originalBytes: bytes.length,
          );
        }
        final cropPath = _cropPathFor(path, cropFileSuffix);
        await File(cropPath).writeAsBytes(pngBytes, flush: true);
        return ProcessedCapture(
          originalPath: path,
          originalWidth: image.width,
          originalHeight: image.height,
          originalBytes: bytes.length,
          croppedPath: cropPath,
          cropRect: cropRect,
          croppedWidth: cropped.width,
          croppedHeight: cropped.height,
          croppedBytes: pngBytes.length,
        );
      } finally {
        cropped.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Rect _cropRect({
    required Size imageSize,
    required Size viewportSize,
    required CoffeeCameraConfig config,
    Rect? normalizedBounds,
    required bool previewMirrored,
    TargetGeometry? targetGeometry,
    double? cropPaddingRatio,
  }) {
    final target =
        targetGeometry ?? TargetGeometry.fromViewport(viewportSize, config);
    Rect viewportBounds;
    if (normalizedBounds == null) {
      viewportBounds = target.bounds;
    } else {
      var bounds = normalizedBounds;
      if (previewMirrored) {
        bounds = Rect.fromLTRB(
          1 - bounds.right,
          bounds.top,
          1 - bounds.left,
          bounds.bottom,
        );
      }
      viewportBounds = Rect.fromLTRB(
        bounds.left * viewportSize.width,
        bounds.top * viewportSize.height,
        bounds.right * viewportSize.width,
        bounds.bottom * viewportSize.height,
      );
    }
    final padded = viewportBounds.inflate(
      math.min(viewportBounds.width, viewportBounds.height) *
          (cropPaddingRatio ?? config.cropPaddingRatio) /
          2,
    );
    final transform = PreviewTransform.oriented(
      sourceSize: imageSize,
      viewportSize: viewportSize,
    );
    return transform.viewportRectToSource(padded);
  }

  Future<ui.Image> _cropImage(ui.Image image, Rect cropRect) async {
    final width = math.max(1, cropRect.width.round());
    final height = math.max(1, cropRect.height.round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final outputRect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawImageRect(image, cropRect, outputRect, Paint());
    final picture = recorder.endRecording();
    try {
      return picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  String _cropPathFor(String originalPath, String suffix) {
    final separator = Platform.pathSeparator;
    final file = File(originalPath);
    final parent = file.parent.path;
    final name = file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    return '$parent$separator${stem}_$suffix.png';
  }
}
