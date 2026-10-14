part of 'tarot_pages.dart';

/// Presentation only: formatting never changes the saved reading or its request.
class _TarotReadingText extends StatelessWidget {
  const _TarotReadingText(this.text);
  final String text;

  List<InlineSpan> _inline(String line) {
    final spans = <InlineSpan>[];
    var end = 0;
    for (final match in RegExp(
      r'\*\*(.+?)\*\*|\*([^*\n]+)\*',
    ).allMatches(line)) {
      if (match.start > end) {
        spans.add(TextSpan(text: line.substring(end, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1) ?? match.group(2),
          style: TextStyle(
            fontWeight: match.group(1) != null ? FontWeight.w600 : null,
            fontStyle: match.group(2) != null ? FontStyle.italic : null,
          ),
        ),
      );
      end = match.end;
    }
    if (end < line.length) spans.add(TextSpan(text: line.substring(end)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split(RegExp(r'\r?\n'));
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final markdown = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(line);
      final bold = RegExp(r'^\*\*(.+)\*\*$').firstMatch(line);
      final position = const {
        'Geçmiş',
        'Şimdi',
        'Olası Yön',
        'Günlük Odak',
        'Ortak Hikâye',
        'Kartların ortak hikâyesi',
      }.contains(line.trim());
      final heading = markdown != null || bold != null || position;
      spans.add(
        TextSpan(
          children: _inline(markdown?.group(1) ?? bold?.group(1) ?? line),
          style: heading
              ? const TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 20,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: atlasCoffee,
                )
              : null,
        ),
      );
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      key: const ValueKey('tarot-reading-text'),
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 16,
        height: 1.65,
        color: atlasInk,
      ),
    );
  }
}

class _TarotBadge extends StatelessWidget {
  const _TarotBadge(this.label, {this.copper = false});
  final String label;
  final bool copper;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: copper ? atlasCopper.withValues(alpha: .1) : atlasSageSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: copper ? atlasCopperInk : atlasSageInk,
      ),
    ),
  );
}

String _tarotStatus(TarotDraw draw) => switch (draw.result.state) {
  TarotResultState.completed => 'Yorum hazır',
  TarotResultState.running => 'Yorum hazırlanıyor',
  TarotResultState.failed => 'Yorum tamamlanamadı',
  TarotResultState.cancelled => 'Yorum iptal edildi',
  TarotResultState.interrupted => 'Yorum yarım kaldı',
  TarotResultState.idle =>
    draw.ready ? 'Yorum bekliyor' : 'Açılım tamamlanmadı',
};
