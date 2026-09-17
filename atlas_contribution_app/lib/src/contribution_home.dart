import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'annotation_page.dart';
import 'local_store.dart';
import 'models.dart';
import 'service.dart';
import 'theme.dart';
import 'photo_view.dart';
import 'gallery_import.dart';
import 'capture_settings.dart';
import 'cropped_photo.dart';

typedef CameraLauncher =
    Future<CameraCaptureResult?> Function(
      BuildContext context, {
      required CoffeeCameraConfig config,
      required String captureTitle,
      required String captureInstruction,
    });

Future<CameraCaptureResult?> _openContributionCamera(
  BuildContext context, {
  required CoffeeCameraConfig config,
  required String captureTitle,
  required String captureInstruction,
}) => showCoffeeCamera(
  context,
  config: config,
  captureTitle: captureTitle,
  captureInstruction: captureInstruction,
);

class ContributionHome extends StatefulWidget {
  const ContributionHome({
    required this.store,
    required this.service,
    this.onExport,
    this.onReview,
    this.galleryPicker,
    this.cameraLauncher,
    super.key,
  });
  final DraftStore store;
  final ContributionBackend service;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onReview;
  final GalleryPicker? galleryPicker;
  final CameraLauncher? cameraLauncher;
  @override
  State<ContributionHome> createState() => _ContributionHomeState();
}

class _ContributionHomeState extends State<ContributionHome>
    with WidgetsBindingObserver {
  ContributionDraft? _draft;
  bool _loading = true, _busy = false, _resumePrompt = false;
  String? _error;
  int _uploaded = 0;
  late final _gallery = GalleryImport(
    widget.store,
    widget.galleryPicker ?? AndroidGalleryPicker(),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && !_loading) _sync();
  }

  Future<void> _load() async {
    try {
      _draft = await widget.store.load();
      if (widget.service.isOffline) {
        try {
          _draft = await _gallery.recover();
        } catch (_) {
          // Keep the old draft if a recovered selection cannot be decoded.
          if (mounted) {
            showNotice(
              context,
              'Galeri seçimi tamamlanamadı. Önceki kayıtların korundu.',
            );
          }
        }
      }
      _resumePrompt = _draft != null && !_draft!.queued;
      await widget.store.pruneExpiredReceipts();
    } catch (_) {
      _error =
          'Taslak okunamadı. Dosyaların korundu; destek için davet eden kişiye ulaş.';
    }
    if (mounted) setState(() => _loading = false);
    await _sync();
  }

  Future<void> _sync() async {
    if (_busy) return;
    try {
      for (final id in await widget.store.pendingDeletes()) {
        await widget.service.delete(id);
        await widget.store.acknowledgeDelete(id);
      }
      if (_draft?.queued == true && mounted) await _send();
    } catch (_) {
      /* Durable deletion requests are retried on resume. */
    }
  }

  Future<void> _save(ContributionDraft next) async {
    await widget.store.save(next);
    if (mounted) setState(() => _draft = next);
  }

  Future<bool> _consent() async {
    bool adult = false, permission = false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, change) => AlertDialog(
              title: const Text('Katkı iznin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.service.isOffline
                          ? 'Fotoğrafların ve işaretlerin yalnız bu telefonda saklanacak. Paketi dışa aktardığında inceleme ve gelecekteki şekil tanıma çalışmaları için kullanılabilecek. Dışa aktarılan paketleri sen yönetirsin.'
                          : 'Fincan fotoğrafların ve işaretlerin Atlas ekibi tarafından incelenecek; ileride şekil tanıma sistemini geliştirmekte kullanılabilecek. Katkın herkese açık paylaşılmayacak. En fazla 180 gün saklanacak. Gönderdiklerim ekranından silebilirsin.',
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('18 yaşındayım veya daha büyüğüm.'),
                      value: adult,
                      onChanged: (v) => change(() => adult = v!),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Kendi çektiğim fotoğrafların ve işaretlerimin bu amaçla kullanılmasına izin veriyorum.',
                      ),
                      value: permission,
                      onChanged: (v) => change(() => permission = v!),
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
                  onPressed: adult && permission
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Devam et'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _new({String? groupId}) async {
    if (_busy || _draft != null || !await _consent()) return;
    _resumePrompt = false;
    final id = const Uuid().v4(),
        now = DateTime.now().toUtc().toIso8601String();
    await _save(
      ContributionDraft(
        id: id,
        rootId: id,
        groupId: groupId ?? const Uuid().v4(),
        createdAt: now,
        consentedAt: now,
        kind: widget.service.isOffline
            ? ContributionKind.freeThreeAngle
            : ContributionKind.threeAngle,
      ),
    );
  }

  Future<void> _capture(CaptureRole role) async {
    if (_busy || _draft == null || _draft!.queued) return;
    setState(() => _busy = true);
    try {
      final result = await (widget.cameraLauncher ?? _openContributionCamera)(
        context,
        config: cameraConfigForRole(role),
        captureTitle:
            '${_draft!.captureRoles.indexOf(role) + 1} / 3 · ${cameraCaptureTitle(role)}',
        captureInstruction: cameraCaptureInstruction(role),
      );
      if (result == null) return;
      final imported = await widget.store.importCapture(
        role,
        result,
        preserveDisplayCrop: widget.service.isOffline,
      );
      await _save(_draft!.withPhoto(imported));
      try {
        await widget.store.releaseCapture(result);
        await widget.store.collectOrphans();
      } catch (_) {
        /* Keep the durable photo even if cache cleanup fails. */
      }
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Fotoğraf kaydedilemedi. Önceki çekimlerin duruyor.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _annotate(ContributionPhoto photo) async {
    if (_busy || _draft?.queued == true) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnnotationPage(
          photo: photo,
          image: FileImage(widget.store.file(photo.localName)),
          displayCrop: photo.visibleCrop,
          onSave: (p) => _save(_draft!.withPhoto(p)),
        ),
      ),
    );
  }

  Future<void> _pickGallery({bool replace = false}) async {
    if (_busy || !widget.service.isOffline || _draft?.queued == true) return;
    if (!replace && _draft != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yarım kalan çalışman var'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Çalışmaya dön'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Taslağı sil ve galeriye geç'),
            ),
          ],
        ),
      );
      if (discard != true) {
        if (mounted) setState(() => _resumePrompt = false);
        return;
      }
      await widget.store.clear();
      if (mounted) setState(() => _draft = null);
    }
    if (!replace && !await _consent()) return;
    if (!mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();
    final base = replace
        ? _draft!
        : ContributionDraft(
            id: id,
            rootId: id,
            groupId: const Uuid().v4(),
            createdAt: now,
            consentedAt: now,
            kind: ContributionKind.gallerySingle,
          );
    setState(() => _busy = true);
    ContributionDraft? imported;
    try {
      imported = await _gallery.select(base);
      if (mounted && imported != null) {
        setState(() {
          _draft = imported;
          _resumePrompt = false;
        });
      }
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Fotoğraf okunamadı veya kaydedilemedi. Önceki kayıtların korundu.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && imported != null) await _annotate(imported.photos.single);
  }

  Future<void> _send() async {
    if (_busy || _draft?.reviewed != true) return;
    setState(() {
      _busy = true;
      _uploaded = 0;
    });
    try {
      await _save(_draft!.copy(queued: true));
      final row = await widget.service.submit(
        _draft!,
        (p) => widget.store.file(p.localName).readAsBytes(),
        (count) {
          if (mounted) setState(() => _uploaded = count);
        },
      );
      await widget.store.saveReceipt(row);
      await widget.store.clear();
      if (mounted) {
        setState(() => _draft = null);
        showNotice(
          context,
          widget.service.isOffline
              ? 'Telefona kaydedildi. İnternete gönderilmedi.'
              : 'Gönderildi. Katkın için teşekkür ederiz.',
        );
      }
    } catch (e) {
      if (mounted) {
        showNotice(
          context,
          e is ContributionFailure
              ? e.message
              : 'Gönderilemedi. Çalışman telefonda duruyor. Tekrar deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bu taslak silinsin mi?'),
        content: const Text('Çekimleri ve işaretleri yeniden yapman gerekir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Çekime dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Taslağı sil'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    if (_draft!.queued) {
      try {
        await widget.service.call('cancel', {'id': _draft!.id});
      } catch (_) {
        if (mounted) {
          showNotice(
            context,
            'Gönderimi iptal etmek için internet bağlantısı gerekiyor.',
          );
        }
        return;
      }
    }
    await widget.store.clear();
    if (mounted) setState(() => _draft = null);
  }

  Future<void> _history() async {
    if (_busy) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContributionHistory(
          store: widget.store,
          service: widget.service,
          canStart: _draft == null,
          onRepeat: (group) async {
            Navigator.pop(context);
            await _new(groupId: group);
          },
          onEdit: (row) async {
            final old = ContributionDraft.fromJson(
              Map<String, dynamic>.from(row['document'] as Map),
            );
            for (final photo in old.photos) {
              if (!await widget.store.file(photo.localName).exists()) {
                final bytes = await widget.service.readPhoto(old.id, photo);
                await widget.store
                    .file(photo.localName)
                    .writeAsBytes(bytes, flush: true);
              }
            }
            await _save(
              ContributionDraft(
                id: const Uuid().v4(),
                rootId: old.rootId,
                groupId: old.groupId,
                revision: old.revision + 1,
                supersedesId: old.id,
                createdAt: DateTime.now().toUtc().toIso8601String(),
                consentedAt: old.consentedAt,
                kind: old.kind,
                photos: old.photos,
              ),
            );
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.service.isOffline ? 'Atlas Katkı · Yerel' : 'Atlas Katkı',
        ),
        actions: [
          IconButton(
            tooltip: 'Gönderdiklerim',
            onPressed: _busy ? null : _history,
            icon: const Icon(LucideIcons.history),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              children: [
                if (widget.onReview != null) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : widget.onReview,
                    icon: const Icon(LucideIcons.scanSearch),
                    label: const Text('Fincanı incele'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.onExport != null) ...[
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await widget.onExport!();
                            } catch (_) {
                              if (context.mounted) {
                                showNotice(
                                  context,
                                  'Paket hazırlanamadı. Kayıtların telefonda duruyor.',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: const Icon(LucideIcons.download),
                    label: const Text('Paketi dışa aktar'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.service.isOffline && _error == null) ...[
                  OutlinedButton.icon(
                    onPressed: _busy || _loading ? null : () => _pickGallery(),
                    icon: const Icon(LucideIcons.image),
                    label: const Text('Galeriden fotoğraf seç'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else if (draft == null) ...[
                  const SizedBox(height: 24),
                  const Icon(
                    LucideIcons.coffee,
                    size: 72,
                    color: Color(0xff186354),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bir fincan,\nfarklı şekiller.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fincanını üç açıdan çek, gördüğün şekilleri paylaş.',
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => _new(),
                    icon: const Icon(LucideIcons.camera),
                    label: const Text('Fincan çek'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _history,
                    icon: const Icon(LucideIcons.history),
                    label: Text(
                      widget.service.isOffline
                          ? 'Kayıtlarım'
                          : 'Gönderdiklerim',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bu denemede fal yorumu verilmez. Katkıların şekil araştırmasına yardımcı olur.',
                  ),
                ] else if (_resumePrompt) ...[
                  const SizedBox(height: 24),
                  const Icon(LucideIcons.coffee, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    draft.isGallery
                        ? 'Fotoğrafın seni bekliyor'
                        : 'Fincanın seni bekliyor',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${draft.photos.length} / ${draft.requiredPhotos} fotoğraf kayıtlı',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => setState(() => _resumePrompt = false),
                    icon: const Icon(LucideIcons.play),
                    label: const Text('Kaldığın yerden devam et'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _history,
                    icon: const Icon(LucideIcons.history),
                    label: Text(
                      widget.service.isOffline
                          ? 'Kayıtlarım'
                          : 'Gönderdiklerim',
                    ),
                  ),
                ] else ...[
                  Text(
                    draft.complete
                        ? 'Gördüğün şekilleri seç'
                        : 'Fincanını üç açıdan çek',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${draft.photos.length} / ${draft.requiredPhotos} fotoğraf hazır',
                  ),
                  const SizedBox(height: 20),
                  if (draft.isGallery) ...[
                    for (final p in draft.photos) ...[
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.file(
                          widget.store.file(p.localName),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('Fotoğraf açılamadı.')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_decisionText(p)),
                      OutlinedButton(
                        onPressed: _busy || draft.queued
                            ? null
                            : () => _annotate(p),
                        child: const Text('İşaretleri gözden geçir'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _busy || draft.queued
                          ? null
                          : () => _pickGallery(replace: true),
                      icon: const Icon(LucideIcons.image),
                      label: const Text('Başka fotoğraf seç'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!draft.isGallery)
                    for (final role in draft.captureRoles) ...[
                      if (draft.photo(role) case final p?)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        role.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '${role.title} yeniden çek',
                                      onPressed: _busy || draft.queued
                                          ? null
                                          : () => _capture(role),
                                      icon: const Icon(LucideIcons.rotateCcw),
                                    ),
                                  ],
                                ),
                                AspectRatio(
                                  aspectRatio: p.displayCrop == null
                                      ? 4 / 3
                                      : p.visibleCrop.aspectRatio(
                                          p.width,
                                          p.height,
                                        ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: p.displayCrop == null
                                        ? Image.file(
                                            widget.store.file(p.localName),
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => const Center(
                                              child: Text(
                                                'Fotoğraf açılamadı. Yeniden çek.',
                                              ),
                                            ),
                                          )
                                        : CroppedPhoto(
                                            image: FileImage(
                                              widget.store.file(p.localName),
                                            ),
                                            photoWidth: p.width,
                                            photoHeight: p.height,
                                            crop: p.visibleCrop,
                                            errorBuilder: (_, _, _) => const Center(
                                              child: Text(
                                                'Fotoğraf açılamadı. Yeniden çek.',
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(_decisionText(p)),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _busy || draft.queued
                                      ? null
                                      : () => _annotate(p),
                                  child: Text(
                                    p.decision == PhotoDecision.unreviewed
                                        ? 'Şekil işaretle'
                                        : 'İşaretleri gözden geçir',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (draft.captureRoles.indexOf(role) ==
                          draft.photos.length) ...[
                        Text(
                          role.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        CaptureGuide(role),
                        const SizedBox(height: 8),
                        Text(cameraCaptureTitle(role)),
                        const SizedBox(height: 4),
                        Text(cameraCaptureInstruction(role)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _capture(role),
                          icon: const Icon(LucideIcons.camera),
                          label: Text('${role.title} çek'),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _uploaded > 0
                          ? '$_uploaded / ${draft.requiredPhotos} fotoğraf hazır'
                          : 'İşlem sürüyor…',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (draft.complete)
                    FilledButton.icon(
                      onPressed: !_busy && draft.reviewed ? _send : null,
                      icon: const Icon(LucideIcons.send),
                      label: Text(
                        widget.service.isOffline
                            ? 'Telefona kaydet'
                            : draft.queued
                            ? 'Gönderimi tekrar dene'
                            : 'Gönder',
                      ),
                    ),
                  if (draft.complete && !draft.reviewed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        draft.isGallery
                            ? 'Kaydetmeden önce fotoğrafı gözden geçir.'
                            : 'Göndermeden önce üç fotoğrafı da gözden geçir. Şekil bulman gerekmiyor.',
                      ),
                    ),
                  TextButton(
                    onPressed: _busy ? null : _discard,
                    child: const Text('Taslağı sil'),
                  ),
                ],
              ],
            ),
    );
  }
}

String _decisionText(ContributionPhoto p) => switch (p.decision) {
  PhotoDecision.unreviewed => 'Henüz gözden geçirilmedi',
  PhotoDecision.marked => p.regions.map((r) => r.title).join(' · '),
  PhotoDecision.uncertain => 'Emin değilim',
  PhotoDecision.notSeen => 'Şekil seçemedim',
  PhotoDecision.skipped => 'Şimdilik geçildi',
};

class ContributionHistory extends StatefulWidget {
  const ContributionHistory({
    required this.store,
    required this.service,
    required this.canStart,
    required this.onRepeat,
    required this.onEdit,
    super.key,
  });
  final DraftStore store;
  final ContributionBackend service;
  final bool canStart;
  final Future<void> Function(String) onRepeat;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  @override
  State<ContributionHistory> createState() => _ContributionHistoryState();
}

class _ContributionHistoryState extends State<ContributionHistory> {
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      _rows = await widget.service.list();
      _message = null;
    } catch (_) {
      _rows = await widget.store.receipts();
      _message = 'Bağlantı yok. Telefonda kayıtlı gönderimler gösteriliyor.';
    }
    final deleted = await widget.store.pendingDeletes();
    _rows = _rows.where((r) => !deleted.contains(r['root_id'])).toList();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Katkın silinsin mi?'),
        content: Text(
          widget.service.isOffline
              ? 'Bu katkının tüm kayıtları telefondan silinecek. Daha önce dışarı aktardığın paketleri ayrıca silmelisin.'
              : 'Bu katkının kullanım izni geri çekilecek. İnternet yoksa istek bağlantı geldiğinde gönderilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Katkımı sil'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final root = row['root_id'] as String;
    await widget.store.queueDelete(root);
    try {
      await widget.service.delete(root);
      await widget.store.acknowledgeDelete(root);
      await widget.store.collectOrphans();
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Silme isteği telefona kaydedildi. Bağlantı geldiğinde iletilecek.',
        );
      }
    }
    await _refresh();
  }

  Future<void> _act(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        showNotice(context, 'İşlem tamamlanamadı. Bağlantını kontrol et.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.service.isOffline ? 'Kayıtlarım' : 'Gönderdiklerim'),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(LucideIcons.refreshCw),
        ),
      ],
    ),
    body: PageBody(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        if (!_busy && _rows.isEmpty)
          Text(
            widget.service.isOffline
                ? 'Henüz tamamlanmış kaydın yok.'
                : 'Henüz gönderilmiş katkın yok.',
          ),
        for (var i = 0; i < _rows.length; i++) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${(_rows[i]['document'] as Map)['kind'] == 'gallerySingle' ? 'Galeri fotoğrafı' : 'Fincan'} ${_rows.length - i}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    (_rows[i]['submitted_at'] as String? ?? '')
                        .split('T')
                        .first,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ((_rows[i]['document'] as Map)['photos'] as List)
                        .expand((p) => (p['regions'] as List))
                        .map(
                          (r) =>
                              contributionLabels[r['label']] ?? 'Emin değilim',
                        )
                        .toSet()
                        .join(' · '),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(() async {
                            final photos = ContributionDraft.fromJson(
                              Map<String, dynamic>.from(_rows[i]['document']),
                            ).photos;
                            final images = <String, ImageProvider>{};
                            for (final p in photos) {
                              images[p.fileKey] = MemoryImage(
                                await widget.service.readPhoto(
                                  _rows[i]['id'] as String,
                                  p,
                                ),
                              );
                            }
                            if (!context.mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Fotoğraflarım'),
                                  ),
                                  body: PageBody(
                                    children: [
                                      for (final p
                                          in ContributionDraft.fromJson(
                                            Map<String, dynamic>.from(
                                              _rows[i]['document'],
                                            ),
                                          ).photos)
                                        MarkedPhoto(
                                          photo: p,
                                          image: images[p.fileKey]!,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    child: const Text('Fotoğrafları gör'),
                  ),
                  if (widget.canStart) ...[
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act(() => widget.onEdit(_rows[i])),
                      child: const Text('İşaretleri düzenle'),
                    ),
                    if ((_rows[i]['document'] as Map)['kind'] !=
                        'gallerySingle')
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => widget.onRepeat(
                                _rows[i]['group_id'] as String,
                              ),
                        child: const Text('Aynı fincanı tekrar çek'),
                      ),
                  ],
                  TextButton(
                    onPressed: _busy ? null : () => _remove(_rows[i]),
                    child: const Text('Katkımı sil'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}
