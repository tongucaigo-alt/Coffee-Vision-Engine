import 'package:flutter/material.dart';
import 'cropped_photo.dart';
import 'models.dart';
import 'theme.dart';

const atlasCoffee = Color(0xff2c1810);
const atlasCream = Color(0xfffaf7f2);
const atlasSage = Color(0xff4a7c59);
const atlasBorder = Color(0xffe6dfd5);

ThemeData atlasTheme() {
  final base = contributionTheme();
  final colors = ColorScheme.fromSeed(seedColor: atlasCoffee).copyWith(
    primary: atlasCoffee,
    secondary: atlasSage,
    surface: atlasCream,
    onSurface: atlasCoffee,
    outlineVariant: atlasBorder,
  );
  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: atlasCream,
    textTheme: base.textTheme.apply(
      fontFamily: 'Plus Jakarta Sans',
      bodyColor: atlasCoffee,
      displayColor: atlasCoffee,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: atlasCream,
      foregroundColor: atlasCoffee,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xffeaf2ec),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xffeaf2ec)
              : Colors.white,
        ),
        foregroundColor: const WidgetStatePropertyAll(atlasCoffee),
        side: const WidgetStatePropertyAll(BorderSide(color: atlasBorder)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: atlasCoffee,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: atlasCoffee,
        backgroundColor: Colors.white,
        side: const BorderSide(color: atlasBorder),
        padding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: atlasBorder),
      ),
    ),
  );
}

class AtlasBrand extends StatelessWidget {
  const AtlasBrand({this.size = 40, this.showName = true, super.key});
  final double size;
  final bool showName;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/brand/atlas-logo.png',
        width: size,
        height: size,
        semanticLabel: 'Atlas',
      ),
      if (showName) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Text('Atlas', style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ],
  );
}

class AtlasNotice extends StatelessWidget {
  const AtlasNotice(this.text, {this.icon = Icons.info_outline, super.key});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xffeaf2ec),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: atlasSage, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class AtlasPhoto extends StatelessWidget {
  const AtlasPhoto({
    required this.photo,
    required this.image,
    this.height = 160,
    super.key,
  });
  final ContributionPhoto photo;
  final ImageProvider image;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: height,
      child: CroppedPhoto(
        image: image,
        crop: photo.visibleCrop,
        photoWidth: photo.width,
        photoHeight: photo.height,
        semanticLabel: photo.title,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    ),
  );
}

/// Presentation only: the saved answer is never rewritten or regenerated.
class FortuneStory extends StatelessWidget {
  const FortuneStory({required this.text, required this.hasSymbols, super.key});
  final String text;
  final bool hasSymbols;
  @override
  Widget build(BuildContext context) {
    final paragraphs = text.trim().split(RegExp(r'\r?\n\s*\r?\n'));
    const style = TextStyle(fontFamily: 'Literata', fontSize: 18, height: 1.65);
    if (paragraphs.length != 4) return SelectableText(text, style: style);
    final headings = [
      'Genel Enerji',
      hasSymbols ? 'Senin Gördüğün Semboller' : 'Çağrışımlar',
      'Yakın Dönem',
      'Kapanış',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paragraphs.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: EdgeInsets.all(i == 1 ? 16 : 0),
            decoration: i == 1
                ? BoxDecoration(
                    color: const Color(0xfff3ede2),
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  headings[i],
                  style: const TextStyle(
                    color: atlasSage,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(paragraphs[i], style: style),
              ],
            ),
          ),
      ],
    );
  }
}
