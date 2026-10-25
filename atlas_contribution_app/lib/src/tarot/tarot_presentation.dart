part of 'tarot_pages.dart';

class _TarotHomeCards extends StatelessWidget {
  const _TarotHomeCards();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 152,
    child: Center(
      child: SizedBox(
        width: 164,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final offset in [-29.0, 29.0])
              Transform.translate(
                offset: Offset(offset, 8),
                child: Transform.rotate(
                  angle: offset < 0 ? -.18 : .18,
                  child: const SizedBox(
                    width: 82,
                    child: TarotCardView(showFront: false),
                  ),
                ),
              ),
            const SizedBox(width: 92, child: TarotCardView(showFront: false)),
          ],
        ),
      ),
    ),
  );
}

class _TarotMoodPicker extends StatelessWidget {
  const _TarotMoodPicker({
    required this.mood,
    required this.saving,
    required this.onSelect,
    this.error,
  });
  final TarotMood? mood;
  final bool saving;
  final String? error;
  final ValueChanged<TarotMood> onSelect;
  static const _icons = {
    TarotMood.happy: Icons.sentiment_satisfied_alt_outlined,
    TarotMood.calm: Icons.spa_outlined,
    TarotMood.unsure: Icons.help_outline,
    TarotMood.tense: Icons.thunderstorm_outlined,
    TarotMood.tired: Icons.bedtime_outlined,
  };
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('tarot-mood-picker'),
    children: [
      const Divider(color: atlasBorder, height: 1),
      const SizedBox(height: 4),
      const Text(
        'İstersen bana nasıl hissettiğini söyleyebilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Literata', fontSize: 19, height: 1.5),
      ),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(13) > 19.5
              ? (constraints.maxWidth < 340 ? 1 : 2)
              : 3;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in TarotMood.values)
                SizedBox(
                  width: width,
                  child: MergeSemantics(
                    child: Semantics(
                      selected: value == mood,
                      child: OutlinedButton(
                        key: ValueKey('tarot-mood-${value.name}'),
                        onPressed: saving ? null : () => onSelect(value),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          foregroundColor: atlasSageInk,
                          backgroundColor: value == mood
                              ? atlasSageSurface
                              : atlasCream,
                          disabledForegroundColor: atlasSageInk,
                          side: BorderSide(
                            color: value == mood ? atlasSageInk : atlasBorder,
                            width: value == mood ? 1.5 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icons[value], size: 18),
                            const SizedBox(height: 2),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 3,
                              children: [
                                if (value == mood)
                                  const Icon(Icons.check, size: 14),
                                Text(
                                  value.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 6),
      const Text(
        'Seçim yapmadan da kartlarını açabilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(color: atlasMuted, fontSize: 12, height: 1.5),
      ),
      if (error != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: atlasCopperInk, height: 1.5),
          ),
        ),
      ],
    ],
  );
}

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
