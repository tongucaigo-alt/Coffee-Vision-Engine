import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/trace_overlay.dart';

/// Explicit paid test, synthetic diagnostic record only. No contributor consent
/// or records in the normal application's package are touched.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'one save action to real Kimi result with one preparation state',
    (tester) async {
      final temp = await getTemporaryDirectory();
      final base = Directory('${temp.path}/opencv-kimi-${const Uuid().v4()}');
      final source = DraftStore(
        Directory('${base.path}/source'),
        manualRetention: true,
      );
      await source.initialize();
      await source.acceptLocalUse(); // Test fixture, not a human's declaration.
      final raw = await File(
        '/data/local/tmp/atlas-opencv-v49/c1.jpg',
      ).readAsBytes();
      final prepared = preparePhoto(raw);
      final bytes = prepared['bytes'] as Uint8List;
      const name = 'diagnostic-cup.jpg';
      await source.file(name).writeAsBytes(bytes);
      final now = DateTime.now().toUtc().toIso8601String(),
          id = const Uuid().v4();
      final photo = ContributionPhoto(
        id: 'diagnostic-cup',
        role: null,
        localName: name,
        checksum: prepared['checksum'] as String,
        originalChecksum: prepared['originalChecksum'] as String,
        width: prepared['width'] as int,
        height: prepared['height'] as int,
        byteLength: bytes.length,
        capturedAt: null,
        importedAt: now,
        decision: PhotoDecision.skipped,
      );
      await source.save(
        ContributionDraft(
          id: id,
          rootId: id,
          groupId: const Uuid().v4(),
          createdAt: now,
          consentedAt: now,
          kind: ContributionKind.photoSet,
          galleryStart: true,
          cupSelectionDone: true,
          saucerDecided: true,
          photos: [photo],
        ),
      );
      final runtime = await AiRuntime.create(source);
      await tester.pumpWidget(
        OfflineContributionApp(store: source, ai: runtime),
      );
      Future<void> waitFor(bool Function() condition, int seconds) async {
        final clock = Stopwatch()..start();
        while (!condition() && clock.elapsed < Duration(seconds: seconds)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue);
      }

      await waitFor(
        () => find.text('Kaldığın Yerden Devam Et').evaluate().isNotEmpty,
        20,
      );
      await tester.tap(find.text('Kaldığın Yerden Devam Et'));
      await tester.pump();
      await waitFor(
        () => find.text('Kaydet ve Falını Oluştur').evaluate().isNotEmpty,
        20,
      );
      final button = find.widgetWithText(
        FilledButton,
        'Kaydet ve Falını Oluştur',
      );
      await waitFor(
        () => tester.widget<FilledButton>(button).onPressed != null,
        30,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await waitFor(() => find.byType(FortuneScan).evaluate().isNotEmpty, 10);
      final state = tester.state(find.byType(FortuneScan));
      final phases = <String>{};
      final clock = Stopwatch()..start();
      while (runtime.preparation.active &&
          clock.elapsed < const Duration(seconds: 200)) {
        phases.add(runtime.progress.value.phase.name);
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(FortuneScan).evaluate().isNotEmpty) {
          expect(tester.state(find.byType(FortuneScan)), same(state));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(runtime.preparation.active, isFalse);
      final receipts = await source.receipts();
      expect(receipts, hasLength(1));
      final sessionId = runtime.bridge.sessionId(id);
      final results = await runtime.store.results(sessionId);
      expect(
        results.where((r) => r['state'] == 'completed'),
        hasLength(1),
        reason: 'Real Kimi must produce a saved result.',
      );
      expect(find.byType(AiFortunePage), findsOneWidget);
      expect(find.byType(FortuneScan), findsNothing);
      final result = results.single;
      expect(jsonEncode(result['context']), isNot(contains('pixels')));
      expect(jsonEncode(result['context']), isNot(contains(base.path)));
      final text = (result['answers'] as List).first['text'] as String;
      expect(text.trim(), isNotEmpty);
      final sessions = await runtime.reviews.sessions();
      final initial = jsonEncode(sessions.single.initialObservations);
      final traces = await runtime.traces.loadSet(
        owner: sessionId,
        photos: sessions.single.photos.map((p) => p.photo).toList(),
        fileFor: (p) => runtime.reviews.file(p.localName),
      );
      expect(traces.selected, isNotEmpty);
      await tester.ensureVisible(find.byType(TracePhoto).first);
      await tester.tap(find.byType(TracePhoto).first);
      await tester.pumpAndSettle();
      expect(find.text('Renkli izler'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Falı Yıldızla'));
      await tester.tap(find.textContaining('Falı Yıldızla'));
      await tester.pumpAndSettle();
      expect(await runtime.store.starredIds(), contains(result['id']));
      expect(
        jsonEncode(
          (await runtime.reviews.sessions()).single.initialObservations,
        ),
        initial,
      );
      final output = await getExternalStorageDirectory();
      final report = {
        'phases': phases.toList(),
        'durationMs': clock.elapsedMilliseconds,
        'completedResults': results.length,
        'traces': traces.selected.length,
        'text': text,
      };
      await File(
        '${output!.path}/opencv-v49-kimi.json',
      ).writeAsString(jsonEncode(report));
      binding.reportData = {
        'phases': phases.toList(),
        'completedResults': results.length,
        'traces': traces.selected.length,
      };
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !const bool.fromEnvironment('ATLAS_REAL_KIMI_TEST'),
  );
}
