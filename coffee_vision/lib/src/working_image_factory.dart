import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'adaptive_padding_color_calculator.dart';
import 'config/vision_config.dart';
import 'image_metadata_parser.dart';
import 'image_resizer.dart';
import 'models/vision_geometry.dart';
import 'models/vision_image_input.dart';
import 'models/vision_image_metadata.dart';
import 'models/working_image.dart';

final class WorkingImageFactory {
  const WorkingImageFactory({required this.config});

  final VisionConfig config;

  WorkingImage create(VisionImageInput input) {
    final sourceBytes = input.imageBytes;
    final sourceMetadata = parseImageMetadata(sourceBytes);
    final decodedImage = _decode(sourceBytes, sourceMetadata.format);
    final processingImage = image
        .bakeOrientation(decodedImage)
        .convert(
          format: image.Format.uint8,
          numChannels: 4,
          withPalette: false,
          noAnimation: true,
        );
    final paddingColor = const AdaptivePaddingColorCalculator().calculate(
      processingImage,
    );
    final resizedImage = const ImageResizer().resize(
      decodedImage: processingImage,
      resolution: config.workingResolution,
    );
    final left = (config.workingResolution - resizedImage.width) ~/ 2;
    final top = (config.workingResolution - resizedImage.height) ~/ 2;
    final workingCanvas = image.Image(
      width: config.workingResolution,
      height: config.workingResolution,
      format: image.Format.uint8,
      numChannels: 4,
    )..clear(paddingColor);
    image.compositeImage(
      workingCanvas,
      resizedImage,
      dstX: left,
      dstY: top,
      blend: image.BlendMode.direct,
    );

    final workingBytes = _encode(workingCanvas, sourceMetadata.format);
    final workingMetadata = parseImageMetadata(workingBytes);
    final resolution = config.workingResolution.toDouble();
    final contentRect = VisionRect(
      left: left / resolution,
      top: top / resolution,
      right: (left + resizedImage.width) / resolution,
      bottom: (top + resizedImage.height) / resolution,
    );

    return WorkingImage(
      bytes: workingBytes,
      metadata: workingMetadata,
      sourceMetadata: sourceMetadata,
      workingMetadata: workingMetadata,
      contentRect: contentRect,
      resolution: config.workingResolution,
    );
  }

  Uint8List _encode(image.Image workingImage, VisionImageFormat format) {
    return switch (format) {
      VisionImageFormat.jpeg => image.encodeJpg(workingImage, quality: 100),
      VisionImageFormat.png => image.encodePng(workingImage),
    };
  }

  image.Image _decode(Uint8List bytes, VisionImageFormat format) {
    try {
      final decoded = switch (format) {
        VisionImageFormat.jpeg => image.decodeJpg(bytes),
        VisionImageFormat.png => image.decodePng(bytes),
      };
      if (decoded != null) return decoded;
    } on image.ImageException {
      throw FormatException(
        'Corrupt ${_formatName(format)}: image data could not be decoded.',
      );
    } on RangeError {
      throw FormatException(
        'Corrupt ${_formatName(format)}: image data could not be decoded.',
      );
    } on StateError {
      throw FormatException(
        'Corrupt ${_formatName(format)}: image data could not be decoded.',
      );
    }

    throw FormatException(
      'Corrupt ${_formatName(format)}: image data could not be decoded.',
    );
  }

  String _formatName(VisionImageFormat format) {
    return switch (format) {
      VisionImageFormat.jpeg => 'JPEG',
      VisionImageFormat.png => 'PNG',
    };
  }
}
