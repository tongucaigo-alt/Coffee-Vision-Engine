import 'package:flutter/material.dart';
import 'atlas_design.dart';
import 'coffee_photo_layout.dart';

class PhotoNavigation extends StatelessWidget {
  const PhotoNavigation({
    required this.index,
    required this.count,
    required this.onSelect,
    this.overlay = false,
    this.bottomInset = 8,
    super.key,
  });
  final int index, count;
  final ValueChanged<int>? onSelect;
  final bool overlay;
  final double bottomInset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (overlay) {
        return Stack(
          children: [
            if (count > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: CoffeeOverlayButton(
                  key: const ValueKey('coffee-previous-photo'),
                  tooltip: 'Önceki fotoğraf',
                  foregroundColor: atlasCoffee,
                  onPressed: index > 0 && onSelect != null
                      ? () => onSelect!(index - 1)
                      : null,
                  child: const Icon(Icons.chevron_left, size: 24),
                ),
              ),
            if (count > 1)
              Align(
                alignment: Alignment.centerRight,
                child: CoffeeOverlayButton(
                  key: const ValueKey('coffee-next-photo'),
                  tooltip: 'Sonraki fotoğraf',
                  foregroundColor: atlasCoffee,
                  onPressed: index < count - 1 && onSelect != null
                      ? () => onSelect!(index + 1)
                      : null,
                  child: const Icon(Icons.chevron_right, size: 24),
                ),
              ),
            Positioned(
              left: 56,
              right: 56,
              bottom: bottomInset,
              child: Center(
                child: CoffeeControlSurface(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Fotoğraf ${index + 1}/$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9.75,
                          color: atlasCoffee,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
      final style =
          Theme.of(context).textButtonTheme.style?.textStyle?.resolve({}) ??
          const TextStyle(fontSize: 13);
      final text = TextPainter(
        text: TextSpan(text: 'Sonraki ›', style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final arrows = count > 1 && text.width + 24 > box.maxWidth / 3;
      return Row(
        children: [
          if (count > 1)
            Flexible(
              flex: arrows ? 0 : 1,
              child: arrows
                  ? IconButton(
                      key: const ValueKey('coffee-previous-photo'),
                      tooltip: 'Önceki fotoğraf',
                      onPressed: index > 0 && onSelect != null
                          ? () => onSelect!(index - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    )
                  : TextButton(
                      key: const ValueKey('coffee-previous-photo'),
                      onPressed: index > 0 && onSelect != null
                          ? () => onSelect!(index - 1)
                          : null,
                      child: const Text(
                        '‹ Önceki',
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Fotoğraf ${index + 1}/$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: atlasCoffee,
                ),
              ),
            ),
          ),
          if (count > 1)
            Flexible(
              flex: arrows ? 0 : 1,
              child: arrows
                  ? IconButton(
                      key: const ValueKey('coffee-next-photo'),
                      tooltip: 'Sonraki fotoğraf',
                      onPressed: index < count - 1 && onSelect != null
                          ? () => onSelect!(index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    )
                  : TextButton(
                      key: const ValueKey('coffee-next-photo'),
                      onPressed: index < count - 1 && onSelect != null
                          ? () => onSelect!(index + 1)
                          : null,
                      child: const Text(
                        'Sonraki ›',
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
        ],
      );
    },
  );
}
