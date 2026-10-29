import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The original scene always remains contained. Only narrow edge textures fill
/// the surplus screen area; they never include another moon or figure.
class AtlasIntroComposition extends StatelessWidget {
  const AtlasIntroComposition({
    required this.frame,
    required this.mainFrame,
    super.key,
  });
  final Widget Function() frame;
  final Widget mainFrame;
  static const sourceSize = Size(720, 1280);
  static Rect contentRect(Size size) => Alignment.center.inscribe(
    applyBoxFit(BoxFit.contain, sourceSize, size).destination,
    Offset.zero & size,
  );

  Widget _scene(Widget child) => FittedBox(
    fit: BoxFit.fill,
    child: SizedBox(width: 720, height: 1280, child: child),
  );

  Widget _patch(
    Rect source,
    Size target, {
    bool vertical = false,
    bool horizontal = false,
  }) {
    final sx = target.width / source.width, sy = target.height / source.height;
    final full = Size(720 * sx, 1280 * sy);
    return Transform.flip(
      flipY: vertical,
      flipX: horizontal,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: horizontal ? 24 : .75,
          sigmaY: horizontal ? 32 : .75,
          tileMode: TileMode.mirror,
        ),
        child: ClipRect(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest, rect = contentRect(box.biggest);
      final vertical = rect.top > .01, horizontal = rect.left > .01;
      final layers = <Widget>[];
      if (vertical) {
        // Narrow sky and wider foliage strips avoid recognizable duplicates.
        // Alternate reflections join the texture without hard seams.
        for (final bottom in [false, true]) {
          final sourceHeight = bottom ? 256.0 : 64.0;
          final strip = sourceHeight * rect.width / 720;
          final count = (rect.top / strip).ceil();
          for (var i = 0; i < count; i++) {
            layers.add(
              Positioned(
                left: rect.left,
                width: rect.width,
                top: bottom
                    ? rect.bottom + i * strip
                    : rect.top - (i + 1) * strip,
                height: strip,
                child: _patch(
                  Rect.fromLTWH(
                    0,
                    bottom ? 1280 - sourceHeight : 0,
                    720,
                    sourceHeight,
                  ),
                  Size(rect.width, strip),
                  vertical: i.isEven,
                ),
              ),
            );
          }
        }
      }
      if (horizontal) {
        // Very narrow side textures stretch only outside the original scene.
        // This also keeps wide layouts from creating dozens of texture layers.
        for (final right in [false, true]) {
          layers.add(
            Positioned(
              top: rect.top,
              height: rect.height,
              left: right ? rect.right : 0,
              width: rect.left,
              child: _patch(
                Rect.fromLTWH(right ? 696 : 0, 0, 24, 1280),
                Size(rect.left, rect.height),
                horizontal: true,
              ),
            ),
          );
        }
      }
      if (vertical || horizontal) {
        layers.add(
          Positioned.fromRect(
            rect: rect,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 2,
                sigmaY: 2,
                tileMode: TileMode.clamp,
              ),
              child: _scene(frame()),
            ),
          ),
        );
      }
      Widget original = _scene(mainFrame);
      if (vertical || horizontal) {
        original = ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final length = vertical ? bounds.height : bounds.width;
            final edge = math.min(.1, 8 / length);
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
