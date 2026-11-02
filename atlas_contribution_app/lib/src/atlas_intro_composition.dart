import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The lake reflection is already part of the video. Keep the complete scene
/// visible and extend only narrow edge textures on other screen ratios.
class AtlasIntroComposition extends StatelessWidget {
  const AtlasIntroComposition({
    required this.frame,
    required this.mainFrame,
    super.key,
  });
  final Widget Function() frame;
  final Widget mainFrame;
  static const sourceSize = Size(1080, 2400);
  static Rect contentRect(Size size) => Alignment.center.inscribe(
    applyBoxFit(BoxFit.contain, sourceSize, size).destination,
    Offset.zero & size,
  );

  Widget _scene(Widget child) => FittedBox(
    fit: BoxFit.fill,
    child: SizedBox.fromSize(size: sourceSize, child: child),
  );

  // No mirroring: stretch a 12-source-pixel border outside the original scene.
  // All views share the existing single player and its audio stream.
  Widget _edge(Rect source, Size target) {
    final sx = target.width / source.width, sy = target.height / source.height;
    final full = Size(sourceSize.width * sx, sourceSize.height * sy);
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
          tileMode: TileMode.clamp,
        ),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: full.width,
          maxWidth: full.width,
          minHeight: full.height,
          maxHeight: full.height,
          child: Transform.translate(
            offset: Offset(-source.left * sx, -source.top * sy),
            child: SizedBox.fromSize(size: full, child: _scene(frame())),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest, rect = contentRect(box.biggest);
      final vertical = rect.top > .01, horizontal = rect.left > .01;
      final layers = <Widget>[];
      const strip = 12.0;
      if (vertical) {
        for (final bottom in [false, true]) {
          layers.add(
            Positioned(
              left: 0,
              width: size.width,
              top: bottom ? rect.bottom : 0,
              height: rect.top,
              child: _edge(
                Rect.fromLTWH(
                  0,
                  bottom ? sourceSize.height - strip : 0,
                  sourceSize.width,
                  strip,
                ),
                Size(size.width, rect.top),
              ),
            ),
          );
        }
      }
      if (horizontal) {
        for (final right in [false, true]) {
          layers.add(
            Positioned(
              top: 0,
              height: size.height,
              left: right ? rect.right : 0,
              width: rect.left,
              child: _edge(
                Rect.fromLTWH(
                  right ? sourceSize.width - strip : 0,
                  0,
                  strip,
                  sourceSize.height,
                ),
                Size(rect.left, size.height),
              ),
            ),
          );
        }
      }
      Widget original = _scene(mainFrame);
      if (vertical || horizontal) {
        layers.add(Positioned.fromRect(rect: rect, child: _scene(frame())));
        original = ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final length = vertical ? bounds.height : bounds.width;
            final edge = math.min(.02, 2 / length);
            return LinearGradient(
              begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, edge, 1 - edge, 1],
            ).createShader(bounds);
          },
          child: original,
        );
      }
      layers.add(
        Positioned.fromRect(
          key: const ValueKey('atlas-intro-content'),
          rect: rect,
          child: original,
        ),
      );
      return ClipRect(
        key: const ValueKey('atlas-intro-viewport'),
        child: SizedBox.fromSize(
          size: size,
          child: Stack(children: layers),
        ),
      );
    },
  );
}
