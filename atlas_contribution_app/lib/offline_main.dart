import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/contribution_home.dart';
import 'src/local_store.dart';
import 'src/offline_contribution.dart';
import 'src/atlas_design.dart';
import 'src/coffee_guide_gate.dart';
import 'src/coffee_guide_page.dart';
import 'src/coffee_guide_store.dart';
import 'src/models.dart';
import 'src/fortune_progress.dart';
import 'src/fortune_preparation.dart';
import 'src/photo_suitability.dart';
import 'src/opencv_traces.dart';
import 'src/mvp/review_controller.dart';
import 'src/mvp/review_models.dart';
import 'src/mvp/review_page.dart';
import 'src/mvp/review_store.dart';
import 'src/ai/ai_contract.dart';
import 'src/ai/ai_runtime.dart';
import 'src/ai/ai_pages.dart';
import 'src/ai/ai_recovery_page.dart';
import 'src/ai/record_summaries.dart';
import 'src/tarot/tarot_runtime.dart';
import 'src/tarot/tarot_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DraftStore(
    Directory(
      '${(await getApplicationSupportDirectory()).path}/offline-contributions',
    ),
    manualRetention: true,
  );
  await store.initialize();
  runApp(OfflineStartupApp(store: store));
}

class OfflineStartupApp extends StatefulWidget {
  const OfflineStartupApp({
    required this.store,
    this.aiEnabled = aiLabEnabled || playTestEnabled,
    this.createAi = AiRuntime.create,
    this.createTarot = TarotRuntime.create,
    this.guideStore,
    super.key,
  });
  final DraftStore store;
  final bool aiEnabled;
  final Future<AiRuntime> Function(DraftStore) createAi;
  final Future<TarotRuntime> Function(Directory, AiRuntime?) createTarot;
  final CoffeeGuideStore? guideStore;
  @override
  State<OfflineStartupApp> createState() => _OfflineStartupAppState();
}

class _OfflineStartupAppState extends State<OfflineStartupApp> {
  bool _loading = false;
  AiRuntime? _ai;
  TarotRuntime? _tarot;
  String? _aiError, _tarotError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _aiError = null;
      _tarotError = null;
    });
    widget.store.readOnlyReason = null;
    _ai = null;
    if (widget.aiEnabled) {
      try {
        _ai = await widget.createAi(widget.store);
      } catch (error) {
        _aiError = error is LocalStoreRecovery
            ? error.message
            : 'AI kayıtları açılamadı. Fotoğrafların ve falların sıfırlanmadı. Güvenlik için kahve kayıtları salt okunur durumda.';
        widget.store.readOnlyReason = _aiError;
      }
    }
    _tarot?.dispose();
    _tarot = null;
    try {
      _tarot = await widget.createTarot(
        Directory('${widget.store.directory.parent.path}/tarot-local'),
        _ai,
      );
    } catch (_) {
      _tarotError =
          'Tarot kayıtları veya kartları okunamadı. Kayıtlar silinmedi. Uygulamayı yeniden açarak deneyebilirsin.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tarot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        theme: atlasTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_aiError != null) {
      return MaterialApp(
        title: 'Atlas',
        debugShowCheckedModeBanner: false,
        theme: atlasTheme(),
        home: AiRecoveryPage(
          store: widget.store,
          message: _aiError!,
          onRetry: _load,
          tarotPage: _tarot == null ? null : TarotHomePage(runtime: _tarot!),
          tarotHistoryPage: _tarot == null
              ? null
              : TarotHistoryPage(runtime: _tarot!),
        ),
      );
    }
    return OfflineContributionApp(
      store: widget.store,
      ai: _ai,
      tarot: _tarot,
      tarotError: _tarotError,
      guideStore: widget.guideStore,
    );
  }
}

class OfflineContributionApp extends StatelessWidget {
  const OfflineContributionApp({
    required this.store,
    this.ai,
    this.tarot,
    this.tarotError,
    this.guideStore,
    super.key,
  });

  final DraftStore store;
  final AiRuntime? ai;
  final TarotRuntime? tarot;
  final String? tarotError;
  final CoffeeGuideStore? guideStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Atlas',
    debugShowCheckedModeBanner: false,
    theme: atlasTheme(),
    builder: (context, child) => ai == null
        ? child!
        : FortunePreparationHost(controller: ai!.preparation, child: child!),
    home: Builder(
      builder: (context) => CoffeeGuideGate(
        store:
            guideStore ??
            CoffeeGuideStore(
              Directory('${store.directory.parent.path}/coffee-guide'),
            ),
        child: ContributionHome(
          modern: true,
          onOpenGuide: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (routeContext) => CoffeeGuidePage(
                allowClose: true,
                onClose: () => Navigator.pop(routeContext),
                onComplete: (_) async => Navigator.pop(routeContext),
              ),
            ),
          ),
          tarotHistoryPage: tarot != null
              ? TarotHistoryPage(runtime: tarot!, embedded: true)
              : null,
          tarotPage: tarot != null
              ? TarotHomePage(runtime: tarot!)
              : tarotError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AtlasNotice(tarotError!),
                  ),
                )
              : null,
          store: store,
          service: OfflineContributionService(store),
          onAiSettings: ai == null
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AiLabPage(runtime: ai!),
                    ),
                  );
                },
          onRecorded: ai == null
              ? null
              : (row) async {
                  if (((row['document'] as Map)['photos'] as List).isNotEmpty) {
                    await ai!.bridge.importReceipt(row, fresh: true);
                  }
                },
          fortuneProgress: ai?.progress,
          preparation: ai?.preparation,
          loadReadingFocus: ai == null
              ? null
              : (rootId) =>
                    ai!.store.readingFocus(ai!.bridge.sessionId(rootId)),
          onReadingFocusChanged: ai == null
              ? null
              : (rootId, focus) => ai!.store.setReadingFocus(
                  ai!.bridge.sessionId(rootId),
                  focus,
                ),
          loadAnnotationTraces: ai == null || !openCvTracesEnabled
              ? null
              : (draft) => ai!.traces.loadSet(
                  owner: ai!.bridge.sessionId(draft.rootId),
                  photos: draft.photos,
                  fileFor: (photo) => store.file(photo.localName),
                ),
          onAnnotationTraceShown: ai == null
              ? null
              : (draft, photo) => ai!.store.exposeTraceAid(
                  sessionId: ai!.bridge.sessionId(draft.rootId),
                  groupId: draft.groupId,
                  photoIdentity: tracePhotoIdentity(photo),
                  algorithm: traceAlgorithm,
                ),
          aiDescription: ai == null
              ? null
              : () async {
                  final profiles = await ai!.store.profiles();
                  if (profiles.isEmpty) return null;
                  final p = profiles.first;
                  try {
                    validateAiUrl(p.url);
                  } catch (_) {
                    return null;
                  }
                  return '${p.name} · ${Uri.parse(p.url).host}';
                },
          onGenerateFortune: ai == null
              ? null
              : (row) async {
                  final session = await ai!.bridge.importReceipt(row);
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AiFortunePage(
                        runtime: ai!,
                        session: session,
                        autoGenerate: true,
                        simple: true,
                      ),
                    ),
                  );
                },
          onConfirmedRecorded: ai == null
              ? null
              : (row, confirmed) async {
                  final source = ContributionDraft.fromJson(
                    Map<String, dynamic>.from(row['document'] as Map),
                  );
                  if (source.cups.isEmpty ||
                      !source.photos.every(
                        (p) =>
                            confirmed.contains('${p.localName}|${p.checksum}'),
                      )) {
                    return RecordPreparationStatus.pending;
                  }
                  final session = await ai!.bridge.importReceipt(
                    row,
                    fresh: true,
                  );
                  final checker = PhotoSuitability(
                    Directory(
                      '${store.directory.parent.path}/photo-suitability',
                    ),
                  );
                  final photos = <ReviewPhoto>[];
                  for (final p in session.photos) {
                    photos.add(
                      p.update(suitability: await checker.read(p.photo)),
                    );
                  }
                  final next = session.next(sameSample: true, photos: photos);
                  final controller = ReviewController(
                    store: ai!.reviews,
                    session: session,
                  );
                  try {
                    await controller.save(next);
                    controller.addListener(() {
                      if (controller.session.currentInitialObservation !=
                          null) {
                        ai!.preparation.permitDisplay();
                      }
                      final id = controller.activePhotoId;
                      if (id != null) {
                        final p = controller.session.photos.firstWhere(
                          (p) => p.id == id,
                        );
                        ai!.progress.value = FortuneProgress(
                          FortunePhase.analyzing,
                          photoId: source.photos
                              .firstWhere(
                                (original) =>
                                    original.fileKey == p.photo.fileKey &&
                                    original.checksum == p.photo.checksum,
                              )
                              .localName,
                        );
                      }
                    });
                    await controller.analyze(
                      enrich: true,
                      isCancelled: () => ai!.preparation.cancelled,
                    );
                    if (controller.setupError != null) {
                      return RecordPreparationStatus.failed;
                    }
                    return switch (controller
                        .session
                        .preparedInput?['status']) {
                      'ready' => RecordPreparationStatus.ready,
                      'partial' => RecordPreparationStatus.partial,
                      'empty' => RecordPreparationStatus.empty,
                      _ => RecordPreparationStatus.pending,
                    };
                  } finally {
                    await controller.close();
                    controller.dispose();
                  }
                },
          loadRecordSummaries: ai == null
              ? null
              : (rows) => readRecordSummaries(
                  rows,
                  readAi: ai!.store.read,
                  readSessions: ai!.reviews.sessions,
                ),
          onReadFortune: ai == null
              ? null
              : (row) async {
                  final session = await ai!.bridge.importReceipt(row);
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AiFortunePage(
                        runtime: ai!,
                        session: session,
                        simple: true,
                      ),
                    ),
                  );
                },
          onReview: () async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ReviewHub(
                  ai: ai,
                  store:
                      ai?.reviews ??
                      ReviewStore(
                        Directory('${store.directory.parent.path}/mvp-reviews'),
                        contributionStore: store,
                      ),
                  captureStore: store,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
