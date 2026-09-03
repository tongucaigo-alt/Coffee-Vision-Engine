import 'dart:io';

import 'package:flutter/material.dart';

import '../config/coffee_camera_config.dart';

class PhotoPreview extends StatelessWidget {
  const PhotoPreview({
    super.key,
    required this.filePath,
    required this.config,
    required this.onRetake,
    required this.onApprove,
    this.title,
    this.onBack,
  });

  final String filePath;
  final CoffeeCameraConfig config;
  final VoidCallback onRetake;
  final VoidCallback onApprove;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: config.theme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
          if (title != null || onBack != null)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (title case final value?)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 52),
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: config.theme.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      if (onBack case final callback?)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Geri',
                            onPressed: callback,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0x66000000),
                              foregroundColor: config.theme.foreground,
                              fixedSize: const Size.square(44),
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetake,
                      icon: const Icon(Icons.refresh),
                      label: Text(config.strings.retake),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: Text(config.strings.approve),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
