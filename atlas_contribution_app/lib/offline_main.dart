import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/contribution_home.dart';
import 'src/local_store.dart';
import 'src/offline_contribution.dart';
import 'src/theme.dart';
import 'src/mvp/review_page.dart';
import 'src/mvp/review_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DraftStore(
    Directory(
      '${(await getApplicationSupportDirectory()).path}/offline-contributions',
    ),
  );
  await store.initialize();
  runApp(OfflineContributionApp(store: store));
}

class OfflineContributionApp extends StatelessWidget {
  const OfflineContributionApp({required this.store, super.key});

  final DraftStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Atlas Katkı · Yerel',
    debugShowCheckedModeBanner: false,
    theme: contributionTheme(),
    home: Builder(
      builder: (context) => ContributionHome(
        store: store,
        service: OfflineContributionService(store),
        onReview: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ReviewHub(
                store: ReviewStore(
                  Directory('${store.directory.parent.path}/mvp-reviews'),
                ),
                captureStore: store,
              ),
            ),
          );
        },
        onExport: () async {
          final result = await OfflineContributionExporter(
            store,
          ).exportToDownloads();
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Paket hazır'),
              content: SelectableText(
                '${result.recordCount} kayıt İndirilenler klasörüne kaydedildi.\n\n'
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
