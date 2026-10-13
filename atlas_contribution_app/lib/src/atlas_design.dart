import 'package:flutter/material.dart';
import 'cropped_photo.dart';
import 'models.dart';
import 'theme.dart';

// Reference palette. Ink companions keep small labels readable on cream.
const atlasCoffee = Color(0xff4a342a);
const atlasCream = Color(0xfff5efe3);
const atlasCard = Color(0xfffbf7ee);
const atlasInk = Color(0xff2e241f);
const atlasCopper = Color(0xffb0714f);
const atlasCopperInk = Color(0xff975b3d);
const atlasSage = Color(0xff7ba294);
const atlasSageInk = Color(0xff4e7468);
const atlasMuted = Color(0xff786c60);
const atlasBorder = Color(0xffdfd2bb);
const atlasSageSurface = Color(0xffe4ebe2);

ThemeData atlasTheme() {
  final base = contributionTheme();
  final colors = ColorScheme.fromSeed(seedColor: atlasCoffee).copyWith(
    primary: atlasCoffee,
    secondary: atlasSageInk,
    onPrimary: atlasCard,
    onSecondary: atlasCard,
    surfaceContainerLowest: atlasCard,
    surfaceContainerLow: atlasCard,
    surfaceContainer: atlasCream,
    surfaceContainerHigh: const Color(0xffeee5d4),
    surfaceContainerHighest: const Color(0xffe9dfcd),
    primaryContainer: const Color(0xffeee1d2),
    onPrimaryContainer: atlasInk,
    secondaryContainer: atlasSageSurface,
    onSecondaryContainer: atlasInk,
    surface: atlasCream,
    onSurface: atlasInk,
    onSurfaceVariant: atlasMuted,
    outline: atlasBorder,
    outlineVariant: atlasBorder,
  );
  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: atlasCream,
    textTheme: base.textTheme
        .apply(
          fontFamily: 'Plus Jakarta Sans',
          bodyColor: atlasInk,
          displayColor: atlasInk,
        )
        .copyWith(
          titleLarge: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: atlasInk,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: atlasCream,
      foregroundColor: atlasInk,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: atlasCream,
      indicatorColor: atlasSageSurface,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? atlasSageSurface
              : atlasCard,
        ),
        foregroundColor: const WidgetStatePropertyAll(atlasCoffee),
        side: const WidgetStatePropertyAll(BorderSide(color: atlasBorder)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: atlasCoffee,
        foregroundColor: atlasCard,
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: atlasInk,
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: atlasCard,
        side: const BorderSide(color: atlasBorder),
        padding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: atlasCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: atlasBorder, width: .8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: atlasSageInk,
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: atlasCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(fontSize: 12, color: atlasMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: atlasBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: atlasBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: atlasCream,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: atlasCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

ThemeData coffeeFlowTheme(ThemeData base) => base.copyWith(
  chipTheme: base.chipTheme.copyWith(
    backgroundColor: atlasCard,
    selectedColor: atlasSageSurface,
    secondarySelectedColor: atlasSageSurface,
    checkmarkColor: atlasSageInk,
    side: const BorderSide(color: atlasBorder),
    labelStyle: const TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 13,
      color: atlasInk,
    ),
    secondaryLabelStyle: const TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 13,
      color: atlasInk,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),
);

/// A centered primary action: keep the existing height, style and callbacks.
/// More room is available when the user enlarges text; never shrink their font.
class AtlasPrimaryButton extends StatelessWidget {
  const AtlasPrimaryButton({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : icon = null;

  const AtlasPrimaryButton.icon({
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.style,
    super.key,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;
  static const preferredWidth = AtlasActionWidth.preferredWidth;

  @override
  Widget build(BuildContext context) => AtlasActionWidth(
    child: icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: icon!,
            label: child,
          ),
  );
}

/// Shared width for paired actions, with room for enlarged text.
class AtlasActionWidth extends StatelessWidget {
  const AtlasActionWidth({required this.child, super.key});
  final Widget child;
  static const preferredWidth = 280.0;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth:
            preferredWidth *
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 2),
      ),
      child: SizedBox(width: double.infinity, child: child),
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
      ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/brand/atlas-logo.png',
          width: size,
          height: size,
          semanticLabel: 'Atlas',
        ),
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
      color: atlasSageSurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: atlasSageInk, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: atlasSageInk,
            ),
          ),
        ),
      ],
    ),
  );
}

class AtlasHint extends StatelessWidget {
  const AtlasHint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.6, color: atlasMuted),
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
    const style = TextStyle(fontFamily: 'Literata', fontSize: 16, height: 1.75);
    if (paragraphs.length != 4) {
      return SelectableText(
        text,
        style: style,
        scrollPhysics: const NeverScrollableScrollPhysics(),
      );
    }
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
                    color: atlasCard,
                    borderRadius: BorderRadius.circular(22),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  headings[i],
                  style: const TextStyle(
                    color: atlasSageInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  paragraphs[i],
                  style: style,
                  scrollPhysics: const NeverScrollableScrollPhysics(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
