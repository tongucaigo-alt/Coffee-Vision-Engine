import 'package:flutter/material.dart';
import 'atlas_design.dart';

class PhotoNavigation extends StatelessWidget {
  const PhotoNavigation({
    required this.index,
    required this.count,
    required this.onSelect,
    super.key,
  });
  final int index, count;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
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
