import 'package:flutter/material.dart';
import 'atlas_palette.dart';

ThemeData contributionTheme() {
  final colors = ColorScheme.fromSeed(seedColor: atlasCoffee).copyWith(
    primary: atlasCoffee,
    onPrimary: atlasCard,
    secondary: atlasSageInk,
    onSecondary: atlasCard,
    surface: atlasCream,
    onSurface: atlasInk,
    onSurfaceVariant: atlasMuted,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: atlasCard,
    surfaceContainerLow: atlasCard,
    surfaceContainer: atlasCream,
    surfaceContainerHigh: const Color(0xffeee5d4),
    surfaceContainerHighest: const Color(0xffe9dfcd),
    primaryContainer: const Color(0xffeee1d2),
    onPrimaryContainer: atlasInk,
    secondaryContainer: atlasSageSurface,
    onSecondaryContainer: atlasInk,
    outline: atlasBorder,
    outlineVariant: atlasBorder,
    error: const Color(0xffb02e3c),
  );
  final text = ThemeData(useMaterial3: true).textTheme;
  TextStyle? spaced(TextStyle? style) => style?.copyWith(letterSpacing: 0);
  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      displayLarge: spaced(text.displayLarge),
      displayMedium: spaced(text.displayMedium),
      displaySmall: spaced(text.displaySmall),
      headlineLarge: spaced(text.headlineLarge),
      headlineMedium: spaced(
        text.headlineMedium,
      )?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: spaced(text.headlineSmall),
      titleLarge: spaced(
        text.titleLarge,
      )?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: spaced(text.titleMedium),
      titleSmall: spaced(text.titleSmall),
      bodyLarge: spaced(text.bodyLarge),
      bodyMedium: spaced(text.bodyMedium)?.copyWith(fontSize: 16),
      bodySmall: spaced(text.bodySmall),
      labelLarge: spaced(text.labelLarge)?.copyWith(fontSize: 16),
      labelMedium: spaced(text.labelMedium),
      labelSmall: spaced(text.labelSmall),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
      fillColor: atlasCard,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: atlasCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: atlasBorder),
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
