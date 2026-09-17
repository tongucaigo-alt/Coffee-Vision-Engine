import 'package:flutter/material.dart';

import 'photo_crop.dart';

/// Shows a display crop without changing the stored image or its coordinates.
class CroppedPhoto extends StatelessWidget {
  const CroppedPhoto({
    required this.image,
    required this.photoWidth,
    required this.photoHeight,
    this.crop,
    this.semanticLabel,
    this.errorBuilder,
    super.key,
  });

  final ImageProvider image;
  final int photoWidth, photoHeight;
  final PhotoCrop? crop;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;

  double get aspectRatio =>
      (crop ?? PhotoCrop.full).aspectRatio(photoWidth, photoHeight);

  @override
  Widget build(BuildContext context) {
    final bounds = crop ?? PhotoCrop.full;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullWidth = constraints.maxWidth / bounds.width;
          final fullHeight = constraints.maxHeight / bounds.height;
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -bounds.x * fullWidth,
                  top: -bounds.y * fullHeight,
                  width: fullWidth,
                  height: fullHeight,
                  child: Image(
                    image: image,
                    fit: BoxFit.fill,
                    semanticLabel: semanticLabel,
                    errorBuilder: errorBuilder,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
