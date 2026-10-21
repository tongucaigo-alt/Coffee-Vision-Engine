import 'package:flutter/material.dart';

import '../config/coffee_camera_config.dart';
import '../models/target_geometry.dart';
import 'camera_focus_region.dart';

/// A static, non-interactive decoration using the exact existing focus cutout.
class CameraBrandWatermark extends StatelessWidget {
  const CameraBrandWatermark({
    super.key,
    required this.image,
    required this.region,
  });

  final ImageProvider<Object> image;
  final CameraFocusRegion region;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipPath(
          clipper: CameraOuterFocusClipper(region: region),
          clipBehavior: Clip.hardEdge,
          child: LayoutBuilder(
            builder: (context, box) {
              final side = box.maxWidth * 1.35;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: box.maxWidth * .5 - side / 2,
                    top: box.maxHeight * .55 - side / 2,
                    width: side,
                    height: side,
                    child: Opacity(
                      opacity: .12,
                      child: Image(
                        image: image,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Header/footer occupy only the space outside the unchanged camera target.
class CameraPresentationChrome extends StatelessWidget {
  const CameraPresentationChrome({
    super.key,
    required this.presentation,
    required this.theme,
    required this.target,
    required this.guidance,
    required this.shutter,
    required this.onBack,
    required this.onFlash,
    required this.torch,
    required this.showLightHint,
    required this.autoVisible,
    required this.autoEnabled,
    required this.onAutoChanged,
    this.instruction,
    this.onFinish,
    this.finishEnabled = true,
  });

  final CoffeeCameraPresentation presentation;
  final CoffeeCameraTheme theme;
  final TargetGeometry target;
  final String guidance;
  final String? instruction;
  final Widget shutter;
  final VoidCallback onBack;
  final VoidCallback onFlash;
  final VoidCallback? onFinish;
  final bool finishEnabled;
  final bool torch;
  final bool showLightHint;
  final bool autoVisible;
  final bool autoEnabled;
  final ValueChanged<bool> onAutoChanged;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final compactFooter =
        target.viewportSize.height < 640 ||
        MediaQuery.textScalerOf(context).scale(16) > 20;
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          top: padding.top + 8,
          height: (target.bounds.top - padding.top - 16).clamp(
            0.0,
            double.infinity,
          ),
          child: Column(
            children: [
              // Keep sequence completion beside the flash, outside scrolling text.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _icon('Geri', Icons.arrow_back, onBack),
                  if (onFinish == null)
                    Expanded(child: _title(context))
                  else
                    const Spacer(),
                  _icon(
                    torch ? 'Işığı kapat' : 'Işığı aç',
                    torch ? Icons.flash_on : Icons.flash_off,
                    onFlash,
                  ),
                  if (onFinish case final finish?)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: target.viewportSize.width * .45,
                      ),
                      child: TextButton(
                        key: const Key('coffee-finish-sequence'),
                        onPressed: finishEnabled ? finish : null,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xddfbf7ee),
                          foregroundColor: const Color(0xff4a342a),
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text(
                          'Çekimi bitir',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: ClipRect(
                  child: SingleChildScrollView(
                    key: const Key('coffee-camera-brand-header'),
                    child: Column(
                      children: [
                        if (onFinish != null) _title(context),
                        if (presentation.stepLabel case final step?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Text(
                              step,
                              key: const Key('coffee-camera-brand-step'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.mutedForeground,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (instruction case final text?)
                          Text(
                            text,
                            key: const Key('coffee-camera-brand-instruction'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.foreground,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        if (showLightHint)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Tarama görünmüyorsa ışığı açmayı dene.',
                              key: const Key('coffee-camera-light-hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          top: target.bounds.bottom + 12,
          bottom: padding.bottom + 20,
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                key: const Key('coffee-camera-brand-footer'),
                reverse: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      guidance,
                      key: const Key('coffee-camera-guidance'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (compactFooter && autoVisible) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _autoControl()),
                          const SizedBox(width: 12),
                          shutter,
                        ],
                      ),
                    ] else ...[
                      if (autoVisible) ...[
                        const SizedBox(height: 8),
                        _autoControl(),
                      ],
                      const SizedBox(height: 10),
                      shutter,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _title(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Text(
      presentation.title,
      key: const Key('coffee-camera-brand-title'),
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: theme.foreground,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _autoControl() => Semantics(
    toggled: autoEnabled,
    label: 'Otomatik çekim',
    child: OutlinedButton(
      key: const Key('coffee-camera-auto-switch'),
      onPressed: () => onAutoChanged(!autoEnabled),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: theme.foreground,
        backgroundColor: theme.background.withValues(alpha: .70),
        side: BorderSide(color: theme.mutedForeground.withValues(alpha: .45)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(
        'Otomatik · ${autoEnabled ? 'Açık' : 'Kapalı'}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    ),
  );

  Widget _icon(String label, IconData icon, VoidCallback callback) =>
      IconButton(
        tooltip: label,
        onPressed: callback,
        style: IconButton.styleFrom(
          foregroundColor: theme.foreground,
          backgroundColor: theme.background.withValues(alpha: .55),
          minimumSize: const Size(48, 48),
        ),
        icon: Icon(icon),
      );
}
