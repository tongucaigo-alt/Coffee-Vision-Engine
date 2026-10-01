import 'dart:io';
import 'dart:async';
import 'ai/ai_contract.dart' show playTestEnabled;
import 'photo_suitability.dart';
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
import 'atlas_design.dart';
import 'annotation_sequence.dart';
import 'research_export_notice.dart';
import 'fortune_progress.dart';

part 'contribution_design.dart';
part 'photo_set_flow.dart';

enum RecordPreparationStatus {
  notRequested,
  ready,
  partial,
  empty,
  pending,
  failed,
}

enum _SavePhase { idle, saving, analyzing, saved, failed }

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
    this.onAiSettings,
    this.onRecorded,
    this.onReadFortune,
    this.onGenerateFortune,
    this.aiDescription,
    this.fortuneProgress,
    this.galleryPicker,
    this.photoSuitability,
    this.cameraLauncher,
    this.saucerLauncher,
    this.modern = false,
    this.onConfirmedRecorded,
    this.recordState,
    this.recordStarred,
    super.key,
  });
  final DraftStore store;
  final ContributionBackend service;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onReview;
  final Future<void> Function()? onAiSettings;
  final Future<void> Function(Map<String, dynamic>)? onRecorded;
  final Future<void> Function(Map<String, dynamic>)? onReadFortune;
  final Future<void> Function(Map<String, dynamic>)? onGenerateFortune;
  final Future<String?> Function()? aiDescription;
  final ValueNotifier<FortuneProgress>? fortuneProgress;
  final GalleryPicker? galleryPicker;
  final PhotoSuitability? photoSuitability;
  final CameraLauncher? cameraLauncher;
  final Future<CameraCaptureResult?> Function(BuildContext)? saucerLauncher;
  final bool modern;
  final Future<RecordPreparationStatus> Function(
    Map<String, dynamic>,
    Set<String>,
  )?
  onConfirmedRecorded;
  final Future<String> Function(Map<String, dynamic>)? recordState;
  final Future<bool> Function(Map<String, dynamic>)? recordStarred;
  @override
  State<ContributionHome> createState() => _ContributionHomeState();
}

class _ContributionHomeState extends State<ContributionHome>
    with WidgetsBindingObserver {
  ContributionDraft? _draft;
  bool _loading = true, _busy = false, _resumePrompt = false;
  bool _fortuneWorkflow = false, _startChoiceOpen = false;
  String? _error;
  int _uploaded = 0;
  bool _stopRequested = false;
  _SavePhase _savePhase = _SavePhase.idle;
  String get _saveLabel => switch (_savePhase) {
    _SavePhase.saving => 'Kaydediliyor…',
    _SavePhase.analyzing => 'Telve inceleniyor…',
    _SavePhase.saved => 'Kayıt tamamlandı',
    _SavePhase.failed => 'Kaydı Yeniden Dene',
    _SavePhase.idle => 'Gözlemleri Kaydet',
  };

  Widget _saveActions(bool enabled) => FutureBuilder<String?>(
    future: widget.aiDescription?.call(),
    builder: (context, snapshot) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onGenerateFortune != null)
          FilledButton(
            onPressed: enabled && snapshot.data != null
                ? () => _send(generate: true)
                : null,
            child: const Text('Kaydet ve Falını Oluştur'),
          ),
        TextButton(
          onPressed: enabled ? () => _send() : null,
          child: Text(
            widget.onGenerateFortune == null ? _saveLabel : 'Yalnız Kaydet',
          ),
        ),
        if (widget.onGenerateFortune != null &&
            snapshot.connectionState == ConnectionState.done &&
            snapshot.data == null)
          TextButton.icon(
            onPressed: widget.onAiSettings == null
                ? null
                : () async {
                    await widget.onAiSettings!();
                    _change(() {});
                  },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Fal bağlantısını ayarla'),
          ),
      ],
    ),
  );

  int _tab = 0;
  bool _flowOpen = false, _sequenceRunning = false, _sameSample = false;
  final Set<String> _usable = {};
  final _photoChecks = <String, Map<String, dynamic>>{};
  final _checkingPhotos = <String>{};
  Future<void> _checkPhoto(ContributionPhoto p, {bool retry = false}) async {
    final key = suitabilityIdentity(p);
    if (!_checkingPhotos.add(key)) return;
    _change(() {});
    try {
      final value = await _suitability.assess(
        widget.store.file(p.localName),
        p,
        retry: retry,
      );
      if (!mounted ||
          _draft?.photos.any((v) => suitabilityIdentity(v) == key) != true) {
        return;
      }
      _change(() {
        _photoChecks[key] = value;
        if (suitabilityAccepted(value, p)) {
          _usable.add(_photoIdentity(p));
        } else {
          _usable.remove(_photoIdentity(p));
        }
      });
    } finally {
      _checkingPhotos.remove(key);
      _change(() {});
    }
  }

  Widget _photoCheckNotice(ContributionPhoto p) => PhotoSuitabilityNotice(
    photo: p,
    value: _photoChecks[suitabilityIdentity(p)],
    onRetry: _atlasBusy || _checkingPhotos.contains(suitabilityIdentity(p))
        ? null
        : () => _checkPhoto(p, retry: true),
  );
  late final _suitability =
      widget.photoSuitability ??
      PhotoSuitability(
        Directory('${widget.store.directory.parent.path}/photo-suitability'),
      );
  void _change(VoidCallback action) {
    if (mounted) setState(action);
  }

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
    if (mounted) {
      setState(() => _loading = false);
      if (widget.modern && widget.service.isOffline && _draft != null) {
        for (final p in _draft!.photos) {
          unawaited(_checkPhoto(p));
        }
      }
    }
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
    if (mounted) {
      setState(() {
        if (_draft?.id != next.id) _savePhase = _SavePhase.idle;
        _draft = next;
      });
      if (widget.modern && widget.service.isOffline) {
        for (final p in next.photos) {
          unawaited(_checkPhoto(p));
        }
      }
    }
  }

  Future<bool> _consent() async {
    if (widget.service.isOffline && await widget.store.hasLocalAcceptance()) {
      return true;
    }
    if (!mounted) return false;
    bool adult = false, permission = false;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, change) => AlertDialog(
              title: Text(
                widget.service.isOffline ? 'Başlamadan önce' : 'Katkı iznin',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.service.isOffline && widget.onReadFortune != null
                          ? 'Fotoğrafların ve ilk gözlemlerin bu telefonda saklanır. Fal oluşturmayı seçersen yalnız metinsel özet seçtiğin AI sunucusuna iletilir. Araştırma paketini dışa aktarmayı sen yönetirsin.'
                          : widget.service.isOffline
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
                      title: Text(
                        widget.service.isOffline
                            ? 'Yerel kayıt ve fal hizmeti açıklamasını okudum. Araştırmaya katkı vermek isteğe bağlıdır.'
                            : 'Kendi çektiğim fotoğrafların ve işaretlerimin bu amaçla kullanılmasına izin veriyorum.',
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
    if (accepted && widget.service.isOffline) {
      await widget.store.acceptLocalUse();
    }
    return accepted;
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
            ? (widget.modern
                  ? ContributionKind.photoSet
                  : ContributionKind.freeThreeAngle)
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
      final photo = _draft!.isSet
          ? imported.asSetPhoto(photoId: _draft!.photo(role)?.id, angle: role)
          : imported;
      await _save(_draft!.withPhoto(photo));
      if (widget.modern) {
        _usable.removeWhere(
          (key) =>
              !_draft!.photos.any((p) => '${p.localName}|${p.checksum}' == key),
        );
        _sameSample = false;
      }
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
          modern: widget.modern,
          photo: photo,
          image: FileImage(widget.store.file(photo.localName)),
          displayCrop: photo.visibleCrop,
          onSave: (p) => _save(_draft!.withPhoto(p)),
        ),
      ),
    );
  }

  Future<void> _pickGallery({bool replace = false}) async {
    if (widget.modern && !replace) {
      await _startSetGallery();
      return;
    }
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

  Future<void> _send({bool generate = false}) async {
    if (_busy || _draft?.reviewed != true) return;
    setState(() {
      _busy = true;
      _uploaded = 0;
      _savePhase = _SavePhase.saving;
      _fortuneWorkflow = true;
    });
    widget.fortuneProgress?.value = const FortuneProgress(FortunePhase.saving);
    _stopRequested = false;
    var receiptSaved = false;
    try {
      await _save(_draft!.copy(queued: true));
      final row = await widget.service.submit(
        _draft!,
        (p) => widget.store.file(p.localName).readAsBytes(),
        (count) {
          if (mounted) setState(() => _uploaded = count);
        },
      );
      final confirmed = (_sameSample || _draft!.photos.length == 1)
          // Same-sample declaration is independent of the system's photo check.
          // onConfirmedRecorded reads each actual assessment; no usability tick
          // is synthesized, including when a check failed.
          ? _draft!.photos.map(_photoIdentity).toSet()
          : <String>{};
      await widget.store.saveReceipt(row);
      receiptSaved = true;
      await widget.store.clear();
      var preparation = RecordPreparationStatus.notRequested;
      // The receipt is durable before analysis starts. A later failure must
      // never be presented as a failed save or trigger another submission.
      try {
        if (widget.onRecorded != null) {
          _change(() => _savePhase = _SavePhase.analyzing);
          await widget.onRecorded!(row);
          if (((row['document'] as Map)['photos'] as List).isNotEmpty) {
            preparation = RecordPreparationStatus.pending;
          }
        }
        if (confirmed.length ==
                ((row['document'] as Map)['photos'] as List).length &&
            widget.onConfirmedRecorded != null) {
          preparation = await widget.onConfirmedRecorded!(row, confirmed);
        }
      } catch (_) {
        preparation = RecordPreparationStatus.failed;
      }
      final savedExplanation = switch (preparation) {
        RecordPreparationStatus.ready =>
          'Gözlemlerin kaydedildi ve telve incelemesi tamamlandı. Falını oluşturabilirsin.',
        RecordPreparationStatus.partial =>
          'Kayıt saklandı; bazı fotoğrafların analizi tamamlanamadı. Kullanılabilir verilerle devam edebilir veya incelemeden yeniden deneyebilirsin.',
        RecordPreparationStatus.empty =>
          'Kayıt saklandı. Fal için kullanılabilir gözlem veya fiziksel bulgu oluşmadı.',
        RecordPreparationStatus.failed =>
          'Kayıt saklandı; analiz tamamlanamadı. Kayıtlarım ekranındaki aynı kayıttan yeniden deneyebilirsin.',
        RecordPreparationStatus.pending =>
          'Gözlemlerin kaydedildi. Fotoğraf teyitlerini tamamlayıp yerel incelemeye devam edebilirsin.',
        RecordPreparationStatus.notRequested =>
          'Gözlemlerin telefonda saklandı.',
      };
      if (mounted) {
        setState(() {
          _draft = null;
          _savePhase = _SavePhase.saved;
          _flowOpen = false;
          _usable.clear();
          _sameSample = false;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        showNotice(
          context,
          widget.service.isOffline
              ? savedExplanation
              : 'Gönderildi. Katkın için teşekkür ederiz.',
        );
        if (generate && !_stopRequested && widget.onGenerateFortune != null) {
          await widget.onGenerateFortune!(row);
        } else if (!generate &&
            !widget.modern &&
            widget.onReadFortune != null &&
            ((row['document'] as Map)['photos'] as List).isNotEmpty) {
          final open = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Kayıt tamamlandı'),
              content: Text(savedExplanation),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Daha sonra'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    preparation == RecordPreparationStatus.failed ||
                            preparation == RecordPreparationStatus.pending ||
                            preparation == RecordPreparationStatus.empty
                        ? 'İncelemeyi Aç'
                        : 'Fal oluştur',
                  ),
                ),
              ],
            ),
          );
          if (open == true) {
            try {
              await widget.onReadFortune!(row);
            } catch (_) {
              if (mounted) {
                showNotice(
                  context,
                  'Kayıt korundu. Kayıtlarım ekranından yeniden deneyebilirsin.',
                );
              }
            }
          }
        }
      }
    } catch (e) {
      _change(
        () => _savePhase = receiptSaved ? _SavePhase.saved : _SavePhase.failed,
      );
      if (mounted) {
        showNotice(
          context,
          receiptSaved
              ? 'Kayıt saklandı; ekran güncellenemedi. Kayıtlarım üzerinden açabilirsin.'
              : e is ContributionFailure
              ? e.message
              : 'Kayıt tamamlanamadı. Çalışman telefonda duruyor. Tekrar deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _fortuneWorkflow = false;
        });
      }
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
          onReadFortune: widget.onReadFortune,
          recordStarred: widget.recordStarred,
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
    if (widget.modern &&
        _fortuneWorkflow &&
        _busy &&
        _draft != null &&
        widget.fortuneProgress != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fincanının Hikâyesi')),
        body: ValueListenableBuilder<FortuneProgress>(
          valueListenable: widget.fortuneProgress!,
          builder: (_, progress, _) => FortuneScan(
            progress: _stopRequested
                ? const FortuneProgress(FortunePhase.cancelled)
                : progress,
            photos: _draft!.photos,
            onCancel: () => setState(() {
              _stopRequested = true;
              widget.fortuneProgress!.value = const FortuneProgress(
                FortunePhase.cancelled,
              );
            }),
            imageFor: (p) => FileImage(widget.store.file(p.localName)),
          ),
        ),
      );
    }
    if (widget.modern) return _buildAtlas();
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
                if (widget.onAiSettings != null)
                  OutlinedButton(
                    onPressed: _busy ? null : widget.onAiSettings,
                    child: const Text('AI Laboratuvarı'),
                  ),
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
                            } catch (error) {
                              if (context.mounted) {
                                await showResearchExportFailure(
                                  context,
                                  error,
                                  openPermissions: widget.onReview,
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
                  Text(
                    widget.onReadFortune != null
                        ? 'Gözlemlerini kaydettikten sonra seçtiğin AI ile fal deneyebilirsin. Fotoğrafların telefonda kalır.'
                        : 'Bu denemede fal yorumu verilmez. Katkıların şekil araştırmasına yardımcı olur.',
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
    this.onReadFortune,
    this.modern = false,
    this.embedded = false,
    this.onlyRoot,
    this.currentDraft,
    this.onContinue,
    this.recordState,
    this.recordStarred,
    super.key,
  });
  final DraftStore store;
  final ContributionBackend service;
  final bool canStart;
  final Future<void> Function(String) onRepeat;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>)? onReadFortune;
  final bool modern, embedded;
  final String? onlyRoot;
  final ContributionDraft? currentDraft;
  final Future<void> Function()? onContinue;
  final Future<String> Function(Map<String, dynamic>)? recordState;
  final Future<bool> Function(Map<String, dynamic>)? recordStarred;
  @override
  State<ContributionHistory> createState() => _ContributionHistoryState();
}

class _ContributionHistoryState extends State<ContributionHistory> {
  int _filter = 0;
  final Map<String, String> _recordStates = {};
  void _changeFilter(int filter) => setState(() => _filter = filter);
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  final Set<String> _starredRoots = {};
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
    if (widget.onlyRoot != null) {
      _rows = _rows.where((r) => r['root_id'] == widget.onlyRoot).toList();
    }
    _starredRoots.clear();
    if (widget.recordStarred != null) {
      for (final row in _rows) {
        if (await widget.recordStarred!(row)) {
          _starredRoots.add(row['root_id'] as String);
        }
      }
    }
    if (widget.recordState != null) {
      for (final row in _rows) {
        try {
          _recordStates[row['root_id'] as String] = await widget.recordState!(
            row,
          );
        } catch (_) {
          _recordStates[row['root_id'] as String] = 'Fal durumu okunamadı';
        }
      }
    }
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
  Widget build(BuildContext context) => widget.modern && widget.onlyRoot == null
      ? (widget.embedded
            ? _atlasHistory()
            : Scaffold(
                appBar: AppBar(title: const Text('Kayıtlarım')),
                body: _atlasHistory(),
              ))
      : Scaffold(
          appBar: AppBar(
            title: Text(
              widget.service.isOffline ? 'Kayıtlarım' : 'Gönderdiklerim',
            ),
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
                if (widget.modern) ...[
                  for (final p in ContributionDraft.fromJson(
                    Map<String, dynamic>.from(_rows[i]['document'] as Map),
                  ).photos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MarkedPhoto(
                        photo: p,
                        image: FileImage(widget.store.file(p.localName)),
                        displayCrop: p.visibleCrop,
                      ),
                    ),
                  Text(
                    _recordStates[_rows[i]['root_id']] ?? 'Telefona kaydedildi',
                  ),
                  const SizedBox(height: 12),
                ],
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
                                    contributionLabels[r['label']] ??
                                    'Emin değilim',
                              )
                              .toSet()
                              .join(' · '),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _act(() async {
                                  final photos = ContributionDraft.fromJson(
                                    Map<String, dynamic>.from(
                                      _rows[i]['document'],
                                    ),
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
                        if (widget.onReadFortune != null &&
                            ((_rows[i]['document'] as Map)['photos'] as List)
                                .isNotEmpty)
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _act(
                                    () => widget.onReadFortune!(_rows[i]),
                                  ),
                            child: Text(
                              _recordStates[_rows[i]['root_id']] == 'Fal hazır'
                                  ? 'Falını Oku'
                                  : 'Fal Oluştur',
                            ),
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
