import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Only presentation changes here. Material retains taps, focus and semantics.
ThemeData atlasArtworkTheme(ThemeData base) {
  ButtonStyle style(
    ButtonStyle? original, {
    bool primary = false,
    bool icon = false,
  }) => (original ?? const ButtonStyle()).copyWith(
    foregroundColor: icon
        ? original?.foregroundColor
        : WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? const Color(0xff9c8c73)
                : primary || states.contains(WidgetState.selected)
                ? const Color(0xfff6ebd3)
                : const Color(0xff432d21),
          ),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    backgroundBuilder: _background,
    foregroundBuilder: _foreground,
  );
  return base.copyWith(
    extensions: [
      ...base.extensions.values.where((e) => e is! _NativeButtons),
      _NativeButtons(
        base.filledButtonTheme,
        base.outlinedButtonTheme,
        base.textButtonTheme,
        base.iconButtonTheme,
        base.segmentedButtonTheme,
      ),
    ],
    filledButtonTheme: FilledButtonThemeData(
      style: style(base.filledButtonTheme.style, primary: true),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: style(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: style(base.textButtonTheme.style),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: style(base.iconButtonTheme.style, icon: true),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: style(base.segmentedButtonTheme.style),
    ),
  );
}

/// Home screens explicitly retain their complete original button themes.
ThemeData atlasOriginalButtonTheme(ThemeData theme) {
  final native = theme.extension<_NativeButtons>();
  return native == null
      ? theme
      : theme.copyWith(
          filledButtonTheme: native.filled,
          outlinedButtonTheme: native.outlined,
          textButtonTheme: native.text,
          iconButtonTheme: native.icon,
          segmentedButtonTheme: native.segmented,
        );
}

class AtlasOriginalButtons extends StatelessWidget {
  const AtlasOriginalButtons({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: atlasOriginalButtonTheme(Theme.of(context)),
      child: child,
    );
  }
}

class _NativeButtons extends ThemeExtension<_NativeButtons> {
  const _NativeButtons(
    this.filled,
    this.outlined,
    this.text,
    this.icon,
    this.segmented,
  );
  final FilledButtonThemeData filled;
  final OutlinedButtonThemeData outlined;
  final TextButtonThemeData text;
  final IconButtonThemeData icon;
  final SegmentedButtonThemeData segmented;
  @override
  _NativeButtons copyWith() => this;
  @override
  _NativeButtons lerp(covariant _NativeButtons? other, double t) =>
      t < .5 || other == null ? this : other;
}

String? _text(Widget? child) {
  if (child is Text) return child.data ?? child.textSpan?.toPlainText();
  if (child is Container) return _text(child.child);
  if (child is SingleChildRenderObjectWidget) return _text(child.child);
  if (child is ProxyWidget) return _text(child.child);
  if (child is MultiChildRenderObjectWidget) {
    final words = child.children.map(_text).whereType<String>().toList();
    return words.isEmpty ? null : words.join(' ');
  }
  return null;
}

class AtlasButtonCaption extends InheritedWidget {
  const AtlasButtonCaption({
    required this.label,
    this.icon,
    this.surfaceHeight,
    required super.child,
    super.key,
  });
  final Widget label;
  final Widget? icon;
  final double? surfaceHeight;
  @override
  bool updateShouldNotify(AtlasButtonCaption old) =>
      label != old.label ||
      icon != old.icon ||
      surfaceHeight != old.surfaceHeight;
}

/// Reserves the complete original rim and shadow around a selectable label.
class AtlasSelectionFace extends StatelessWidget {
  const AtlasSelectionFace({
    required this.selected,
    required this.child,
    this.disabled = false,
    super.key,
  });
  final bool selected, disabled;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: _AtlasButtonArtwork(
              art: selected ? _primary : _light,
              skinOnly: true,
              preserveInsets: true,
              disabled: disabled,
            ),
          ),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 24), child: child),
    ],
  );
}

/// Keeps the platform chip's selection, keyboard and accessibility behavior.
ChoiceChip atlasChoiceChip({
  Key? key,
  required Widget label,
  required bool selected,
  ValueChanged<bool>? onSelected,
  Widget? avatar,
  bool? showCheckmark,
}) => ChoiceChip(
  key: key,
  selected: selected,
  onSelected: onSelected,
  showCheckmark: false,
  padding: EdgeInsets.zero,
  labelPadding: EdgeInsets.zero,
  backgroundColor: Colors.transparent,
  selectedColor: Colors.transparent,
  disabledColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  side: BorderSide.none,
  label: Builder(
    builder: (context) {
      final ink = selected ? const Color(0xfff6ebd3) : const Color(0xff432d21);
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: ink),
          child: IconTheme.merge(
            data: IconThemeData(color: ink),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (avatar != null) ...[avatar, const SizedBox(width: 4)],
                Flexible(child: label),
              ],
            ),
          ),
        ),
      );
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _AtlasButtonArtwork(
                  art: selected ? _primary : _light,
                  skinOnly: true,
                  disabled: onSelected == null,
                ),
              ),
            ),
          ),
          content,
        ],
      );
    },
  ),
);

IconData? _icon(Widget? child) {
  if (child is Icon) return child.icon;
  if (child is BackButtonIcon) return Icons.arrow_back;
  if (child is Container) return _icon(child.child);
  if (child is Material) return _icon(child.child);
  if (child is SingleChildRenderObjectWidget) return _icon(child.child);
  if (child is ProxyWidget) return _icon(child.child);
  return null;
}

bool _selected(Widget? child) {
  if (child is Semantics && child.properties.selected == true) return true;
  if (child is SingleChildRenderObjectWidget) return _selected(child.child);
  if (child is ProxyWidget) return _selected(child.child);
  return false;
}

bool _ancestorSelected(BuildContext context) {
  bool? selected;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Semantics && widget.properties.selected != null) {
      selected = widget.properties.selected;
      return false;
    }
    return true;
  });
  return selected ?? false;
}

class _Art {
  const _Art(
    this.name,
    this.width,
    this.height,
    this.body, {
    this.half,
    this.label,
  });
  final String name;
  final double width, height;
  final Rect body;
  final int? half;
  final String? label;
  String get path => 'assets/tuslar/$name.png';
}

const _light = _Art('yalniz_kaydet', 131, 57, Rect.fromLTWH(12, 10, 107, 27));
const _primary = _Art(
  'devam_et_aktif',
  287,
  75,
  Rect.fromLTWH(12, 10, 263, 45),
);
const _round = _Art('geri', 49, 55, Rect.fromLTWH(12, 10, 25, 25));

_Art? _art(BuildContext context, Set<WidgetState> states) {
  final button = context.widget;
  if (button is! ButtonStyleButton) return null;
  final key = button.key is ValueKey ? (button.key as ValueKey).value : null;
  final text =
      _text(button.child) ??
      _text(context.findAncestorWidgetOfExactType<AtlasButtonCaption>()?.label);
  final icon =
      _icon(button.child) ??
      _icon(context.findAncestorWidgetOfExactType<AtlasButtonCaption>()?.label);
  if (icon == Icons.arrow_back ||
      icon == Icons.arrow_back_ios ||
      icon == Icons.arrow_back_ios_new) {
    return const _Art(
      'geri',
      49,
      55,
      Rect.fromLTWH(12, 10, 25, 25),
      label: 'Geri',
    );
  }
  if (icon == LucideIcons.maximize || icon == Icons.fullscreen) {
    return const _Art(
      'tam_ekran',
      50,
      53,
      Rect.fromLTWH(12, 10, 26, 23),
      label: 'Tam ekran',
    );
  }
  final selected =
      _selected(button.child) ||
      states.contains(WidgetState.selected) ||
      _ancestorSelected(context);
  final disabled = states.contains(WidgetState.disabled);
  if (key == 'coffee-mode-button-false' || key == 'coffee-mode-button-true') {
    final mark = key == 'coffee-mode-button-true';
    return _Art(
      mark == selected ? 'isaret_secili' : 'tasi_secili',
      113,
      59,
      const Rect.fromLTWH(12, 10, 89, 29),
      half: mark ? 1 : 0,
      label: mark ? 'İşaret' : 'Taşı',
    );
  }
  if (key == 'coffee-create-fortune' || text == 'Falımı Oluştur') {
    return const _Art(
      'falimi_olustur',
      287,
      75,
      Rect.fromLTWH(12, 10, 263, 45),
      label: 'Falımı Oluştur',
    );
  }
  if (key == 'coffee-continue-set' || text == 'Bu fotoğraflarla devam et') {
    return _Art(
      disabled ? 'devam_et_pasif' : 'devam_et_aktif',
      287,
      75,
      const Rect.fromLTWH(12, 10, 263, 45),
      label: 'Bu fotoğraflarla devam et',
    );
  }
  final topic = switch (text) {
    'Aşk' => 'ask',
    'İş' => 'is',
    'Para' => 'para',
    _ => null,
  };
  if (topic != null) {
    return _Art(
      'kategori_$topic${selected ? '_secili' : ''}',
      69,
      62,
      const Rect.fromLTWH(12, 10, 45, 32),
      label: text,
    );
  }
  return switch (text) {
    'Bu alanı seç' => const _Art(
      'bu_alani_sec',
      251,
      75,
      Rect.fromLTWH(12, 10, 227, 45),
      label: 'Bu alanı seç',
    ),
    'Yalnız Kaydet' => const _Art(
      'yalniz_kaydet',
      131,
      57,
      Rect.fromLTWH(12, 10, 107, 27),
      label: 'Yalnız Kaydet',
    ),
    'Kalanları geç' => const _Art(
      'kalanlari_gec',
      131,
      57,
      Rect.fromLTWH(12, 10, 107, 27),
      label: 'Kalanları geç',
    ),
    'Taslağı sil' => const _Art(
      'taslagi_sil',
      131,
      57,
      Rect.fromLTWH(12, 10, 107, 27),
      label: 'Taslağı sil',
    ),
    'Galeriden fotoğraf seç' => const _Art(
      'galeriden_fotograf_sec',
      169,
      62,
      Rect.fromLTWH(12, 10, 145, 32),
      label: 'Galeriden fotoğraf seç',
    ),
    'Kameraya geç' => const _Art(
      'kameraya_gec',
      169,
      62,
      Rect.fromLTWH(12, 10, 145, 32),
      label: 'Kameraya geç',
    ),
    'Fotoğraf ekle' => const _Art(
      'fotograf_ekle',
      105,
      54,
      Rect.fromLTWH(12, 10, 81, 24),
      label: 'Fotoğraf ekle',
    ),
    'Kuş' => const _Art(
      'kus_secimi',
      91,
      63,
      Rect.fromLTWH(12, 10, 67, 33),
      label: 'Kuş',
    ),
    'Geri' => const _Art(
      'geri',
      49,
      55,
      Rect.fromLTWH(12, 10, 25, 25),
      label: 'Geri',
    ),
    _ => null,
  };
}

bool _hasProgress(Widget? child) {
  if (child is ProgressIndicator) return true;
  if (child is Container) return _hasProgress(child.child);
  if (child is SingleChildRenderObjectWidget) return _hasProgress(child.child);
  if (child is ProxyWidget) return _hasProgress(child.child);
  if (child is MultiChildRenderObjectWidget) {
    return child.children.any(_hasProgress);
  }
  return false;
}

bool _liveText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) > 14.1 ||
    MediaQuery.boldTextOf(context) ||
    (context.widget is ButtonStyleButton &&
        _hasProgress((context.widget as ButtonStyleButton).child)) ||
    _hasProgress(
      context.findAncestorWidgetOfExactType<AtlasButtonCaption>()?.icon,
    );

Widget _foreground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final art = _art(context, states);
  if (art == null || child == null) return child ?? const SizedBox.shrink();
  final original = Opacity(
    opacity: 0,
    alwaysIncludeSemantics: true,
    child: child,
  );
  return _liveText(context) ? child : original;
}

Widget _background(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final art = _art(context, states);
  final button = context.widget;
  final primary =
      button is FilledButton ||
      states.contains(WidgetState.selected) ||
      (button is ButtonStyleButton &&
          (_selected(button.child) || _ancestorSelected(context)));
  final icon = context.findAncestorWidgetOfExactType<IconButton>();
  return Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: _AtlasButtonArtwork(
              key: ValueKey(
                'atlas-art:${art?.path ?? (icon != null
                        ? _round
                        : primary
                        ? _primary
                        : _light).path}',
              ),
              art: art != null && !_liveText(context)
                  ? art
                  : (icon != null
                        ? _round
                        : primary
                        ? _primary
                        : _light),
              skinOnly: art == null || _liveText(context),
              bottomAligned:
                  art?.half != null ||
                  art?.name.startsWith('kategori_') == true,
              surfaceHeight: context
                  .findAncestorWidgetOfExactType<AtlasButtonCaption>()
                  ?.surfaceHeight,
              disabled:
                  states.contains(WidgetState.disabled) &&
                  art?.name != 'devam_et_pasif',
              pressed: states.contains(WidgetState.pressed),
            ),
          ),
        ),
      ),
      ?child,
    ],
  );
}

/// Full original silhouettes, including their rims and shadows, for photo tools.
class AtlasPhotoHeaderFace extends StatelessWidget {
  const AtlasPhotoHeaderFace({required this.child, this.artwork, super.key});
  final Widget child;
  final String? artwork;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final source = artwork == null
          ? _light
          : const _Art('fotograf_ekle', 105, 54, Rect.fromLTWH(12, 10, 81, 24));
      final fitted = applyBoxFit(
        BoxFit.contain,
        Size(source.width, source.height),
        Size(math.min(160, box.maxWidth), box.maxHeight),
      ).destination;
      final origin = Offset(
        (box.maxWidth - fitted.width) / 2,
        (box.maxHeight - fitted.height) / 2,
      );
      final factor = fitted.width / source.width;
      final body = Rect.fromLTWH(
        origin.dx + source.body.left * factor,
        origin.dy + source.body.top * factor,
        source.body.width * factor,
        source.body.height * factor,
      );
      return Stack(
        children: [
          Positioned.fromRect(
            rect: origin & fitted,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: artwork == null
                    ? _AtlasButtonArtwork(
                        art: _light,
                        skinOnly: true,
                        wholeSkin: true,
                      )
                    : Image.asset(
                        'assets/tuslar/3.0x/$artwork.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: body.deflate(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: artwork == null
                  ? child
                  : Opacity(
                      opacity: 0,
                      alwaysIncludeSemantics: true,
                      child: child,
                    ),
            ),
          ),
        ],
      );
    },
  );
}

/// Paints the supplied PNGs. No source image is changed or regenerated.
/// For new labels only the original blank surface is repeated at render time.
class _AtlasButtonArtwork extends StatefulWidget {
  const _AtlasButtonArtwork({
    required this.art,
    this.skinOnly = false,
    this.bottomAligned = false,
    this.surfaceHeight,
    this.disabled = false,
    this.pressed = false,
    this.wholeSkin = false,
    this.preserveInsets = false,
    super.key,
  });
  final _Art art;
  final bool skinOnly,
      disabled,
      pressed,
      bottomAligned,
      wholeSkin,
      preserveInsets;
  final double? surfaceHeight;
  @override
  State<_AtlasButtonArtwork> createState() => _AtlasButtonArtworkState();
}

class _AtlasButtonArtworkState extends State<_AtlasButtonArtwork> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_AtlasButtonArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.art.path != widget.art.path) _resolve();
  }

  void _resolve() {
    final stream = AssetImage(widget.art.path).resolve(
      createLocalImageConfiguration(context).copyWith(
        devicePixelRatio: math.max(3, MediaQuery.devicePixelRatioOf(context)),
      ),
    );
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: widget.disabled ? .45 : 1,
    child: Transform.scale(
      scale: widget.pressed ? .98 : 1,
      child: CustomPaint(
        painter: _ArtPainter(
          _info?.image,
          widget.art,
          widget.skinOnly,
          widget.bottomAligned,
          MediaQuery.textScalerOf(context).scale(12),
          widget.surfaceHeight,
          widget.wholeSkin,
          widget.preserveInsets,
        ),
      ),
    ),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(
    this.image,
    this.art,
    this.skinOnly,
    this.bottomAligned,
    this.fontSize,
    this.surfaceHeight,
    this.wholeSkin,
    this.preserveInsets,
  );
  final ui.Image? image;
  final _Art art;
  final bool skinOnly, bottomAligned, wholeSkin, preserveInsets;
  final double fontSize;
  final double? surfaceHeight;
  final _paint = Paint()..filterQuality = FilterQuality.high;
  final _surfacePaint = Paint()
    ..filterQuality = FilterQuality.high
    ..blendMode = BlendMode.src;
  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null || size.isEmpty) return;
    if (preserveInsets) {
      // Scale the full cap and shadow vertically as one image; only the blank
      // horizontal centre stretches. The original rounded ends remain intact.
      final scale = size.height / art.height;
      final cap = art.body.left + art.body.height / 2 + 2;
      final targetCap = math.min(cap * scale, size.width / 2);
      final src = [0.0, cap, art.width - cap, art.width];
      final dst = [0.0, targetCap, size.width - targetCap, size.width];
      final density = image.width / art.width;
      for (var col = 0; col < 3; col++) {
        if (dst[col + 1] <= dst[col]) continue;
        canvas.drawImageRect(
          image,
          Rect.fromLTRB(
            src[col] * density,
            0,
            (col == 1 ? src[col] + 1 : src[col + 1]) * density,
            image.height.toDouble(),
          ),
          Rect.fromLTRB(dst[col], 0, dst[col + 1], size.height),
          _paint,
        );
      }
      return;
    }
    if (wholeSkin) {
      final factor = size.width / art.width;
      canvas.save();
      canvas.scale(factor);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, art.width, art.height),
        _paint,
      );
      final density = image.width / art.width;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(29 * density, 18 * density, density, 14 * density),
        const Rect.fromLTRB(35, 18, 97, 32),
        _paint,
      );
      canvas.restore();
      return;
    }
    if (!skinOnly) {
      final body = art.half == null
          ? art.body
          : Rect.fromLTWH(
              art.half == 0 ? art.body.left : art.width / 2,
              art.body.top,
              art.body.width / 2,
              art.body.height,
            );
      final target = applyBoxFit(
        BoxFit.contain,
        body.size,
        Size(
          math.max(1, size.width - (art.half == null ? 6 : 0)),
          math.max(1, size.height - 8),
        ),
      ).destination;
      final factor = target.width / body.width;
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(
        (size.width - target.width) / 2 - body.left * factor,
        (bottomAligned
                ? size.height - target.height - 2
                : (size.height - target.height) / 2 - 1) -
            body.top * factor,
      );
      canvas.scale(factor);
      if (art.half != null) {
        canvas.clipRect(
          Rect.fromLTRB(
            art.half == 0 ? 0 : art.width / 2,
            0,
            art.half == 0 ? art.width / 2 : art.width,
            art.height,
          ),
          doAntiAlias: false,
        );
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, art.width, art.height),
        _paint,
      );
      canvas.restore();
      return;
    }
    // Nine slices preserve caps, rims and shadows; only blank centre stretches.
    final source = art.name == 'geri'
        ? _round
        : art.name == 'devam_et_aktif'
        ? _primary
        : _light;
    final x = source == _round ? 19.0 : 28.0;
    final top = source == _primary
        ? 24.0
        : source == _round
        ? 17.0
        : 18.0;
    final bottom = source == _primary ? 42.0 : 32.0;
    final srcX = [0.0, x, source.width - x, source.width];
    final srcY = [0.0, top, bottom, source.height];
    final height = bottomAligned
        ? math.min(
            size.height - 4,
            surfaceHeight ?? math.max(28.0, fontSize * 1.1 + 4),
          )
        : math.max(1.0, size.height - 10);
    final body = Rect.fromLTWH(
      3,
      bottomAligned ? size.height - height - 2 : (size.height - height) / 2 - 1,
      math.max(1, size.width - 6),
      height,
    );
    final scale = (height / source.body.height).clamp(.5, 1.6);
    final capX = math.min((x - source.body.left) * scale, body.width / 2);
    final capTop = math.min((top - source.body.top) * scale, body.height / 2);
    final capBottom = math.min(
      (source.body.bottom - bottom) * scale,
      body.height / 2,
    );
    final dstX = [
      body.left - source.body.left,
      body.left + capX,
      body.right - capX,
      body.right + source.width - source.body.right,
    ];
    final dstY = [
      body.top - source.body.top,
      body.top + capTop,
      body.bottom - capBottom,
      body.bottom + source.height - source.body.bottom,
    ];
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.clipRect(Offset.zero & size);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final src = Rect.fromLTRB(
          srcX[col],
          srcY[row],
          srcX[col + 1],
          srcY[row + 1],
        );
        final dst = Rect.fromLTRB(
          dstX[col],
          dstY[row],
          dstX[col + 1],
          dstY[row + 1],
        );
        if (src.isEmpty || dst.isEmpty) continue;
        canvas.save();
        canvas.clipRect(dst.inflate(.35), doAntiAlias: false);
        canvas.translate(dst.left, dst.top);
        canvas.scale(dst.width / src.width, dst.height / src.height);
        canvas.translate(-src.left, -src.top);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, source.width, source.height),
          _surfacePaint,
        );
        final label = source == _primary
            ? const Rect.fromLTRB(70, 25, 219, 42)
            : source == _round
            ? const Rect.fromLTRB(19, 17, 31, 32)
            : const Rect.fromLTRB(35, 18, 97, 32);
        final sampleX = source == _primary
            ? 35.0
            : source == _round
            ? 17.0
            : 29.0;
        final density = image.width / source.width;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            sampleX * density,
            label.top * density,
            density,
            label.height * density,
          ),
          label,
          _surfacePaint,
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.image != image ||
      old.art != art ||
      old.skinOnly != skinOnly ||
      old.bottomAligned != bottomAligned ||
      old.fontSize != fontSize ||
      old.surfaceHeight != surfaceHeight ||
      old.wholeSkin != wholeSkin ||
      old.preserveInsets != preserveInsets;
}
