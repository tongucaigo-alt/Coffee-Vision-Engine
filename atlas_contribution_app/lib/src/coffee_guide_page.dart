import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'atlas_design.dart';
import 'label_picker.dart';
import 'guide_additional_pages.dart';
import 'guide_camera_scan.dart';

const _cupAsset = 'assets/guide/example-cup.png';
const _titles = [
  'Atlas’a hoş geldin',
  'İlk fotoğrafın',
  'Işığı kontrol et',
  'Yakından bak',
  'Fotoğrafı taşı',
  'Şekli seç',
  'Kutuyu düzelt',
  'Bilgilerim',
  'Kaldığın yerden devam et',
  'Kayıtlarını bul',
  'Tarot’u keşfet',
  'Yardım ve bildirim',
  'Devam et',
];
const _messages = [
  'Fincanının hikâyesini birlikte keşfedelim.',
  'Telvenin yoğun olduğu bölgeyi göster.',
  'Fotoğraf karanlıksa flaşı dene.',
  'İki parmağını açarak büyüt, yaklaştırarak küçült.',
  'Fotoğrafı kaydırmak için Taşı’yı seç.',
  'Gördüğün yere dokun, benzettiğin şekli seç.',
  'Kutuyu şekle göre düzelt.',
  'Bilgilerim’i istersen doldur, istersen boş bırak.',
  '▶ ile yarım kalan kahvene veya Tarot açılımına dön.',
  'Kayıtlarım’dan kahve ve Tarot geçmişine ulaş.',
  'Günün Kartı veya Üç Kart ile kartlarını kendin seç.',
  'Gizlilik, destek ve bildirim seçeneklerini Ayarlar’da bul.',
  'İşaretlemeden de fal oluşturabilirsin.',
];

// Preserve the original demonstrations while extending the guide's contents.
const _illustrations = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 7];
final int coffeeGuideCardCount = _titles.length;

/// A demonstration only: no camera, annotation, AI or consent callbacks.
class CoffeeGuidePage extends StatefulWidget {
  const CoffeeGuidePage({
    required this.onComplete,
    this.allowSuppression = false,
    this.allowClose = false,
    this.onClose,
    super.key,
  });
  final Future<void> Function(bool dontShowAgain) onComplete;
  final bool allowSuppression, allowClose;
  final VoidCallback? onClose;

  @override
  State<CoffeeGuidePage> createState() => _CoffeeGuidePageState();
}

class _CoffeeGuidePageState extends State<CoffeeGuidePage> {
  int _index = 0;
  bool _suppress = false, _finishing = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (_finishing) return;
    setState(() => _index = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _next() async {
    if (_finishing) return;
    if (_index < coffeeGuideCardCount - 1) {
      _go(_index + 1);
      return;
    }
    setState(() => _finishing = true);
    try {
      await widget.onComplete(widget.allowSuppression && _suppress);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.allowClose && _index == 0 && !_finishing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_finishing && _index > 0) _go(_index - 1);
    },
    child: Scaffold(
      key: const ValueKey('coffee-guide-page'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/brand/atlas-logo.png',
                            width: 40,
                            height: 40,
                            semanticLabel: 'Atlas',
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atlas',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Kahve Ritüeli',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: atlasCopperInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.allowClose)
                    IconButton(
                      tooltip: 'Rehberi kapat',
                      onPressed: _finishing ? null : widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('coffee-guide-scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: CustomPaint(
                        foregroundPainter: const _GuideFrame(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
                          child: Column(
                            children: [
                              if (_index == 0) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(42),
                                    child: Image.asset(
                                      'assets/brand/atlas-logo.png',
                                      width: 176,
                                      height: 176,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ],
                              Semantics(
                                header: true,
                                liveRegion: true,
                                child: Text(
                                  _titles[_index],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Literata',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _messages[_index],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: atlasMuted,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _GuideIllustration(
                                key: ValueKey(_index),
                                index: _illustrations[_index],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Rehber, ${_index + 1} / $coffeeGuideCardCount',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < coffeeGuideCardCount; i++)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _index ? atlasCoffee : atlasCream,
                                  border: Border.all(
                                    color: i == _index
                                        ? atlasCoffee
                                        : atlasCopper,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_index == coffeeGuideCardCount - 1 &&
                          widget.allowSuppression)
                        CheckboxListTile(
                          key: const ValueKey('guide-dont-show-again'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Bir daha gösterme'),
                          value: _suppress,
                          onChanged: _finishing
                              ? null
                              : (value) =>
                                    setState(() => _suppress = value ?? false),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_index > 0) ...[
                            TextButton(
                              onPressed: _finishing
                                  ? null
                                  : () => _go(_index - 1),
                              child: const Text('Geri'),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: FilledButton(
                              key: const ValueKey('guide-next'),
                              onPressed: _finishing ? null : _next,
                              child: Text(
                                _index == coffeeGuideCardCount - 1
                                    ? 'Başlayalım'
                                    : 'İleri',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideIllustration extends StatefulWidget {
  const _GuideIllustration({required this.index, super.key});
  final int index;
  @override
  State<_GuideIllustration> createState() => _GuideIllustrationState();
}

class _GuideIllustrationState extends State<_GuideIllustration>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _reduced = false, _initialized = false;
  bool get _animated => [1, 3, 4, 5, 6].contains(widget.index);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!_initialized || reduced != _reduced) {
      _initialized = true;
      _reduced = reduced;
      if (_reduced) {
        _animation.stop();
      } else if (_animated) {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Widget _sample(String text, IconData icon, {bool active = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? atlasSageSurface : atlasCard,
          border: Border.all(color: atlasBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: atlasSageInk),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: atlasSageInk),
              ),
            ),
          ],
        ),
      );

  Widget _wrap(List<Widget> children) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: children,
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) {
      final progress = _reduced ? .5 : _animation.value;
      return Column(
        children: [
          if (widget.index >= 8) ...[
            GuideAdditionalPage(kind: widget.index),
          ] else if (widget.index == 0) ...[
            _wrap([
              _sample('Fincanını Tara', Icons.camera_alt_outlined),
              _sample('Galeriden Seç', Icons.photo_library_outlined),
            ]),
            const SizedBox(height: 12),
            const Text(
              'Galeri: 1–3 fincan + isteğe bağlı 1 tabak',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: atlasMuted),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tek fincanla da devam edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: atlasSageInk),
            ),
            const SizedBox(height: 12),
            _sample('Açılış videosu · Dokunarak geç', Icons.touch_app_outlined),
          ] else if (widget.index == 2) ...[
            _wrap([
              _sample('Kapalı', Icons.flash_off),
              _sample('Otomatik', Icons.flash_auto),
              _sample('Açık ışık', Icons.flash_on),
            ]),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _lightExample(false)),
                const SizedBox(width: 12),
                Expanded(child: _lightExample(true)),
              ],
            ),
          ] else if (widget.index == 7) ...[
            _wrap([
              _sample('Göremedim', Icons.visibility_off_outlined),
              _sample('Emin değilim', Icons.help_outline),
              _sample('Bu fotoğrafı geç', Icons.skip_next_outlined),
              _sample('Kalanları geç', Icons.last_page),
            ]),
            const SizedBox(height: 18),
            _sample('Falımı Oluştur', Icons.auto_awesome, active: true),
            const SizedBox(height: 8),
            const Text(
              'Kayıt → Hazırlık → Fal sonucu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: atlasCoffee),
            ),
            const SizedBox(height: 16),
            _sample('Yalnız Kaydet', Icons.save_outlined),
            const SizedBox(height: 8),
            const Text(
              'Fal üretmeden telefona kaydeder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: atlasMuted),
            ),
            const SizedBox(height: 16),
            _wrap([
              _sample('Kahve', Icons.home_outlined),
              _sample('Kayıtlarım', Icons.history),
              _sample('Ayarlar', Icons.settings_outlined),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Hazır falını Kayıtlarım’dan tekrar okuyabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: atlasMuted),
            ),
          ] else ...[
            if (widget.index >= 4) ...[
              _wrap([
                _sample(
                  'Taşı',
                  Icons.pan_tool_alt_outlined,
                  active: widget.index == 4,
                ),
                _sample(
                  'İşaret',
                  Icons.touch_app_outlined,
                  active: widget.index >= 5,
                ),
              ]),
              const SizedBox(height: 12),
            ],
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.index == 1 || widget.index == 5 ? 230 : 480,
                ),
                child: _photo(progress),
              ),
            ),
            if (widget.index == 1) ...[
              const SizedBox(height: 12),
              const Text(
                'Yeşil noktalar telve taramasını gösterir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: atlasSageInk,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sembol sonucu veya çekim onayı değildir; kamera yönlendirmesini izle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: atlasMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              _wrap([
                _sample('Serbest açı', Icons.camera_alt_outlined),
                _sample('Kulp sağda', Icons.arrow_forward),
                _sample('Kulp solda', Icons.arrow_back),
                _sample('Tabak · isteğe bağlı', Icons.add_circle_outline),
                _sample('Önizleme', Icons.photo_outlined),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Fincan sabit · Kamera hareketli',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: atlasSageInk,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Önizlemede fotoğrafın netliğini kontrol et.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: atlasMuted, height: 1.5),
              ),
            ],
            if (widget.index == 5) ...[
              const SizedBox(height: 12),
              _picker(progress),
            ],
            if (_animated && !_reduced)
              TextButton.icon(
                key: const ValueKey('guide-replay'),
                onPressed: () => _animation.forward(from: 0),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Tekrar göster'),
              ),
          ],
        ],
      );
    },
  );

  Widget _lightExample(bool glare) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _cupAsset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              if (glare)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(.35, -.35),
                      radius: .7,
                      colors: [
                        Colors.white,
                        Color(0xe6ffffff),
                        Color(0x00ffffff),
                      ],
                    ),
                  ),
                ),
              const Positioned(
                bottom: 6,
                left: 4,
                right: 4,
                child: _ExampleLabel(),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Icon(
        glare ? Icons.close : Icons.check,
        color: glare ? atlasCopperInk : atlasSageInk,
      ),
      Text(
        glare ? 'Parlama' : 'Telve görünür',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
    ],
  );

  Widget _photo(double t) {
    var zoom = 1.0;
    var pan = Offset.zero;
    if (widget.index == 3) {
      final wave = _reduced ? .7 : math.sin(math.pi * t);
      zoom = 1 + .7 * wave;
    } else if (widget.index == 4) {
      zoom = 1.6;
      pan = Offset(
        -.12 * (_reduced ? 1 : math.sin(math.pi * t)),
        .06 * (_reduced ? 1 : math.sin(math.pi * t)),
      );
    }
    final description = switch (widget.index) {
      1 =>
        'Örnek fincan: yoğun telve üst sağda. Yeşil noktalar telve taramasının görsel yardımıdır; sembol sonucu veya çekim onayı değildir. Fincan sabit kalır, kamera yönlendirilir.',
      3 =>
        'İki parmak birbirinden uzaklaşınca örnek fotoğraf büyür, yaklaşınca küçülür.',
      4 => 'Taşı modunda tek parmak örnek fotoğrafı kaydırır.',
      5 => 'İşaret modunda dokununca küçük kutu ve şekil listesi açılır.',
      _ =>
        'Seçilmiş kutu önce ortasından taşınır, sonra köşesinden boyutlandırılır.',
    };
    return Semantics(
      label: description,
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(pan.dx * box.maxWidth, pan.dy * box.maxHeight),
                  child: Transform.scale(
                    scale: zoom,
                    child: Image.asset(_cupAsset, fit: BoxFit.cover),
                  ),
                ),
                if (widget.index == 1)
                  GuideCameraScan(
                    progress: t,
                    playing: _animation.isAnimating,
                    reducedMotion: _reduced,
                  ),
                CustomPaint(
                  painter: _GesturePainter(widget.index, t, _reduced),
                ),
                const Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _ExampleLabel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picker(double t) => Opacity(
    opacity: _reduced || t >= .3 ? 1 : 0,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: atlasCard,
        border: Border.all(color: atlasBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'Neye benziyor?',
            style: TextStyle(fontFamily: 'Literata', fontSize: 18),
          ),
          const SizedBox(height: 12),
          _sample('Şekil ara', Icons.search),
          const SizedBox(height: 12),
          _wrap([
            for (final entry in [
              ('bird', 'Kuş'),
              ('heart', 'Kalp'),
              ('tree', 'Ağaç'),
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: atlasCream,
                  border: Border.all(color: atlasBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LabelIcon(entry.$1, size: 20),
                    const SizedBox(width: 6),
                    Text(entry.$2, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            _sample('Emin değilim', Icons.help_outline),
          ]),
          const SizedBox(height: 10),
          const Text(
            'Bu listede “Emin değilim”: alanı isimsiz işaretler.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: atlasMuted),
          ),
        ],
      ),
    ),
  );
}

class _ExampleLabel extends StatelessWidget {
  const _ExampleLabel();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: atlasCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Örnek gösterim',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: atlasCoffee),
      ),
    ),
  );
}

class _GesturePainter extends CustomPainter {
  _GesturePainter(this.index, this.t, this.reduced);
  final int index;
  final double t;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    Offset point(double x, double y) => Offset(x * size.width, y * size.height);
    final ink = Paint()
      ..color = atlasSageInk
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void line(Offset from, Offset to) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = atlasCard
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(from, to, ink);
    }

    void arrow(Offset from, Offset to) {
      line(from, to);
      final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
      for (final turn in [-.65, .65]) {
        line(
          to,
          to - Offset(math.cos(angle + turn), math.sin(angle + turn)) * 12,
        );
      }
    }

    void touch(Offset at) {
      canvas.drawCircle(
        at,
        13,
        Paint()..color = atlasCard.withValues(alpha: .82),
      );
      canvas.drawCircle(at, 13, ink);
    }

    void box(Rect rect) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = atlasCard
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke,
      );
      canvas.drawRect(rect, ink);
      for (final corner in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        canvas.drawCircle(corner, 4, Paint()..color = atlasCard);
      }
    }

    if (index == 1) {
      arrow(point(.88, .13), point(.76, .25));
      final travel = reduced ? .5 : math.sin(math.pi * t);
      canvas.drawCircle(
        point(.17 + .09 * travel, .2),
        17,
        Paint()..color = atlasCard,
      );
      final camera = point(.17 + .09 * travel, .2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: camera, width: 23, height: 16),
          const Radius.circular(3),
        ),
        ink,
      );
      canvas.drawCircle(camera, 4, ink);
      canvas.drawLine(
        camera + const Offset(-5, -8),
        camera + const Offset(-3, -11),
        ink,
      );
      canvas.drawLine(
        camera + const Offset(-3, -11),
        camera + const Offset(4, -11),
        ink,
      );
      canvas.drawLine(
        camera + const Offset(4, -11),
        camera + const Offset(6, -8),
        ink,
      );
    } else if (index == 3) {
      final spread = reduced ? .7 : math.sin(math.pi * t);
      final first = point(.5 - .13 * spread, .5 + .13 * spread);
      final second = point(.5 + .13 * spread, .5 - .13 * spread);
      touch(first);
      touch(second);
      final outward = reduced || t <= .5;
      arrow(
        first + Offset(-12, 12),
        first + (outward ? const Offset(-40, 40) : const Offset(6, -6)),
      );
      arrow(
        second + Offset(12, -12),
        second + (outward ? const Offset(40, -40) : const Offset(-6, 6)),
      );
    } else if (index == 4) {
      final move = reduced ? 1.0 : math.sin(math.pi * t);
      final at = point(.6 - .12 * move, .5 + .06 * move);
      touch(at);
      arrow(at + const Offset(-18, 9), at + const Offset(-52, 26));
    } else if (index == 5) {
      final center = point(.66, .36);
      if (reduced || (t > .15 && t < .35)) touch(center);
      if (reduced || t >= .3) {
        box(
          Rect.fromCenter(
            center: center,
            width: size.width * .15,
            height: size.height * .15,
          ),
        );
      }
    } else if (index == 6) {
      // First move the center without resizing; then drag only the bottom-right.
      final move = reduced ? 1.0 : ((t - .1) / .3).clamp(0.0, 1.0);
      final resize = reduced ? 1.0 : ((t - .6) / .25).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(
        size.width * (.42 + .09 * move),
        size.height * (.42 - .09 * move),
        size.width * (.15 + .12 * resize),
        size.height * (.15 + .09 * resize),
      );
      box(rect);
      if (reduced) {
        arrow(rect.center - const Offset(38, -38), rect.center);
        arrow(rect.bottomRight, rect.bottomRight + const Offset(22, 18));
      } else if (t < .5) {
        touch(rect.center);
      } else {
        touch(rect.bottomRight);
      }
    }
  }

  @override
  bool shouldRepaint(_GesturePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.index != index ||
      oldDelegate.reduced != reduced;
}

class _GuideFrame extends CustomPainter {
  const _GuideFrame();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = atlasCopper.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(2),
        const Radius.circular(26),
      ),
      line,
    );
    for (final right in [false, true]) {
      for (final bottom in [false, true]) {
        canvas.save();
        canvas.translate(right ? size.width : 0, bottom ? size.height : 0);
        canvas.scale(right ? -1 : 1, bottom ? -1 : 1);
        canvas.drawPath(
          Path()
            ..moveTo(8, 42)
            ..lineTo(8, 30)
            ..quadraticBezierTo(8, 8, 30, 8)
            ..lineTo(48, 8),
          line,
        );
        canvas.restore();
      }
    }
    final center = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(center - 52, 0, 104, 14),
      Paint()..color = atlasCream,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center, 4)
        ..lineTo(center + 3, 8)
        ..lineTo(center, 12)
        ..lineTo(center - 3, 8)
        ..close(),
      line,
    );
    final leaf = Paint()..color = atlasSage.withValues(alpha: .25);
    for (final direction in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final x = center + direction * (16 + i * 10);
        canvas.save();
        canvas.translate(x, 8);
        canvas.rotate(direction * -.45);
        canvas.drawOval(const Rect.fromLTWH(-3, -6, 6, 12), leaf);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_GuideFrame oldDelegate) => false;
}
