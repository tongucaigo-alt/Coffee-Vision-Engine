import 'dart:io';
import '../photo_suitability.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../cropped_photo.dart';
import '../atlas_design.dart';
import '../photo_view.dart';
import '../mvp/review_controller.dart';
import '../mvp/review_models.dart';
import 'ai_client.dart';
import 'ai_contract.dart';
import 'ai_runtime.dart';
import 'ai_bundled.dart';
import 'play_access_page.dart';
import 'narrative.dart';
import '../fortune_progress.dart';

String _error(Object e) => e is AiFailure
    ? e.message
    : e is FormatException
    ? e.message
    : 'İşlem tamamlanamadı. Kayıtların korunuyor.';

class AiLabPage extends StatefulWidget {
  const AiLabPage({required this.runtime, super.key});
  final AiRuntime runtime;
  @override
  State<AiLabPage> createState() => _AiLabPageState();
}

class _AiLabPageState extends State<AiLabPage> {
  List<AiProfile> _profiles = [];
  String? _message;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final p = await widget.runtime.store.profiles();
      if (mounted) setState(() => _profiles = p);
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    }
  }

  Future<void> _edit([AiProfile? old]) async {
    if (old != null && isBundledProfile(old)) return;
    final name = TextEditingController(text: old?.name ?? 'Atlas');
    final url = TextEditingController(text: old?.url ?? '');
    final model = TextEditingController(text: old?.model ?? 'atlas');
    final key = TextEditingController(
      text: old == null ? '' : await widget.runtime.key(old),
    );
    var provider = old?.provider ?? AiProvider.atlas,
        noThink = old?.noThink ?? true;
    var busy = false;
    AiCancellation? probe;
    String? message;
    var lastUrl = old?.url ?? '';
    final id = old?.id ?? const Uuid().v4();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          AiProfile profile() => AiProfile(
            id: id,
            name: name.text.trim(),
            url: url.text.trim().replaceFirst(RegExp(r'/$'), ''),
            model: model.text.trim(),
            provider: provider,
            noThink: noThink,
          );
          return AlertDialog(
            title: const Text('AI bağlantısı'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<AiProvider>(
                    value: provider,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: AiProvider.atlas,
                        child: Text('Atlas servisi'),
                      ),
                      DropdownMenuItem(
                        value: AiProvider.direct,
                        child: Text('Kendi AI sunucum'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setLocal(() {
                            provider = v!;
                            key.clear();
                            model.text = v == AiProvider.atlas
                                ? 'atlas'
                                : 'qwen3-14b';
                          }),
                  ),
                  TextField(
                    controller: name,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Bağlantı adı',
                    ),
                  ),
                  TextField(
                    controller: url,
                    enabled: !busy,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: provider == AiProvider.atlas
                          ? 'HTTPS test adresi'
                          : 'API adresi (…/v1)',
                    ),
                    onChanged: (value) {
                      if (value != lastUrl) {
                        key.clear();
                        lastUrl = value;
                      }
                    },
                  ),
                  TextField(
                    controller: model,
                    enabled: !busy,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                  TextField(
                    controller: key,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Erişim anahtarı (gerekiyorsa)',
                    ),
                  ),
                  if (provider == AiProvider.direct)
                    CheckboxListTile(
                      value: noThink,
                      onChanged: busy
                          ? null
                          : (v) => setLocal(() => noThink = v!),
                      title: const Text('Qwen düşünmesiz talimatı (/no_think)'),
                    ),
                  const Text(
                    'Adres değişirse anahtarı yeniden gir. Yerel bağlantıda bilgisayarının IP adresini kullan; localhost telefonun kendisidir.',
                  ),
                  if (message != null) Text(message!),
                  if (busy) const LinearProgressIndicator(),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setLocal(() => busy = true);
                            try {
                              final list = await widget.runtime.client.models(
                                profile(),
                                key.text.trim(),
                              );
                              if (ctx.mounted) {
                                setLocal(
                                  () =>
                                      message = 'Modeller: ${list.join(', ')}',
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setLocal(() => message = _error(e));
                              }
                            } finally {
                              if (ctx.mounted) setLocal(() => busy = false);
                            }
                          },
                    child: const Text(
                      'Bağlantıyı kontrol et / modelleri getir',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setLocal(() {
                              busy = true;
                              probe = AiCancellation();
                              message = 'Yapay örnek veriyle üretim deneniyor…';
                            });
                            try {
                              final result = await widget.runtime.client.probe(
                                profile(),
                                key.text.trim(),
                                probe!,
                                (s) {
                                  if (ctx.mounted) setLocal(() => message = s);
                                },
                              );
                              if (ctx.mounted) {
                                setLocal(
                                  () => message =
                                      'Metin üretimi başarılı · ${result['durationMs']} ms. Gerçek fotoğraf veya gözlem kullanılmadı.',
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setLocal(() => message = _error(e));
                              }
                            } finally {
                              if (ctx.mounted) {
                                setLocal(() {
                                  busy = false;
                                  probe = null;
                                });
                              }
                            }
                          },
                    child: const Text('Yapay örnekle üretimi dene'),
                  ),
                  if (probe != null)
                    TextButton(
                      onPressed: () => probe?.cancel(),
                      child: const Text('Testi iptal et'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() => busy = true);
                        try {
                          final p = profile();
                          if (p.name.isEmpty || p.model.isEmpty) {
                            throw const AiFailure('Ad ve model gir.');
                          }
                          await widget.runtime.saveProfile(p, key.text.trim());
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            setLocal(() {
                              message = _error(e);
                              busy = false;
                            });
                          }
                        }
                      },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
    // Dialog animations may still be using controllers for this frame.
    await probe?.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    url.dispose();
    model.dispose();
    key.dispose();
    await _reload();
  }

  @override
  Widget build(BuildContext context) => playTestEnabled
      ? PlayAccessPage(runtime: widget.runtime)
      : Scaffold(
          appBar: AppBar(title: const Text('AI Laboratuvarı · Test')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Yalnız test ekibi için. Fotoğraflar gönderilmez; seçilen sunucuya metinsel gözlemler ve fiziksel özet iletilir.',
              ),
              if (_message != null) Text(_message!),
              for (final p in _profiles)
                ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    isBundledProfile(p)
                        ? '${p.model} · Hazır test bağlantısı\nİnternet bağlantısıyla kullanılır.'
                        : '${p.model}\n${p.url}',
                  ),
                  isThreeLine: true,
                  trailing: isBundledProfile(p)
                      ? const Icon(Icons.lock_outline)
                      : null,
                  onTap: isBundledProfile(p) ? null : () => _edit(p),
                ),
              FilledButton(
                onPressed: () => _edit(),
                child: const Text('Bağlantı ekle'),
              ),
            ],
          ),
        );
}

class AiFortunePage extends StatefulWidget {
  const AiFortunePage({
    required this.runtime,
    required this.session,
    this.autoGenerate = false,
    this.simple = false,
    super.key,
  });
  final AiRuntime runtime;
  final ReviewSession session;
  final bool autoGenerate;
  final bool simple;
  @override
  State<AiFortunePage> createState() => _AiFortunePageState();
}

class _AiFortunePageState extends State<AiFortunePage> {
  late final ReviewController _controller;
  List<AiProfile> _profiles = [];
  List<Map<String, dynamic>> _results = [];
  String? _first, _second, _message;
  Set<String> _stars = {};
  bool _busy = false, _compare = false, _showScan = false;
  AiCancellation? _cancel;
  PhotoSuitabilityFailure? _photoFailure;
  bool _checkingPhotos = false;
  ReviewSession get session => _controller.session;
  @override
  void initState() {
    super.initState();
    _controller = ReviewController(
      store: widget.runtime.reviews,
      session: widget.session,
    );
    _controller.addListener(_analysisProgress);
    _load().then((_) {
      if (mounted &&
          widget.autoGenerate &&
          _profiles.isNotEmpty &&
          !_results.any(
            (r) =>
                r['state'] == 'completed' &&
                r['sourceFingerprint'] == preparationSourceFingerprint(session),
          )) {
        _act(_generate);
      }
    });
  }

  void _analysisProgress() {
    final id = _controller.activePhotoId;
    if (id != null) {
      final p = session.photos.firstWhere((p) => p.id == id);
      widget.runtime.progress.value = FortuneProgress(
        FortunePhase.analyzing,
        photoId: p.photo.localName,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_cancel?.cancel());
    _controller.removeListener(_analysisProgress);
    unawaited(_controller.close());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profiles = await widget.runtime.store.profiles();
      final stars = await widget.runtime.store.starredIds();
      final results = await widget.runtime.store.results(session.id);
      for (final result in results) {
        if ((result['answers'] as List).isNotEmpty) {
          await widget.runtime.store.expose(result);
        }
      }
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _stars = stars;
          _first ??= profiles.firstOrNull?.id;
          _results = results.reversed.toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on PhotoSuitabilityFailure catch (e) {
      if (mounted) {
        setState(() {
          _photoFailure = e;
          _message = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _showScan = false;
        });
      }
    }
  }

  Future<bool> _checkPhotos({bool retry = false}) async {
    if (mounted) setState(() => _checkingPhotos = true);
    try {
      final checker = PhotoSuitability(
        Directory(
          '${widget.runtime.bridge.source.directory.parent.path}/photo-suitability',
        ),
      );
      var next = session;
      for (final p in session.photos) {
        if (!mounted) return false;
        final assessment = await ensurePhotoSuitability(
          context,
          checker,
          widget.runtime.reviews.file(p.photo.localName),
          p.photo,
          retry: retry && _photoFailure?.photo.checksum == p.photo.checksum,
        );
        if (assessment == null) return false;
        if (jsonEncode(assessment) != jsonEncode(p.suitability)) {
          next = next.withPhoto(p.update(suitability: assessment));
        }
      }
      if (session.photos.length == 1 && !next.sameSampleDeclared) {
        next = next.next(sameSample: true);
      }
      if (!next.sameSampleDeclared && mounted) {
        final same = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Aynı fincan mı?'),
            content: const Text(
              'Fotoğraflar aynı fincana ve varsa ona ait tabağa mı ait?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Geri dön'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Evet, devam et'),
              ),
            ],
          ),
        );
        if (same != true) return false;
        next = next.next(sameSample: true);
      }
      if (!identical(next, session)) {
        // Coalesce preparation into one revision regardless of photo count.
        await _controller.save(
          session.next(
            photos: next.photos,
            sameSample: next.sameSampleDeclared,
          ),
        );
      }
      return true;
    } finally {
      if (mounted) setState(() => _checkingPhotos = false);
    }
  }

  Future<void> _generate() async {
    if (!await _checkPhotos(retry: _photoFailure?.technical == true)) return;
    _photoFailure = null;
    if (!mounted) return;
    setState(() => _showScan = true);
    if (!await widget.runtime.bridge.isCurrent(session)) {
      throw const AiFailure(
        'Kaynak kayıt değişti. Ekranı kapatıp güncel kaydı aç.',
      );
    }
    widget.runtime.progress.value = const FortuneProgress(
      FortunePhase.generating,
    );
    await _controller.analyze(enrich: true);
    if (!mounted) return;
    final preparation = session.preparedInput;
    if (preparation == null ||
        !session.ready ||
        session.currentInitialObservation == null) {
      throw const AiFailure('Önce incelemeyi tamamla.');
    }
    final recent = await widget.runtime.store.recentSuccessfulResults();
    final retry = _results
        .where(
          (r) =>
              ['failed', 'cancelled', 'interrupted'].contains(r['state']) &&
              r['sourceFingerprint'] == preparationSourceFingerprint(session) &&
              (r['context'] as Map?)?['version'] ==
                  'atlas-fortune-context-v2' &&
              (r['context'] as Map?)?['narrative'] != null,
        )
        .firstOrNull;
    final contextData = validateAiContext(
      freezeNarrativeContext(
        Map<String, dynamic>.from(preparation['payload'] as Map),
        retry == null
            ? planNarrative(recent)
            : Map<String, dynamic>.from(
                (retry['context'] as Map)['narrative'] as Map,
              ),
      ),
    );
    final selected = [
      _profiles.firstWhere((p) => p.id == _first),
      if (_compare) _profiles.firstWhere((p) => p.id == _second),
    ];
    if (selected.length == 2 &&
        selected[0].url == selected[1].url &&
        selected[0].model == selected[1].model) {
      throw const AiFailure('Karşılaştırma için farklı iki model seç.');
    }
    final snapshot = session;
    final result = <String, dynamic>{
      'version': 1,
      'id': const Uuid().v4(),
      'sessionId': session.id,
      'groupId': session.groupId,
      'sourceFingerprint': preparationSourceFingerprint(session),
      'context': contextData,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'comparison': _compare,
      'answers': <Map<String, dynamic>>[],
      'state': 'running',
      'vote': null,
    };
    _cancel = AiCancellation();
    await widget.runtime.store.saveResult(result);
    try {
      for (final p in selected) {
        _cancel!.check();
        final answer = await widget.runtime.client.generate(
          p,
          await widget.runtime.key(p),
          contextData,
          cancellation: _cancel!,
          onProgress: (p) => widget.runtime.progress.value = p,
          previousTexts: [
            for (final r in recent)
              for (final a in r['answers'] as List) a['text'] as String,
          ],
          onStatus: (s) {
            if (mounted) setState(() => _message = s);
          },
        );
        if (!mounted || !await widget.runtime.bridge.isCurrent(snapshot)) {
          throw const AiFailure(
            'Kayıt değişti; bu yanıt güncel fal olarak gösterilmedi.',
          );
        }
        (result['answers'] as List).add({
          ...answer,
          'profileId': p.id,
          'profileUrl': p.url,
          'profileName': p.name,
        });
        await widget.runtime.store.saveResult(result);
      }
      final answers = result['answers'] as List;
      if (answers.length == 2 &&
          (answers[0]['promptHash'] != answers[1]['promptHash'] ||
              answers[0]['noThink'] != answers[1]['noThink'])) {
        throw const AiFailure(
          'Karşılaştırma talimatları eşleşmiyor. İki bağlantının düşünme ayarlarını eşitle.',
        );
      }
      answers.shuffle(Random.secure());
      result['state'] = 'completed';
      widget.runtime.progress.value = const FortuneProgress(
        FortunePhase.completed,
      );
    } catch (_) {
      result['state'] = _cancel!.cancelled ? 'cancelled' : 'failed';
      widget.runtime.progress.value = FortuneProgress(
        _cancel!.cancelled ? FortunePhase.cancelled : FortunePhase.failed,
      );
      rethrow;
    } finally {
      if (!await widget.runtime.store.isDeleted(session.id)) {
        await widget.runtime.store.saveResult(result);
      }
      _cancel = null;
      if (mounted) await _load();
    }
    if (mounted) setState(() => _message = 'Fal telefona kaydedildi.');
  }

  Future<void> _vote(Map<String, dynamic> result, String vote) async {
    final next = {...result, 'vote': vote};
    await widget.runtime.store.saveResult(next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final modern =
        Theme.of(context).textTheme.bodyMedium?.fontFamily ==
        'Plus Jakarta Sans';
    final hasAnswers = _results.any((r) => (r['answers'] as List).isNotEmpty);
    final currentComplete = _results.any(
      (r) =>
          r['state'] == 'completed' &&
          r['sourceFingerprint'] == preparationSourceFingerprint(session),
    );
    final prepared = session.preparedInput;
    final eligible =
        session.photos.any((p) => p.surface == ReviewSurface.cup) &&
        ['ready', 'partial'].contains(prepared?['status']);
    return Scaffold(
      appBar: AppBar(
        title: Text(modern ? 'Fincanının Hikâyesi' : 'Fal denemesi'),
        actions: [
          if (!widget.simple)
            IconButton(
              tooltip: 'AI Laboratuvarı',
              icon: const Icon(Icons.settings),
              onPressed: _busy
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AiLabPage(runtime: widget.runtime),
                        ),
                      );
                      await _load();
                    },
            ),
        ],
      ),
      body: _busy && _showScan
          ? ValueListenableBuilder<FortuneProgress>(
              valueListenable: widget.runtime.progress,
              builder: (_, progress, _) => FortuneScan(
                progress: progress,
                photos: session.orderedPhotos.map((p) => p.photo).toList(),
                imageFor: (p) =>
                    FileImage(widget.runtime.reviews.file(p.localName)),
                onCancel: _cancel == null
                    ? null
                    : () {
                        widget.runtime.progress.value = const FortuneProgress(
                          FortunePhase.cancelled,
                        );
                        unawaited(_cancel!.cancel());
                      },
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_checkingPhotos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: const Text('Fotoğraflar kontrol ediliyor…'),
                    ),
                  ),
                if (_photoFailure != null) ...[
                  PhotoSuitabilityNotice(
                    photo: _photoFailure!.photo,
                    value: _photoFailure!.assessment,
                    onRetry: _busy
                        ? null
                        : () => _act(() async {
                            await _checkPhotos(retry: true);
                            if (mounted) setState(() => _photoFailure = null);
                          }),
                  ),
                  if (!_photoFailure!.technical)
                    const Text(
                      'Fotoğrafı değiştirmek veya kaldırmak için Kayıtlarım ekranındaki kaydı düzenle.',
                    ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(liveRegion: true, child: Text(_message!)),
                  ),
                if (modern) ...[
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: session.orderedPhotos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final p = session.orderedPhotos[i];
                        return SizedBox(
                          width: 96,
                          child: InkWell(
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (ctx) => Dialog(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(p.title),
                                        MarkedPhoto(
                                          photo: p.photo,
                                          image: FileImage(
                                            widget.runtime.reviews.file(
                                              p.photo.localName,
                                            ),
                                          ),
                                          displayCrop: p.visibleCrop,
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Kapat'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                AtlasPhoto(
                                  photo: p.photo,
                                  image: FileImage(
                                    widget.runtime.reviews.file(
                                      p.photo.localName,
                                    ),
                                  ),
                                  height: 70,
                                ),
                                Expanded(
                                  child: Text(
                                    p.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (hasAnswers) ..._fortuneWidgets(),
                ],
                if (widget.simple) ...[
                  if (!currentComplete)
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (_profiles.isEmpty) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AiLabPage(runtime: widget.runtime),
                                  ),
                                );
                                await _load();
                              } else {
                                await _act(_generate);
                              }
                            },
                      child: Text(
                        _profiles.isEmpty
                            ? 'Fal bağlantısını ayarla'
                            : _message != null
                            ? 'Yeniden Dene'
                            : 'Fal Oluştur',
                      ),
                    ),
                  ExpansionTile(
                    title: const Text('Araştırmaya katkı'),
                    children: [
                      CheckboxListTile(
                        value: session.researchConsentAtUtc != null,
                        title: const Text(
                          'Bu kaydı araştırma paketine eklemeye izin veriyorum.',
                        ),
                        onChanged: _busy
                            ? null
                            : (value) => _act(
                                () => _controller.save(
                                  session.next(researchAllowed: value),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
                if (!widget.simple)
                  ExpansionTile(
                    key: ValueKey('fortune-controls-$hasAnswers'),
                    initiallyExpanded: !modern || !hasAnswers,
                    title: Text(
                      hasAnswers
                          ? 'Yeni Fal ve İnceleme Ayarları'
                          : 'Falını Hazırla',
                    ),
                    children: [
                      const Text(
                        'Önce kendi gözlemlerin kaydedilir. Fotoğrafların telefonda kalır; fal için yalnızca metinsel özet gönderilir.',
                      ),
                      if (session.id.startsWith('linked-'))
                        const Text(
                          'Fotoğraf ve işaretleri değiştirmek için Kayıtlarım ekranını kullan.',
                        ),
                      ExpansionTile(
                        title: const Text('Fotoğraflar ve Yerel İnceleme'),
                        initiallyExpanded:
                            !modern || !session.ready || prepared == null,
                        children: [
                          for (final p in session.orderedPhotos) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 160,
                              child: Center(
                                child: CroppedPhoto(
                                  image: FileImage(
                                    widget.runtime.reviews.file(
                                      p.photo.localName,
                                    ),
                                  ),
                                  photoWidth: p.photo.width,
                                  photoHeight: p.photo.height,
                                  crop: p.visibleCrop,
                                ),
                              ),
                            ),
                            if (p.photo.regions.isNotEmpty)
                              ExpansionTile(
                                title: Text(
                                  'İşaretleri gör · ${p.photo.regions.length}',
                                ),
                                children: [
                                  MarkedPhoto(
                                    photo: p.photo,
                                    image: FileImage(
                                      widget.runtime.reviews.file(
                                        p.photo.localName,
                                      ),
                                    ),
                                    displayCrop: p.visibleCrop,
                                  ),
                                ],
                              ),
                            CheckboxListTile(
                              value: p.usableConfirmedAtUtc != null,
                              title: Text(
                                '${p.title}: telve kullanılabilir biçimde görünüyor',
                              ),
                              onChanged: _busy || p.usableConfirmedAtUtc != null
                                  ? null
                                  : (v) => _act(
                                      () => _controller.save(
                                        session.withPhoto(
                                          p.update(
                                            confirmedAt: DateTime.now()
                                                .toUtc()
                                                .toIso8601String(),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            if (p.failed)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(
                                        () => _controller.analyze(
                                          retryPhotoId: p.id,
                                        ),
                                      ),
                                child: const Text(
                                  'Bu fotoğrafın analizini yeniden dene',
                                ),
                              ),
                          ],
                          CheckboxListTile(
                            value: session.sameSampleDeclared,
                            title: const Text(
                              'Fotoğraflar aynı fincan / telve grubuna ait.',
                            ),
                            onChanged: _busy
                                ? null
                                : (v) => _act(
                                    () => _controller.save(
                                      session.next(sameSample: v),
                                    ),
                                  ),
                          ),
                          FilledButton(
                            onPressed: _busy || !session.ready
                                ? null
                                : () => _act(() => _controller.analyze()),
                            child: const Text('Yerel incelemeyi tamamla'),
                          ),
                        ],
                      ),
                      Text(
                        prepared == null
                            ? 'Analiz bekliyor'
                            : switch (prepared['status']) {
                                'ready' => 'Metin hazır',
                                'partial' => 'Metin hazır · kısmi analiz',
                                'empty' =>
                                  'Kullanılabilir gözlem veya bulgu yok',
                                _ => 'Analiz bekliyor',
                              },
                      ),
                      CheckboxListTile(
                        value: session.researchConsentAtUtc != null,
                        title: const Text(
                          'İsteğe bağlı: bu incelemeyi ve bağlı çekim kaydını araştırma ZIP’ine eklemeye izin veriyorum.',
                        ),
                        onChanged: _busy
                            ? null
                            : (v) => _act(
                                () => _controller.save(
                                  session.next(researchAllowed: v),
                                ),
                              ),
                      ),
                      const Divider(),
                      if (_profiles.isEmpty)
                        const Text(
                          'Önce sağ üstteki AI Laboratuvarından bağlantı ekle.',
                        ),
                      if (_profiles.isNotEmpty)
                        DropdownButton<String>(
                          value: _profiles.any((p) => p.id == _first)
                              ? _first
                              : null,
                          isExpanded: true,
                          hint: const Text('AI seç'),
                          items: [
                            for (final p in _profiles)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} · ${p.model}'),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  _first = v;
                                  if (_second == v) _second = null;
                                }),
                        ),
                      SwitchListTile(
                        value: _compare,
                        title: const Text('İki AI’yı kör karşılaştır'),
                        onChanged: _busy || _profiles.length < 2
                            ? null
                            : (v) => setState(() => _compare = v),
                      ),
                      if (_compare)
                        DropdownButton<String>(
                          value: _second,
                          isExpanded: true,
                          hint: const Text('İkinci AI'),
                          items: [
                            for (final p in _profiles.where(
                              (p) => p.id != _first,
                            ))
                              DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} · ${p.model}'),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _second = v),
                        ),
                      for (final p in _profiles.where(
                        (p) => p.id == _first || (_compare && p.id == _second),
                      ))
                        Text('Metin gönderilecek: ${p.url}'),
                      FilledButton(
                        onPressed:
                            _busy ||
                                !eligible ||
                                _first == null ||
                                (_compare &&
                                    (_second == null || _second == _first))
                            ? null
                            : () => _act(_generate),
                        child: Text(
                          _compare ? 'A/B fal oluştur' : 'Fal oluştur',
                        ),
                      ),
                      if (_busy) ...[
                        const LinearProgressIndicator(),
                        if (_cancel != null)
                          TextButton(
                            onPressed: () => _cancel?.cancel(),
                            child: const Text('İptal et'),
                          ),
                      ],

                      if (prepared != null)
                        ExpansionTile(
                          title: const Text(
                            'Gönderilecek metin · teknik ayrıntılar',
                          ),
                          children: [
                            SelectableText(
                              const JsonEncoder.withIndent(
                                '  ',
                              ).convert(prepared['payload']),
                            ),
                          ],
                        ),
                      if (_results.any((r) => r['state'] == 'interrupted'))
                        const Text(
                          'Önceki deneme uygulama kapanınca kesildi. Sunucu hâlâ çalışıyorsa işin bitmesini bekleyip yeniden deneyebilirsin.',
                        ),
                    ],
                  ),
                if (!modern) ..._fortuneWidgets(),
              ],
            ),
    );
  }

  Future<void> _report(Map<String, dynamic> result, Map answer) async {
    final profiles = await widget.runtime.store.profiles();
    final profile = profiles
        .where(
          (p) =>
              p.id == answer['profileId'] &&
              p.url == answer['profileUrl'] &&
              p.provider == AiProvider.atlas,
        )
        .firstOrNull;
    if (!mounted) return;
    if (profile == null) {
      setState(
        () => _message =
            'Bu eski bağlantıda bildirim desteklenmiyor. Atlas test bağlantısıyla oluşturulan yorumlar bildirilebilir.',
      );
      return;
    }
    var reason = 'misleading';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Bu yorumu bildir'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Aşağıdaki yorum ve seçtiğin neden Atlas test yöneticisine gönderilecek. Fotoğrafların eklenmez.',
                ),
                DropdownButton<String>(
                  value: reason,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'misleading',
                      child: Text('Yanıltıcı yorum'),
                    ),
                    DropdownMenuItem(
                      value: 'harmful',
                      child: Text('Rahatsız edici içerik'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Diğer')),
                  ],
                  onChanged: (v) => update(() => reason = v!),
                ),
                SelectableText(answer['text'] as String),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bildir'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _act(() async {
      await widget.runtime.store.queueReport({
        'id': const Uuid().v4(),
        'sessionId': session.id,
        'profileId': profile.id,
        'url': profile.url,
        'reason': reason,
        'text': answer['text'],
        'state': 'pending',
      });
      final pending = await widget.runtime.sendPendingReports();
      if (mounted) {
        setState(
          () => _message = pending == 0
              ? 'Bildirim iletildi.'
              : 'Bildirim telefonda bekliyor. Ayarlar’dan yeniden gönderebilirsin.',
        );
      }
    });
  }

  List<Widget> _fortuneWidgets() => [
    for (final result in _results.where(
      (r) => (r['answers'] as List).isNotEmpty,
    )) ...[
      const Divider(),
      Text(
        result['sourceFingerprint'] == preparationSourceFingerprint(session)
            ? 'Kayıtlı fal'
            : 'Önceki kayda ait fal',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (result['state'] == 'completed')
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _act(() async {
                  await widget.runtime.store.setStarred(
                    result['id'] as String,
                    !_stars.contains(result['id']),
                  );
                  await _load();
                }),
          icon: Icon(
            _stars.contains(result['id']) ? Icons.star : Icons.star_border,
          ),
          label: Text(
            '${_stars.contains(result['id']) ? 'Yıldızı Kaldır' : 'Falı Yıldızla'} · ${_stars.length}/20',
          ),
        ),
      if (result['state'] != 'completed')
        const Text('Deneme tamamlanamadı. Başarılı yanıt aşağıda korundu.'),
      for (var i = 0; i < (result['answers'] as List).length; i++) ...[
        Text(
          result['comparison'] == true
              ? 'Yanıt ${i == 0 ? 'A' : 'B'}'
              : 'Falın',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        FortuneStory(
          text: result['answers'][i]['text'] as String,
          hasSymbols: ((result['context'] as Map)['photos'] as List).any(
            (p) => (p['userObservations'] as List).isNotEmpty,
          ),
        ),
        TextButton.icon(
          onPressed: _busy
              ? null
              : () => _report(result, result['answers'][i] as Map),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Bu yorumu bildir'),
        ),
        if (!widget.simple &&
            (result['comparison'] != true || result['vote'] != null))
          ExpansionTile(
            title: const Text('Model ve teknik bilgiler'),
            children: [
              Text(
                '${result['answers'][i]['model']} · ${result['answers'][i]['durationMs']} ms',
              ),
            ],
          ),
        const SizedBox(height: 16),
      ],
      if (result['comparison'] == true &&
          result['state'] == 'completed' &&
          result['vote'] == null)
        Wrap(
          spacing: 8,
          children: [
            for (final choice in ['A', 'B', 'Eşit', 'İkisi de uygun değil'])
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => _vote(result, choice)),
                child: Text(choice),
              ),
          ],
        ),
      if (result['vote'] != null) Text('Tercihin: ${result['vote']}'),
    ],
  ];
}
