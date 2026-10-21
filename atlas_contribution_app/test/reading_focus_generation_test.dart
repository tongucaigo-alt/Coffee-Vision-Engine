import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/reading_identity.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'fixtures.dart';
import 'mvp_review_test.dart' show fakeEngine;
import 'suitability_fixture.dart';

class FocusClient extends AiClient {
  FocusClient(super.prompt);
  final topics = <String>[];
  Future<void> Function()? beforeReply;
  @override
  Future<Map<String, dynamic>> generate(
    AiProfile p,
    String key,
    Map<String, dynamic> context, {
    required AiCancellation cancellation,
    required void Function(String) onStatus,
    String? requestId,
    List<String> previousTexts = const [],
    void Function(FortuneProgress)? onProgress,
    Future<void> Function()? beforeRequest,
    AiGenerationBudget? budget,
    int maxAttempts = 2,
  }) async {
    await beforeRequest?.call();
    cancellation.check();
    topics.add(context['readingFocus'] as String);
    await beforeReply?.call();
    return {
      'text':
          'Yeni ${context['readingFocus']} konulu fal. Sakin bir değerlendirme sana eşlik edebilir.',
      'model': 'fake',
      'durationMs': 1,
      'promptVersion': prompt.version,
      'promptHash': prompt.hash,
      'noThink': true,
      'attempts': 1,
    };
  }
}

void main() {
  for (final oldFocus in ['general', 'love']) {
    testWidgets(
      'completed starred $oldFocus survives topic change, explicit generation and reopening',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory root;
        late AiRuntime runtime;
        late ReviewSession session;
        late FocusClient client;
        late Map<String, dynamic> oldResult;
        late String fingerprint;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp(
            'atlas-focus-generation-',
          );
          final source = DraftStore(
            Directory('${root.path}/offline-contributions'),
            manualRetention: true,
          );
          await source.initialize();
          client = FocusClient(
            FortunePrompt(
              await rootBundle.loadString('assets/fortune-prompt-v1.json'),
            ),
          );
          runtime = await AiRuntime.create(
            source,
            client: client,
            readKey: (_) async => '',
          );
          final imported = await runtime.reviews.importPhoto(
            testImage(),
            surface: ReviewSurface.cup,
          );
          final checker = PhotoSuitability(
            Directory('${root.path}/photo-suitability'),
          );
          final suitability = await checker.continueWith(
            imported.photo,
            await SupportedSuitability().assess(
              runtime.reviews.file(imported.photo.localName),
              imported.photo,
            ),
          );
          final photo = imported.update(
            confirmedAt: '2026-10-01T00:00:00Z',
            suitability: suitability,
            photo: imported.photo.annotated([
              RegionAnnotation(
                id: 'bird',
                label: 'bird',
                box: RegionBox(.2, .2, .2, .2),
              ),
            ], PhotoDecision.marked),
          );
          session = ReviewSession(
            id: 'focus',
            groupId: 'focus-group',
            createdAtUtc: '2026-10-01T00:00:00Z',
            localConsentAtUtc: '2026-10-01T00:00:00Z',
            sameSampleDeclared: true,
            photos: [photo],
          );
          await runtime.reviews.save(session);
          final controller = ReviewController(
            store: runtime.reviews,
            session: session,
            loadEngine: () async => fakeEngine(),
          );
          await controller.analyze();
          session = controller.session;
          controller.dispose();
          fingerprint = preparationSourceFingerprint(session);
          await runtime.store.saveProfile(
            const AiProfile(
              id: 'fake',
              name: 'fake',
              url: 'https://fake.example/v1',
              model: 'fake',
              provider: AiProvider.direct,
            ),
          );
          oldResult = {
            'id': 'legacy-result',
            'sessionId': session.id,
            'groupId': session.groupId,
            'sourceFingerprint': fingerprint,
            'createdAtUtc': '2026-10-01T00:00:00Z',
            'state': 'completed',
            'comparison': false,
            'context': {
              ...(session.preparedInput!['payload'] as Map),
              'version': 'atlas-fortune-context-v4',
              if (oldFocus != 'general') 'readingFocus': oldFocus,
            },
            'answers': [
              {
                'text': 'Eski $oldFocus konulu fal korunuyor.',
                'model': 'fake',
                'durationMs': 1,
              },
            ],
          };
          await runtime.store.saveResult(oldResult);
          await runtime.store.setStarred('legacy-result', true);
          await runtime.store.setReadingFocus(session.id, 'money');
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            await root.delete(recursive: true);
          });
        });
        var page = 0;
        Future<void> settleIo() async {
          for (var i = 0; i < 45; i++) {
            await tester.runAsync(() async {
              await tester.pump(const Duration(milliseconds: 20));
              await Future<void>.delayed(const Duration(milliseconds: 20));
            });
          }
          await tester.pumpAndSettle();
        }

        Future<void> open({bool generate = false}) async {
          await tester.runAsync(() async {
            session = (await runtime.reviews.sessions()).single;
            await tester.pumpWidget(
              MaterialApp(
                theme: atlasTheme(),
                home: AiFortunePage(
                  key: ValueKey(++page),
                  runtime: runtime,
                  session: session,
                  simple: true,
                  autoGenerate: generate,
                ),
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await settleIo();
        }

        await open();
        expect(
          client.topics,
          isEmpty,
          reason: 'Reading after a topic change must not generate.',
        );
        expect(find.text('Önceki kayda ait fal'), findsOneWidget);
        await tester.ensureVisible(find.text('Fal Oluştur'));
        await tester.runAsync(() => tester.tap(find.text('Fal Oluştur')));
        await settleIo();
        expect(client.topics, ['money']);
        await tester.runAsync(() async {
          final rows = await runtime.store.results(session.id);
          expect(
            rows.singleWhere((r) => r['id'] == 'legacy-result'),
            oldResult,
          );
          final current = rows.singleWhere((r) => r['id'] != 'legacy-result');
          expect(current['state'], 'completed');
          expect(current['sourceFingerprint'], fingerprint);
          expect(
            current['readingRequestKey'],
            readingRequestKey(session.id, fingerprint, 'money'),
          );
          expect(await runtime.store.starredIds(), {'legacy-result'});
          expect(
            (await runtime.store.read())['fortuneMemoryV1']['completedKeys']
                .length,
            2,
          );
        });
        await open(generate: true);
        expect(client.topics, [
          'money',
        ], reason: 'The completed money reading is reused.');
        await tester.runAsync(
          () => runtime.store.setReadingFocus(session.id, oldFocus),
        );
        await open(generate: true);
        expect(client.topics, [
          'money',
        ], reason: 'The old completed reading is also reused.');
        await tester.runAsync(
          () => runtime.store.setReadingFocus(session.id, 'work'),
        );
        client.beforeReply = () =>
            runtime.store.setReadingFocus(session.id, oldFocus);
        await open(generate: true);
        expect(client.topics, ['money', 'work']);
        await tester.runAsync(() async {
          final rows = await runtime.store.results(session.id);
          expect(rows.where((r) => r['state'] == 'completed'), hasLength(2));
          expect(rows.last['state'], 'failed');
          expect(
            (await runtime.store.read())['fortuneMemoryV1']['completedKeys']
                .length,
            2,
          );
          expect(await runtime.store.starredIds(), {'legacy-result'});
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
