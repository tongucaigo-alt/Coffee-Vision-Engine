import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/contribution_home.dart';
import 'src/local_store.dart';
import 'src/offline_contribution.dart';
import 'src/research_export.dart';
import 'src/atlas_design.dart';
import 'src/models.dart';
import 'src/fortune_progress.dart';
import 'src/mvp/review_controller.dart';
import 'src/mvp/review_models.dart';
import 'src/mvp/review_page.dart';
import 'src/mvp/review_store.dart';
import 'src/ai/ai_contract.dart';
import 'src/ai/ai_runtime.dart';
import 'src/ai/ai_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DraftStore(
    Directory(
      '${(await getApplicationSupportDirectory()).path}/offline-contributions',
    ),
  );
  await store.initialize();
  final ai = aiLabEnabled ? await AiRuntime.create(store) : null;
  runApp(OfflineContributionApp(store: store, ai: ai));
}

class OfflineContributionApp extends StatelessWidget {
  const OfflineContributionApp({required this.store, this.ai, super.key});

  final DraftStore store;
  final AiRuntime? ai;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Atlas',
    debugShowCheckedModeBanner: false,
    theme: atlasTheme(),
    home: Builder(
      builder: (context) => ContributionHome(
        modern: true,
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
                      (p) => confirmed.contains('${p.localName}|${p.checksum}'),
                    )) {
                  return RecordPreparationStatus.pending;
                }
                final session = await ai!.bridge.importReceipt(
                  row,
                  fresh: true,
                );
                final now = DateTime.now().toUtc().toIso8601String();
                final next = session.next(
                  sameSample: true,
                  photos: session.photos.map((p) => p.update(confirmedAt: now)),
                );
                final controller = ReviewController(
                  store: ai!.reviews,
                  session: session,
                );
                try {
                  await controller.save(next);
                  controller.addListener(() {
                    final id = controller.activePhotoId;
                    if (id != null) {
                      final p = controller.session.photos.firstWhere(
                        (p) => p.id == id,
                      );
                      ai!.progress.value = FortuneProgress(
                        FortunePhase.analyzing,
                        photoId: p.photo.localName,
                      );
                    }
                  });
                  await controller.analyze(enrich: true);
                  if (controller.setupError != null) {
                    return RecordPreparationStatus.failed;
                  }
                  return switch (controller.session.preparedInput?['status']) {
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
        recordState: ai == null
            ? null
            : (row) async {
                final id = ai!.bridge.sessionId(row['root_id'] as String);
                final data = await ai!.store.read();
                final results = (data['results'] as List).where(
                  (r) =>
                      r['sessionId'] == id && (r['answers'] as List).isNotEmpty,
                );
                if (results.isEmpty) return 'Telefona kaydedildi';
                final session = (await ai!.reviews.sessions())
                    .where((s) => s.id == id)
                    .firstOrNull;
                final link = (data['links'] as Map)[row['root_id']] as Map?;
                if (session == null ||
                    link?['receiptId'] != (row['document'] as Map)['id']) {
                  return 'Önceki kayda ait fal';
                }
                final current = results.where(
                  (r) =>
                      r['sourceFingerprint'] ==
                      preparationSourceFingerprint(session),
                );
                if (current.isEmpty) return 'Önceki kayda ait fal';
                return current.any((r) => r['state'] == 'completed')
                    ? 'Fal hazır'
                    : 'Fal denemesi tamamlanmadı';
              },
        onReadFortune: ai == null
            ? null
            : (row) async {
                final session = await ai!.bridge.importReceipt(row);
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AiFortunePage(runtime: ai!, session: session),
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
        onExport: () async {
          final result = await OfflineContributionExporter(
            store,
            reviewStore: ai?.reviews,
            exposureAudit: ai?.store.researchAudit,
          ).exportToDownloads();
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Paket hazır'),
              content: SelectableText(
                '${result.recordCount} kayıt ${exportDestinationLabel(result.location)} kaydedildi.\n\n'
                '${result.fileName}\n\nKontrol kodu:\n${result.checksum}',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
