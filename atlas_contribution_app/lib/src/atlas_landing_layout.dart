import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'atlas_design.dart';
import 'atlas_home_atmosphere.dart';
import 'atlas_home_hints.dart';

class AtlasLandingLayout extends StatefulWidget {
  const AtlasLandingLayout({
    required this.content,
    required this.secondary,
    required this.primary,
    required this.frame,
    this.scene = AtlasAtmosphereScene.coffeeHome,
    this.resume,
    this.scrollKey,
    this.hintsEnabled = true,
    super.key,
  });
  final AtlasAtmosphereScene scene;
  final Widget content, secondary, primary, frame;
  final Widget? resume;
  final Key? scrollKey;
  final bool hintsEnabled;
  static const referenceFrameWidth = 873.0;
  static const hintStyle = TextStyle(
    fontFamily: 'EB Garamond',
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: atlasCoffee,
  );
  @override
  State<AtlasLandingLayout> createState() => _AtlasLandingLayoutState();
}

class _AtlasLandingLayoutState extends State<AtlasLandingLayout>
    with WidgetsBindingObserver {
  final _fallbackPreferences = AtlasHomeHintPreferences();
  AtlasHomeHintPreferences? _preferences;
  AtlasHomeHintController? _hints;
  bool _routeVisible = true, _scheduled = false;
  AppLifecycleState? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  void _createController() {
    _hints?.dispose();
    final controller = AtlasHomeHintController(
      _preferences!,
      widget.scene == AtlasAtmosphereScene.tarotHome ? 'tarot' : 'coffee',
    );
    _hints = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_hints, controller)) {
        unawaited(controller.initialize());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences =
        AtlasHomeHintScope.maybeOf(context) ?? _fallbackPreferences;
    if (_preferences != preferences) {
      _preferences = preferences;
      _createController();
    }
    _routeVisible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _scheduleVisibility();
  }

  @override
  void didUpdateWidget(AtlasLandingLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene) _createController();
    _scheduleVisibility();
  }

  void _scheduleVisibility() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _hints?.setActive(
        _routeVisible &&
            widget.hintsEnabled &&
            (_lifecycle == null || _lifecycle == AppLifecycleState.resumed),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) {
      _hints?.setActive(false);
    } else {
      _scheduleVisibility();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hints?.dispose();
    _fallbackPreferences.dispose();
    super.dispose();
  }

  // These measurements freeze the V115 heading position without building or
  // reserving any former caption/notice rows in the new layout.
  _LegacyCaptionMetrics _legacyMetrics(BuildContext context, double width) {
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, width - 32));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final tarot = widget.scene == AtlasAtmosphereScene.tarotHome;
    return (
      small: measure(
        tarot ? 'Günün Kartı' : 'Galeriden Seç',
        const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
      large: measure(
        tarot ? 'Üç Kart · Karıştır' : 'Fincanını Tara',
        const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
      notice: measure(
        'Tarot eğlence ve öz değerlendirme içindir. Kart seçimi çevrimdışıdır; yorum için internet gerekir.',
        const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AtlasHomeHintBinding(
    controller: _hints!,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                key: widget.scrollKey,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: AtlasAtmosphereSurface(
                    scene: widget.scene,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(child: widget.frame),
                        ),
                        _LandingSlots(
                          tarot: widget.scene == AtlasAtmosphereScene.tarotHome,
                          legacy: _legacyMetrics(context, box.maxWidth),
                          children: [
                            widget.content,
                            widget.secondary,
                            widget.primary,
                            _AtlasLandingHintLabel(
                              button: widget.secondary,
                              primary: false,
                            ),
                            _AtlasLandingHintLabel(
                              button: widget.primary,
                              primary: true,
                            ),
                          ],
                        ),
                        if (widget.resume != null)
                          Positioned(top: 8, right: 8, child: widget.resume!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The image owns its original action; hints never become action targets.
class AtlasLandingImageButton extends StatelessWidget {
  const AtlasLandingImageButton({
    required this.asset,
    required this.label,
    required this.onPressed,
    this.primary = false,
    super.key,
  });
  final String asset, label;
  final VoidCallback? onPressed;
  final bool primary;
  static double artworkSize(double frameWidth, {required bool primary}) =>
      frameWidth *
      (primary ? 288 : 162) /
      AtlasLandingLayout.referenceFrameWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final diameter = artworkSize(box.maxWidth + 32, primary: primary);
      final hints = AtlasHomeHintBinding.maybeOf(context);
      Widget artwork = Image.asset(
        'assets/buttons/$asset',
        key: ValueKey(
          primary ? 'atlas-primary-image' : 'atlas-secondary-image',
        ),
        width: diameter,
        height: diameter,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
      if (primary) artwork = AtlasHomeHalo(child: artwork);
      return TextButton(
        onPressed: onPressed,
        onLongPress: onPressed == null || hints == null
            ? null
            : () => hints.show(primary),
        style: TextButton.styleFrom(
          foregroundColor: atlasCoffee,
          disabledForegroundColor: atlasMuted,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          shape: const CircleBorder(),
        ),
        child: Semantics(
          label: label,
          child: Opacity(opacity: onPressed == null ? .45 : 1, child: artwork),
        ),
      );
    },
  );
}

class _AtlasLandingHintLabel extends StatelessWidget {
  const _AtlasLandingHintLabel({required this.button, required this.primary});
  final Widget button;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final visible =
        AtlasHomeHintBinding.maybeOf(context)?.visible(primary) ?? false;
    final label = button is AtlasLandingImageButton
        ? (button as AtlasLandingImageButton).label
        : '';
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: ValueKey(
            primary ? 'atlas-primary-hint' : 'atlas-secondary-hint',
          ),
          opacity: visible ? 1 : 0,
          duration: visible || MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AtlasHomeHintController.fadeDuration,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AtlasLandingLayout.hintStyle,
          ),
        ),
      ),
    );
  }
}

class AtlasLandingContent extends StatelessWidget {
  const AtlasLandingContent({
    required this.kicker,
    required this.title,
    required this.description,
    super.key,
  });
  final Widget kicker;
  final String title, description;
  static const titleStyle = TextStyle(
    fontFamily: 'EB Garamond',
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: atlasCoffee,
  );
  static const bodyStyle = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: atlasSageInk,
  );
  static const kickerStyle = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: atlasSageInk,
  );

  @override
  Widget build(BuildContext context) => AtlasAtmosphereRegion(
    kind: AtlasAtmosphereRegionKind.heading,
    child: LayoutBuilder(
      builder: (context, box) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          kicker,
          const SizedBox(height: 8),
          Text(
            title,
            key: const ValueKey('atlas-landing-title'),
            textAlign: TextAlign.center,
            style: titleStyle.copyWith(
              fontSize:
                  (67 *
                          (box.maxWidth + 32) /
                          AtlasLandingLayout.referenceFrameWidth)
                      .clamp(24, 34),
            ),
          ),
          const SizedBox(height: 14),
          Text(description, textAlign: TextAlign.center, style: bodyStyle),
        ],
      ),
    ),
  );
}

typedef _LegacyCaptionMetrics = ({double small, double large, double notice});

class _LandingSlots extends MultiChildRenderObjectWidget {
  const _LandingSlots({
    required this.tarot,
    required this.legacy,
    required super.children,
  });
  final bool tarot;
  final _LegacyCaptionMetrics legacy;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LandingRender(tarot, legacy);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _LandingRender render,
  ) {
    if (render.tarot != tarot || render.legacy != legacy) {
      render.tarot = tarot;
      render.legacy = legacy;
      render.markNeedsLayout();
    }
  }
}

class _LandingParentData extends ContainerBoxParentData<RenderBox> {}

class _LandingRender extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _LandingRender(this.tarot, this.legacy);
  bool tarot;
  _LegacyCaptionMetrics legacy;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _LandingParentData();
    }
  }

  double _v115Heading(
    double width,
    double viewport,
    double contentHeight,
    double smallDiameter,
    double largeDiameter,
  ) {
    final smallHeight = math.max(48.0, smallDiameter + 8 + legacy.small);
    final largeHeight = math.max(48.0, largeDiameter + 12 + legacy.large);
    final height = math.max(
      viewport,
      60 +
          contentHeight +
          12 +
          smallHeight +
          8 +
          largeHeight +
          6 +
          legacy.notice +
          20,
    );
    final noticeTop = height - 20 - legacy.notice;
    final largeCenter = height * ((tarot ? 1360 : 1390) - 264) / 1456;
    final smallCenter = height * ((tarot ? 1020 : 1040) - 264) / 1456;
    final largeTop = math.max(
      60 + contentHeight + 12 + smallHeight + 8,
      math.min(largeCenter - largeDiameter / 2, noticeTop - 6 - largeHeight),
    );
    final smallTop = math.max(
      60 + contentHeight + 12,
      math.min(smallCenter - smallDiameter / 2, largeTop - 8 - smallHeight),
    );
    return math.max(
      60.0,
      math.min(height * .19, smallTop - 12 - contentHeight),
    );
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final children = getChildrenAsList();
    for (final child in children) {
      child.layout(
        BoxConstraints(maxWidth: math.max(1, width - 32)),
        parentUsesSize: true,
      );
    }
    final content = children[0], small = children[1], large = children[2];
    final smallHint = children[3], largeHint = children[4];
    final smallDiameter = AtlasLandingImageButton.artworkSize(
      width,
      primary: false,
    );
    final largeDiameter = AtlasLandingImageButton.artworkSize(
      width,
      primary: true,
    );
    final contentTop = _v115Heading(
      width,
      constraints.minHeight,
      content.size.height,
      smallDiameter,
      largeDiameter,
    );
    // Only real artwork and clearance participate. Labels are painted overlays.
    final gap = math.max(34.0, smallHint.size.height + 14);
    final bottom = math.max(58.0, largeHint.size.height + 24);
    final minimum =
        contentTop +
        content.size.height +
        12 +
        math.max(48.0, smallDiameter) +
        gap +
        math.max(48.0, largeDiameter) +
        bottom;
    // Keep the V116 frame/scroll canvas. Otherwise the tighter gaps shrink a
    // short screen's canvas and inadvertently move the large button *up*.
    final v116Minimum =
        contentTop +
        content.size.height +
        12 +
        math.max(48.0, smallDiameter) +
        math.max(40.0, smallHint.size.height + 16) +
        math.max(48.0, largeDiameter) +
        math.max(64.0, largeHint.size.height + 24);
    size = constraints.constrain(Size(width, math.max(minimum, v116Minimum)));
    final largeCenter = size.height - bottom - largeDiameter / 2;
    final smallCenter =
        largeCenter - largeDiameter / 2 - gap - smallDiameter / 2;
    final tops = [
      contentTop,
      smallCenter - small.size.height / 2,
      largeCenter - large.size.height / 2,
      smallCenter + smallDiameter / 2 + 6,
      largeCenter + largeDiameter / 2 + 8,
    ];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      (child.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
        (width - child.size.width) / 2,
        tops[i],
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
