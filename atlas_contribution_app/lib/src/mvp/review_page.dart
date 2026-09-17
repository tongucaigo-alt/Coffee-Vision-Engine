import 'dart:convert';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../annotation_page.dart';
import '../cropped_photo.dart';
import '../gallery_import.dart';
import '../local_store.dart';
import '../models.dart';
import '../photo_view.dart';
import '../theme.dart';
import 'review_controller.dart';
import 'review_capture_settings.dart';
import 'review_gallery.dart';
import 'review_models.dart';
import 'review_store.dart';

class ReviewHub extends StatefulWidget {
  const ReviewHub({required this.store, required this.captureStore, super.key});
  final ReviewStore store;
  final DraftStore captureStore;
  @override
  State<ReviewHub> createState() => _ReviewHubState();
}

class _ReviewHubState extends State<ReviewHub> {
  List<ReviewSession> _sessions = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(recover: true);
  }

  Future<void> _load({bool recover = false}) async {
    try {
      await widget.store.initialize();
      if (recover) {
        await ReviewGallery(widget.store, AndroidGalleryPicker()).recover();
      }
      _sessions = (await widget.store.sessions())
          .where((s) => !s.deleted)
          .toList();
    } catch (_) {
      _error = 'Kayıt açılamadı. Mevcut dosyaların korundu.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(ReviewSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          controller: ReviewController(store: widget.store, session: session),
          captureStore: widget.captureStore,
        ),
      ),
    );
    await _load();
  }

  Future<void> _new({String? groupId}) async {
    var local = false, research = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Yeni inceleme'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: local,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Fotoğraflarımın bu telefonda analiz edilmesini ve saklanmasını kabul ediyorum.',
                  ),
                  onChanged: (v) => setLocal(() => local = v ?? false),
                ),
                CheckboxListTile(
                  value: research,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'İsteğe bağlı: araştırma ve gelecekteki model geliştirme için dışa aktarmaya izin veriyorum.',
                  ),
                  onChanged: (v) => setLocal(() => research = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: local ? () => Navigator.pop(context, true) : null,
              child: const Text('Başla'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final s = ReviewSession(
      id: const Uuid().v4(),
      groupId: groupId ?? const Uuid().v4(),
      createdAtUtc: now,
      localConsentAtUtc: now,
      researchConsentAtUtc: research ? now : null,
    );
    try {
      await widget.store.save(s);
      if (mounted) await _open(s);
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'İnceleme açılamadı. Kayıt sınırını ve boş alanı kontrol et.',
        );
      }
    }
  }

  Future<void> _delete(ReviewSession s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İnceleme silinsin mi?'),
        content: const Text(
          'Fotoğraflar bu telefondan silinecek. Önceden dışa aktardığın paketleri ayrıca silmelisin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.store.delete(s);
      await _load();
    } catch (_) {
      if (mounted) {
        showNotice(context, 'Silme tamamlanamadı. Tekrar deneyebilirsin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fincanı incele')),
    body: PageBody(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        FilledButton.icon(
          onPressed: _busy || _error != null ? null : () => _new(),
          icon: const Icon(LucideIcons.plus),
          label: const Text('Yeni inceleme'),
        ),
        const SizedBox(height: 16),
        for (final s in _sessions) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('İnceleme · ${s.createdAtUtc.split('T').first}'),
            subtitle: Text(
              '${s.photos.length} fotoğraf · ${s.photos.where((p) => p.analyzed).length} analiz',
            ),
            trailing: IconButton(
              tooltip: 'İncelemeyi sil',
              onPressed: () => _delete(s),
              icon: const Icon(LucideIcons.trash2),
            ),
            onTap: () => _open(s),
          ),
          TextButton(
            onPressed: () => _new(groupId: s.groupId),
            child: const Text('Aynı fincanı tekrar incele'),
          ),
          const Divider(),
        ],
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final result = await widget.store.exportToDownloads();
                    if (context.mounted) {
                      showNotice(
                        context,
                        '${result.count} izinli inceleme İndirilenler klasöründe: ${result.name}',
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      showNotice(
                        context,
                        'Paket hazırlanamadı veya dışa aktarma izni olan kayıt yok.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          icon: const Icon(LucideIcons.download),
          label: const Text('İzinli incelemeleri dışa aktar'),
        ),
      ],
    ),
  );
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    required this.controller,
    required this.captureStore,
    super.key,
  });
  final ReviewController controller;
  final DraftStore captureStore;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late ReviewController _controller = widget.controller;
  bool _working = false;
  ReviewSession get session => _controller.session;
  bool get busy => _working || _controller.busy;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'İşlem tamamlanamadı. Son kaydedilen inceleme korundu.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save(ReviewSession next) => _controller.save(next);
  Future<void> _reload() async {
    final current = (await _controller.store.sessions()).singleWhere(
      (s) => s.id == session.id,
    );
    _controller.removeListener(_changed);
    _controller.dispose();
    _controller = ReviewController(
      store: widget.controller.store,
      session: current,
    )..addListener(_changed);
  }

  Future<void> _camera({ReviewPhoto? replace}) async {
    final used = session.photos
        .where((p) => p.id != replace?.id)
        .map((p) => p.declaredRole)
        .toSet();
    final role = replace?.declaredRole ?? nextReviewCaptureRole(used);
    final capture = await showCoffeeCamera(
      context,
      captureTitle: reviewCaptureTitle(role),
      captureInstruction: reviewCaptureInstruction(role),
      config: reviewCameraConfig(role),
    );
    if (capture == null) return;
    final p = await _controller.store.importPhoto(
      await File(capture.filePath).readAsBytes(),
      surface: ReviewSurface.cup,
      declaredRole: role,
      capture: capture,
    );
    await _save(
      session.next(
        photos: [
          for (final old in session.photos)
            if (old.id == replace?.id) p else old,
          if (replace == null) p,
        ],
      ),
    );
    await widget.captureStore.releaseCapture(capture);
  }

  Future<void> _gallery(ReviewSurface surface, {ReviewPhoto? replace}) async {
    CaptureRole? role = replace?.declaredRole;
    if (surface == ReviewSurface.cup) {
      final selected = await showDialog<String>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Fotoğrafın açısı'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'unknown'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Açı belirtilmedi'),
              ),
            ),
            for (final r in CaptureRole.values)
              if (!session.photos.any(
                (p) =>
                    p.id != replace?.id &&
                    (p.declaredRole == CaptureRole.top
                            ? CaptureRole.free
                            : p.declaredRole) ==
                        (r == CaptureRole.top ? CaptureRole.free : r),
              ))
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(r.title),
                  ),
                ),
          ],
        ),
      );
      if (selected == null) return;
      role = selected == 'unknown' ? null : CaptureRole.values.byName(selected);
    }
    await ReviewGallery(
      _controller.store,
      AndroidGalleryPicker(),
    ).select(session, surface, role, replaceId: replace?.id);
    await _reload();
  }

  Future<void> _annotate(ReviewPhoto p) async {
    await _controller.store.readPhoto(p);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnnotationPage(
          photo: p.photo,
          displayCrop: p.displayCrop,
          image: FileImage(_controller.store.file(p.photo.localName)),
          onSave: (photo) => _save(
            session.withPhoto(
              p.update(photo: photo, exposed: p.feedback.isNotEmpty),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _candidates(ReviewPhoto photo) async {
    if (session.currentInitialObservation == null) {
      throw StateError('Initial observations must be saved before suggestions');
    }
    var p = photo;
    final symbols = (p.analysis!['symbols'] as List).cast<Map>();
    final now = DateTime.now().toUtc().toIso8601String();
    p = p.update(
      feedback: [
        for (final s in symbols)
          p.feedback.where((f) => f.candidateKey == s['key']).firstOrNull ??
              CandidateFeedback(
                candidateKey: s['key'] as String,
                runId: p.analysis!['runId'] as String,
                answer: CandidateAnswer.unanswered,
                exposedAtUtc: now,
              ),
      ],
    );
    await _save(session.withPhoto(p));
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, setLocal) => Scaffold(
            appBar: AppBar(title: const Text('Görsel çağrışım adayları')),
            body: PageBody(
              children: [
                for (final s in symbols) ...[
                  MarkedPhoto(
                    displayCrop: p.displayCrop,
                    photo: p.photo.annotated(
                      [
                        if (s['box'] != null)
                          RegionAnnotation(
                            id: 'engine-region',
                            box: RegionBox.fromJson(
                              Map<String, dynamic>.from(s['box'] as Map),
                            ),
                          ),
                      ],
                      s['box'] == null
                          ? PhotoDecision.unreviewed
                          : PhotoDecision.marked,
                    ),
                    image: FileImage(_controller.store.file(p.photo.localName)),
                  ),
                  Text(
                    s['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  DropdownButtonFormField<CandidateAnswer>(
                    initialValue: p.feedback
                        .singleWhere((f) => f.candidateKey == s['key'])
                        .answer,
                    isExpanded: true,
                    items: [
                      for (final answer in CandidateAnswer.values)
                        DropdownMenuItem(
                          value: answer,
                          child: Text(switch (answer) {
                            CandidateAnswer.yes => 'Evet, görüyorum',
                            CandidateAnswer.maybe => 'Belki',
                            CandidateAnswer.no => 'Hayır',
                            CandidateAnswer.unanswered => 'Yanıt vermedim',
                          }),
                        ),
                    ],
                    onChanged: (answer) async {
                      if (answer == null) return;
                      final old = p.feedback.singleWhere(
                        (f) => f.candidateKey == s['key'],
                      );
                      final next = p.update(
                        feedback: [
                          for (final f in p.feedback)
                            if (f.candidateKey == old.candidateKey)
                              CandidateFeedback(
                                candidateKey: old.candidateKey,
                                runId: old.runId,
                                answer: answer,
                                exposedAtUtc: old.exposedAtUtc,
                                editedBox: old.editedBox,
                              )
                            else
                              f,
                        ],
                      );
                      try {
                        await _save(session.withPhoto(next));
                        if (context.mounted) setLocal(() => p = next);
                      } catch (_) {
                        if (context.mounted) {
                          showNotice(context, 'Yanıt kaydedilemedi.');
                        }
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final old = p.feedback.singleWhere(
                        (f) => f.candidateKey == s['key'],
                      );
                      final box =
                          old.editedBox ??
                          (s['box'] == null
                              ? null
                              : RegionBox.fromJson(
                                  Map<String, dynamic>.from(s['box'] as Map),
                                ));
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AnnotationPage(
                            displayCrop: p.displayCrop,
                            photo: p.photo.annotated(
                              [
                                if (box != null)
                                  RegionAnnotation(
                                    id: 'engine-region',
                                    box: box,
                                  ),
                              ],
                              box == null
                                  ? PhotoDecision.unreviewed
                                  : PhotoDecision.marked,
                            ),
                            image: FileImage(
                              _controller.store.file(p.photo.localName),
                            ),
                            onSave: (edited) async {
                              if (edited.regions.length != 1) {
                                throw StateError('One region required');
                              }
                              final next = p.update(
                                feedback: [
                                  for (final f in p.feedback)
                                    if (f.candidateKey == old.candidateKey)
                                      CandidateFeedback(
                                        candidateKey: old.candidateKey,
                                        runId: old.runId,
                                        answer: old.answer,
                                        exposedAtUtc: old.exposedAtUtc,
                                        editedBox: edited.regions.single.box,
                                      )
                                    else
                                      f,
                                ],
                              );
                              await _save(session.withPhoto(next));
                              if (context.mounted) setLocal(() => p = next);
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.scan),
                    label: const Text('Gördüğüm bölgeyi düzelt'),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _technicalDetails() async {
    final prepared = session.preparedInput;
    if (prepared == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Hazırlanan AI girdisi')),
          body: PageBody(
            children: [
              const Text(
                'Bu içerik telefonda hazırlandı. Henüz bir AI servisine gönderilmedi.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(prepared['payload']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPreview(ReviewPhoto p) {
    final crop = p.visibleCrop;
    return AspectRatio(
      aspectRatio: p.displayCrop == null
          ? 4 / 3
          : crop.aspectRatio(p.photo.width, p.photo.height),
      child: Center(
        child: AspectRatio(
          aspectRatio: crop.aspectRatio(p.photo.width, p.photo.height),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: CroppedPhoto(
                    image: FileImage(_controller.store.file(p.photo.localName)),
                    photoWidth: p.photo.width,
                    photoHeight: p.photo.height,
                    crop: crop,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Fotoğraf okunamadı')),
                  ),
                ),
                for (final region in p.photo.regions)
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(
                      crop.toDisplayBox(region.box).x * constraints.maxWidth,
                      crop.toDisplayBox(region.box).y * constraints.maxHeight,
                      crop.toDisplayBox(region.box).width *
                          constraints.maxWidth,
                      crop.toDisplayBox(region.box).height *
                          constraints.maxHeight,
                    ),
                    child: Semantics(
                      label: 'Kullanıcı gözlemi: ${region.title}',
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xffa15c00),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cups = session.photos
        .where((p) => p.surface == ReviewSurface.cup)
        .length;
    final prepared = session.preparedInput;
    final observationCount = session.photos.fold<int>(
      0,
      (count, photo) =>
          count + photo.photo.regions.where((r) => r.label != null).length,
    );
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Fincan incelemesi')),
        body: PageBody(
          children: [
            if (busy) ...[
              const LinearProgressIndicator(),
              Text(
                _controller.activePhotoId == null
                    ? 'Kaydediliyor'
                    : '${session.photos.singleWhere((p) => p.id == _controller.activePhotoId).title} inceleniyor',
              ),
            ],
            if (_controller.setupError != null) Text(_controller.setupError!),
            if (cups < 3)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => _act(() => _camera()),
                    icon: const Icon(LucideIcons.camera),
                    label: const Text('Fincan çek'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _act(() => _gallery(ReviewSurface.cup)),
                    icon: const Icon(LucideIcons.image),
                    label: const Text('Galeriden fincan'),
                  ),
                ],
              ),
            if (!session.photos.any((p) => p.surface == ReviewSurface.saucer))
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => _act(() => _gallery(ReviewSurface.saucer)),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Galeriden tabak ekle · isteğe bağlı'),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: session.sameSampleDeclared,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Bu fotoğraflar aynı fincana ve aynı telveye ait.',
              ),
              onChanged: busy
                  ? null
                  : (v) => _act(() => _save(session.next(sameSample: v))),
            ),
            for (final p in session.orderedPhotos) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fotoğrafı çıkar',
                    onPressed: busy
                        ? null
                        : () => _act(
                            () => _save(
                              session.next(
                                photos: session.photos.where(
                                  (e) => e.id != p.id,
                                ),
                              ),
                            ),
                          ),
                    icon: const Icon(LucideIcons.trash2),
                  ),
                ],
              ),
              _photoPreview(p),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: p.usableConfirmedAtUtc != null,
                title: const Text('Fotoğraf net; telve ve iç yüzey görünür.'),
                onChanged: busy || p.usableConfirmedAtUtc != null
                    ? null
                    : (v) => v == true
                          ? _act(
                              () => _save(
                                session.withPhoto(
                                  p.update(
                                    confirmedAt: DateTime.now()
                                        .toUtc()
                                        .toIso8601String(),
                                  ),
                                ),
                              ),
                            )
                          : null,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _act(() => _annotate(p)),
                    icon: const Icon(LucideIcons.scan),
                    label: const Text('Gördüğüm şekilleri ekle'),
                  ),
                  IconButton(
                    tooltip: 'Galeriden değiştir',
                    onPressed: busy
                        ? null
                        : () => _act(() => _gallery(p.surface, replace: p)),
                    icon: const Icon(LucideIcons.image),
                  ),
                  if (p.surface == ReviewSurface.cup)
                    IconButton(
                      tooltip: 'Yeniden çek',
                      onPressed: busy
                          ? null
                          : () => _act(() => _camera(replace: p)),
                      icon: const Icon(LucideIcons.camera),
                    ),
                ],
              ),
              if (p.photo.regions.isNotEmpty)
                Text(
                  'Kullanıcı gözlemi: ${p.photo.regions.map((r) => r.title).join(', ')}',
                ),
              if (p.analysis != null) ...[
                Text(switch (p.analysis!['outcome']) {
                  'noMatch' => 'Fiziksel eşleşme oluşmadı.',
                  'insufficientSymbolEvidence' =>
                    'Fiziksel eşleşme var; sembol kanıtı yetersiz.',
                  'symbolCandidatesAvailable' =>
                    'Görsel çağrışım adayları var.',
                  _ => 'Bu fotoğrafın analizi tamamlanamadı.',
                }),
                if (!p.failed)
                  Text(
                    '${(p.analysis!['patterns'] as List).length} fiziksel aday · '
                    '${p.analysis!['matchedCount']} Knowledge eşleşmesi · ${(p.analysis!['symbols'] as List).length} Symbol adayı',
                  ),
                if (p.analysis!['symbolAvailability'] == 'notConfigured')
                  const Text('Otomatik Symbol kataloğu yüklü değil.'),
                if (session.currentInitialObservation != null &&
                    (p.analysis!['symbols'] as List).isNotEmpty)
                  OutlinedButton(
                    onPressed: busy ? null : () => _act(() => _candidates(p)),
                    child: const Text('Adayları incele'),
                  ),
                if (p.failed)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => _act(
                            () => _controller.analyze(retryPhotoId: p.id),
                          ),
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('Bu fotoğrafı tekrar işle'),
                  ),
              ],
            ],
            const SizedBox(height: 24),
            const Text(
              'Gördüğün şekilleri ekleyebilir veya işaretlemeden devam edebilirsin.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  busy ||
                      !session.ready ||
                      (prepared != null &&
                          prepared['status'] != 'analysisPending')
                  ? null
                  : () => _act(() => _controller.analyze()),
              icon: const Icon(LucideIcons.scanSearch),
              label: const Text('İncelemeyi tamamla'),
            ),
            const SizedBox(height: 16),
            Text(
              prepared == null
                  ? (session.currentInitialObservation == null
                        ? 'İşaretlerin ilk yorum öncesinde kaydedilecek.'
                        : 'İlk gözlemler korundu · İnceleme tamamlanmayı bekliyor')
                  : switch (prepared['status']) {
                      'ready' => 'İnceleme kaydedildi',
                      'partial' =>
                        'İnceleme kaydedildi · Bazı fotoğraflar işlenemedi',
                      'empty' =>
                        'İnceleme kaydedildi · Kullanılabilir bulgu oluşmadı',
                      _ => 'Gözlemler kaydedildi · Analiz bekliyor',
                    },
            ),
            Text('$observationCount kullanıcı işareti'),
            if (prepared != null)
              TextButton.icon(
                onPressed: busy ? null : _technicalDetails,
                icon: const Icon(LucideIcons.fileJson),
                label: const Text('Teknik ayrıntılar'),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: session.researchConsentAtUtc != null,
              title: const Text(
                'Araştırma için dışa aktarmaya izin veriyorum.',
              ),
              onChanged: busy
                  ? null
                  : (v) => _act(() => _save(session.next(researchAllowed: v))),
            ),
          ],
        ),
      ),
    );
  }
}
