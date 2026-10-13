import 'package:flutter/material.dart';
import 'atlas_design.dart';
import 'coffee_controls.dart';
import 'models.dart';
import 'photo_crop.dart';

PhotoCrop coffeeDisplayCrop(ContributionPhoto photo) =>
    photo.regions.every((r) => photo.visibleCrop.containsBox(r.box))
    ? photo.visibleCrop
    : PhotoCrop.full;

/// One geometry for review and annotation, independent of controls and selection.
class CoffeePhotoLayout extends StatelessWidget {
  const CoffeePhotoLayout({
    required this.photo,
    required this.tools,
    required this.footer,
    super.key,
  });
  final Widget photo, tools, footer;
  static const toolbarHeight = 80.0;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: LayoutBuilder(
      builder: (context, box) {
        final large = MediaQuery.textScalerOf(context).scale(14) > 19;
        final height = (box.maxHeight - 192).clamp(96.0, double.infinity);
        return Stack(
          children: [
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              height: height,
              child: Material(
                key: const ValueKey('coffee-photo-frame'),
                color: atlasCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: atlasBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: photo,
              ),
            ),
            Positioned(
              left: large ? 4 : 0,
              right: large ? 4 : 0,
              top: large ? height - 60 : height + 16,
              height: 64,
              child: large ? CoffeeControlSurface(child: tools) : tools,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: large ? 180 : 112,
              child: Theme(
                data: Theme.of(context).copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: Theme.of(context).filledButtonTheme.style?.copyWith(
                      minimumSize: WidgetStatePropertyAll(
                        Size(48, large ? 88 : 48),
                      ),
                    ),
                  ),
                ),
                child: footer,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class CoffeeControlSurface extends StatelessWidget {
  const CoffeeControlSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: atlasCard,
    elevation: 2,
    shadowColor: atlasCoffee.withValues(alpha: .2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: atlasBorder),
    ),
    child: child,
  );
}

/// A compact visible surface inside an unchanged accessible touch target.
class CoffeeOverlayButton extends StatelessWidget {
  const CoffeeOverlayButton({
    required this.child,
    required this.onPressed,
    required this.tooltip,
    this.selected,
    this.foregroundColor = atlasSageInk,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool? selected;
  final Color foregroundColor;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tooltip,
    button: true,
    selected: selected,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          foregroundColor: foregroundColor,
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Material(
          color: selected == true ? atlasSageSurface : atlasCard,
          elevation: 2,
          shadowColor: atlasCoffee.withValues(alpha: .2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: atlasBorder),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: onPressed == null
                  ? Theme.of(context).disabledColor
                  : foregroundColor,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Keep words whole, using horizontal scrolling only when they do not fit.
class CoffeeActionStrip extends StatelessWidget {
  const CoffeeActionStrip(this.actions, {this.iconsAbove = false, super.key});
  final List<CoffeeAction> actions;
  final bool iconsAbove;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (actions.isEmpty) return const SizedBox.shrink();
      final above =
          iconsAbove && MediaQuery.textScalerOf(context).scale(12) <= 17;
      final textStyle =
          Theme.of(
            context,
          ).textTheme.labelLarge?.merge(CoffeeActions.textStyle) ??
          CoffeeActions.textStyle;
      final widths = actions.map((a) {
        final text = TextPainter(
          text: TextSpan(text: a.label, style: textStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        return (text.width.ceilToDouble() +
                18 +
                (!above && a.icon != null ? 24 : 0))
            .clamp(48.0, double.infinity);
      }).toList();
      Widget button(CoffeeAction a) => Tooltip(
        message: a.tooltip ?? a.label,
        child: TextButton(
          onPressed: a.onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            foregroundColor: atlasSageInk,
            textStyle: textStyle,
          ),
          child: above && a.icon != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icon, size: 16),
                    const SizedBox(height: 4),
                    Text(a.label, softWrap: false),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (a.icon != null) ...[
                      Icon(a.icon, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(a.label, softWrap: false),
                  ],
                ),
        ),
      );
      final fits = widths.every((w) => w <= box.maxWidth / actions.length);
      if (fits) {
        return Row(
          children: [for (final a in actions) Expanded(child: button(a))],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++)
              SizedBox(width: widths[i], child: button(actions[i])),
          ],
        ),
      );
    },
  );
}
