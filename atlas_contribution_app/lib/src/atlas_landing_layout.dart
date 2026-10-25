import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'atlas_design.dart';
import 'atlas_home_atmosphere.dart';

/// Shared home geometry. The empty coffee notice slot matches the Tarot notice.
class AtlasLandingLayout extends StatelessWidget {
  const AtlasLandingLayout({
    required this.content,
    required this.secondary,
    required this.primary,
    required this.frame,
    this.resume,
    this.notice = false,
    this.scrollKey,
    super.key,
  });
  final Widget content, secondary, primary, frame;
  final Widget? resume;
  final bool notice;
  final Key? scrollKey;
  static const noticeText =
      'Tarot eğlence ve öz değerlendirme içindir. Kart seçimi çevrimdışıdır; yorum için internet gerekir.';
  static const noticeStyle = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: atlasMuted,
  );

  static ButtonStyle primaryStyle() => FilledButton.styleFrom(
    textStyle: const TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    minimumSize: const Size(48, 56),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    backgroundColor: atlasCoffee,
    foregroundColor: atlasCard,
    elevation: 2,
    shadowColor: atlasCoffee.withValues(alpha: .2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: LayoutBuilder(
            builder: (context, box) {
              final text = TextPainter(
                text: TextSpan(
                  text: noticeText,
                  style: DefaultTextStyle.of(context).style.merge(noticeStyle),
                ),
                textAlign: TextAlign.center,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: math.max(1, box.maxWidth - 32));
              final body = Stack(
                fit: StackFit.passthrough,
                children: [
                  const Positioned.fill(child: AtlasHomeAtmosphere()),
                  Positioned.fill(child: IgnorePointer(child: frame)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      box.maxHeight < 500 ? 16 : 40,
                      16,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        content,
                        const Spacer(),
                        AtlasActionWidth(child: secondary),
                        const SizedBox(height: 8),
                        primary,
                        const SizedBox(height: 8),
                        SizedBox(
                          height: text.height,
                          child: notice
                              ? const Text(
                                  noticeText,
                                  textAlign: TextAlign.center,
                                  style: noticeStyle,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (resume != null)
                    Positioned(top: 8, right: 8, child: resume!),
                ],
              );
              // Intrinsic content, not a fixed viewport threshold, decides
              // whether scrolling is necessary (including short landscapes).
              return SingleChildScrollView(
                key: scrollKey,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(child: body),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Identical presentation slots keep home typography and artwork aligned.
class AtlasLandingContent extends StatelessWidget {
  const AtlasLandingContent({
    required this.hero,
    required this.kicker,
    required this.title,
    required this.description,
    super.key,
  });
  final Widget hero, kicker;
  final String title, description;
  static const titleStyle = TextStyle(
    fontFamily: 'Literata',
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w500,
    color: atlasInk,
  );
  static const bodyStyle = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: atlasMuted,
  );
  static const kickerStyle = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: atlasSageInk,
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        key: const ValueKey('atlas-landing-hero-slot'),
        height: 152,
        child: Center(child: hero),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Center(child: kicker),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        key: const ValueKey('atlas-landing-title'),
        textAlign: TextAlign.center,
        style: titleStyle,
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (MediaQuery.textScalerOf(context).scale(13) * 1.45 * 2)
              .ceilToDouble(),
        ),
        child: Text(description, textAlign: TextAlign.center, style: bodyStyle),
      ),
    ],
  );
}
