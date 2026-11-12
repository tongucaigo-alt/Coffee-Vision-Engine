import 'dart:async';

import 'annotation_page.dart';
import 'atlas_design.dart';
import 'label_picker.dart';
import 'models.dart';
import 'photo_navigation.dart';
import 'umay_home_tour.dart';
import 'package:flutter/material.dart';

const umayAnnotationSteps = <UmayTourStep>[
  UmayTourStep(
    target: 'annotation-viewport',
    message: 'Bu örnek fotoğrafı iki parmağınla büyütüp küçültebilirsin.',
    radius: 14,
    targetLabel: 'Örnek fotoğraf. Tanıtıma devam et.',
  ),
  UmayTourStep(
    target: 'coffee-mode-surface-false',
    message:
        'Taşı’yı seçince büyüttüğün fotoğrafı tek parmağınla kaydırabilirsin. Böylece farklı yerlere yakından bakabiliriz.',
  ),
  UmayTourStep(
    target: 'coffee-mode-surface-true',
    message:
        'Bir şekil gördüğünde İşaret’i seçip fotoğrafta o yere dokun. Açılan listeden neye benzediğini seçebilirsin.',
  ),
  UmayTourStep(
    target: 'coffee-label-bird',
    message:
        'Dokunduğun alan için bir şekil seç. Örneğin Kuş’u seçersen o alana bir Kuş işareti eklenir.',
    fallback:
        'Dokunduğun alan için listeden bir şekil seçebilirsin. Kuş, Kalp veya sana en yakın gelen başka bir şekil olabilir.',
  ),
  UmayTourStep(
    target: 'coffee-label-search',
    message:
        'Aradığın şeklin adını buraya yazabilirsin. Üstteki başlıklardan hayvanlara, doğaya ve diğer şekillere de bakabilirsin.',
  ),
  UmayTourStep(
    target: 'resize-corner-0',
    message:
        'Örnek olarak bir alanı Kuş diye işaretledik. Kutuyu köşelerinden çekerek düzelt; ortasından tutarak yerini değiştir.',
    fallback:
        'Seçili kutuyu köşelerinden çekerek büyütebilir veya küçültebilirsin. Ortasından tutarak yerini değiştirebilirsin.',
    targetLabel: 'İşaret kutusunun köşesi. Tanıtıma devam et.',
  ),
  UmayTourStep(
    target: 'coffee-region-guide-bird',
    message:
        'Seçtiğin şekiller burada birikir. Bir şeklin adına dokununca fotoğraftaki kutusu seçilir; yeniden dokununca seçim kapanır.',
  ),
  UmayTourStep(
    target: 'coffee-change-region',
    message:
        'Bu şekil başka bir şeye benziyorsa Değiştir’e dokun. Aynı kutu için listeden yeni bir şekil seçebilirsin.',
  ),
  UmayTourStep(
    target: 'coffee-remove-region',
    message:
        'Bu işareti istemiyorsan Kaldır’a dokun. Yalnızca seçtiğin işaret kaldırılır; fotoğrafın silinmez.',
  ),
  UmayTourStep(
    target: 'coffee-focus-surface-Aşk',
    message:
        'İstersen falında Aşk, İş veya Para konusuna ağırlık verebilirsin. Seçtiğin konuya yeniden dokunarak seçimini kaldırabilirsin.',
  ),
  UmayTourStep(
    target: 'coffee-next-photo',
    message:
        'Sağ okla sonraki, sol okla önceki fotoğrafa geçebilirsin. Her fotoğrafın işaretleri kendisine bağlı kalır.',
  ),
  UmayTourStep(
    target: 'coffee-zoom-control',
    message:
        'Çok yakınlaştıysan bu tuş fotoğrafı yeniden ekrana sığdırır. Eklediğin işaretler korunur.',
  ),
  UmayTourStep(
    target: 'coffee-not-seen',
    message:
        'Fotoğrafta bir şekil göremiyorsan Göremedim’i seçebilirsin. Bir şey işaretlemek zorunda değilsin; sonraki fotoğrafa geçeriz.',
  ),
  UmayTourStep(
    target: 'coffee-uncertain',
    message:
        'Bir şekil var gibi ama neye benzediğinden emin değil misin? Emin değilim’i seçip sonraki fotoğrafa geçebilirsin.',
  ),
  UmayTourStep(
    target: 'coffee-skip-photo',
    message:
        'Bu fotoğrafa şimdi bakmak istemiyorsan Bu fotoğrafı geç’i seçebilirsin. Fotoğraf silinmez.',
  ),
  UmayTourStep(
    target: 'coffee-save-only',
    message:
        'Yalnız Kaydet, fotoğraflarını ve seçtiğin şekilleri kaydeder. Falını hemen oluşturmak istemediğinde bunu kullanabilirsin.',
  ),
  UmayTourStep(
    target: 'coffee-skip-remaining',
    message:
        'Kalanları geç, henüz bakmadığın fotoğrafları atlayıp bu ekrandan çıkarır. Buradan fal oluşturulmaz.',
  ),
  UmayTourStep(
    target: 'coffee-create-fortune',
    message:
        'Hazır olduğunda Falımı Oluştur’a dokunabilirsin. İşaretleme isteğe bağlı; istersen hiç şekil seçmeden de falını oluşturabilirsin.',
  ),
];

/// The guide has no app store, backend, camera, gallery or generation runtime.
class AnnotationGuideAudit {
  int draftChanges = 0, finishActions = 0, saveActions = 0, skipActions = 0;
  int photoChanges = 0, focusChanges = 0;
}

class UmayAnnotationGuide extends StatefulWidget {
  const UmayAnnotationGuide({
    required this.onFinish,
    this.audit,
    this.onPresented,
    super.key,
  });
  final void Function(bool completed) onFinish;
  final AnnotationGuideAudit? audit;
  final VoidCallback? onPresented;
  @override
  State<UmayAnnotationGuide> createState() => _UmayAnnotationGuideState();
}

class _UmayAnnotationGuideState extends State<UmayAnnotationGuide> {
  int _step = 0;
  late final _audit = widget.audit ?? AnnotationGuideAudit();
  @override
  Widget build(BuildContext context) => UmayHomeTour(
    steps: umayAnnotationSteps,
    onFinish: widget.onFinish,
    onPresented: widget.onPresented,
    onStepChanged: (step) => setState(() => _step = step),
    child: Theme(
      data: coffeeFlowTheme(Theme.of(context)),
      child: _AnnotationGuideScene(
        key: ValueKey(_step),
        step: _step,
        audit: _audit,
      ),
    ),
  );
}

class _AnnotationGuideScene extends StatefulWidget {
  const _AnnotationGuideScene({
    required this.step,
    required this.audit,
    super.key,
  });
  final int step;
  final AnnotationGuideAudit audit;
  @override
  State<_AnnotationGuideScene> createState() => _AnnotationGuideSceneState();
}

class _AnnotationGuideSceneState extends State<_AnnotationGuideScene> {
  final _pageKey = GlobalKey();
  BuildContext? _pageContext;

  bool get _hasRegion => [5, 6, 7, 8, 15, 17].contains(widget.step);

  ContributionPhoto get _photo => ContributionPhoto(
    role: CaptureRole.free,
    localName: 'umay-guide-cup.jpg',
    checksum: 'sha256:${'a' * 64}',
    originalChecksum: 'sha256:${'a' * 64}',
    width: 1254,
    height: 1254,
    byteLength: 1,
    capturedAt: '2026-01-01T00:00:00Z',
    decision: _hasRegion ? PhotoDecision.marked : PhotoDecision.unreviewed,
    regions: _hasRegion
        ? [
            RegionAnnotation(
              id: 'guide-bird',
              label: 'bird',
              box: RegionBox(.42, .32, .24, .24),
            ),
          ]
        : const [],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.step == 1) {
        _find<TextButton>('coffee-mode-button-false')?.onPressed?.call();
      }
      if ([5, 7, 8].contains(widget.step)) {
        _find<ChoiceChip>('coffee-region-guide-bird')?.onSelected?.call(true);
      }
      if (widget.step == 3 || widget.step == 4) {
        unawaited(pickContributionLabel(_pageContext!).then<void>((_) {}));
      }
    });
  }

  // Configure only the disposable sample via the real controls' local callbacks.
  // Neither these setup actions nor the guide invoke a save or completion action.
  T? _find<T extends Widget>(String key) {
    T? result;
    void visit(Element e) {
      if (e.widget.key == ValueKey(key) && e.widget is T) {
        result = e.widget as T;
      }
      e.visitChildren(visit);
    }

    (_pageKey.currentContext as Element?)?.visitChildren(visit);
    return result;
  }

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (pageContext) {
        _pageContext = pageContext;
        return AnnotationPage(
          key: _pageKey,
          modern: true,
          photo: _photo,
          image: const AssetImage('assets/guide/example-cup.png'),
          onSave: (_) async {
            widget.audit.draftChanges++;
          },
          onComplete: () {
            widget.audit.photoChanges++;
          },
          onFinish: () {
            widget.audit.finishActions++;
          },
          onSaveOnly: () {
            widget.audit.saveActions++;
          },
          onSkip: () {
            widget.audit.skipActions++;
          },
          onFocusChanged: (_) {
            widget.audit.focusChanges++;
          },
          navigation: Builder(
            builder: (context) => PhotoNavigation(
              index: 1,
              count: 3,
              overlay: true,
              bottomInset: MediaQuery.textScalerOf(context).scale(14) > 19
                  ? 80
                  : 8,
              onSelect: (_) {
                widget.audit.photoChanges++;
              },
            ),
          ),
        );
      },
    ),
  );
}
