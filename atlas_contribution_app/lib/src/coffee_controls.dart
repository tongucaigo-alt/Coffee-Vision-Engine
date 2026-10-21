import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'atlas_design.dart';

class CoffeeAction {
  const CoffeeAction(
    this.label,
    this.onPressed, {
    this.icon,
    this.tooltip,
    this.iconWidget,
    this.emphasized = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;
  final Widget? iconWidget;
  final bool emphasized;
}

class CoffeeSaucerAddIcon extends StatelessWidget {
  const CoffeeSaucerAddIcon({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    height: 16,
    child: CustomPaint(
      painter: _SaucerPainter(IconTheme.of(context).color ?? atlasSageInk),
    ),
  );
}

class _SaucerPainter extends CustomPainter {
  const _SaucerPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(Rect.fromLTWH(1, 6, 12, 7), paint);
    canvas.drawOval(Rect.fromLTWH(3.5, 8, 7, 3), paint);
    canvas.drawLine(const Offset(12.5, 1), const Offset(12.5, 5), paint);
    canvas.drawLine(const Offset(10.5, 3), const Offset(14.5, 3), paint);
  }

  @override
  bool shouldRepaint(covariant _SaucerPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Keep every action visible and every word whole at the user's text scale.
class CoffeeActions extends StatelessWidget {
  const CoffeeActions(
    this.actions, {
    this.compact = false,
    this.referenceLabels = const [],
    super.key,
  });
  final List<CoffeeAction> actions;
  final bool compact;
  final List<String> referenceLabels;
  static const textStyle = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (actions.isEmpty) return const SizedBox.shrink();
      double wordWidth = 48;
      for (final action in actions) {
        for (final word in action.label.split(' ')) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: textStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          wordWidth = math.max(wordWidth, painter.width + (compact ? 0 : 8));
        }
      }
      // Both preview stages use the same capacity at large text sizes. Keep
      // the reference's three evenly spaced buttons at ordinary text sizes.
      for (final label in [
        ...referenceLabels,
        if (referenceLabels.isNotEmpty) ...actions.map((a) => a.label),
      ]) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: Theme.of(context).textTheme.labelLarge?.merge(textStyle),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        wordWidth = math.max(wordWidth, painter.width + (compact ? 0 : 8));
      }
      final columns = math.max(
        1,
        math.min(actions.length, (box.maxWidth / wordWidth).floor()),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var start = 0; start < actions.length; start += columns)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++)
                    Expanded(
                      child: start + col >= actions.length
                          ? const SizedBox()
                          : _button(actions[start + col]),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _button(CoffeeAction action) => Tooltip(
    message: action.tooltip ?? action.label,
    child: TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 4, vertical: 8),
        textStyle: textStyle,
        foregroundColor: atlasSageInk,
      ),
      child: action.icon != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 16),
                const SizedBox(height: 4),
                Text(action.label, textAlign: TextAlign.center),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(action.label, textAlign: TextAlign.center),
                ),
              ],
            ),
    ),
  );
}
