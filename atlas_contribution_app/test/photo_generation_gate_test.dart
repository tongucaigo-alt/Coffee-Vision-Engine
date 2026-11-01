import 'dart:async';
import 'dart:io';

import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'fixtures.dart';
import 'mvp_review_test.dart' show fakeEngine;
import 'photo_set_test.dart' show setDraft, setImage;
import 'suitability_fixture.dart';

class _PausedCheck extends SupportedSuitability {
  final result = Completer<void>();
  String status = 'uncertain';
  @override
  Future<Map<String, dynamic>> assess(
    File file,
    ContributionPhoto p, {
    bool retry = false,
  }) async {
    await result.future;
    return {...await super.assess(file, p), 'status': status};
  }
}

class _Client extends AiClient {
  _Client(super.prompt);
  int requests = 0;
  Future<void> Function()? beforePreflight;
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
    void Function(String stage, int elapsedMs)? onStage,
    AiGenerationBudget? budget,
    int maxAttempts = 2,
  }) async {
    await beforePreflight?.call();
    await beforeRequest?.call();
    requests++;
    fail('Blocked photos must never reach the transport');
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 35; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'pending and uncertain preview keeps editing and saving but blocks generation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late MemoryStore store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('atlas-preview-gate-');
        store = MemoryStore(root, setDraft());
        final p = await store.importGallery(setImage(0));
        store.draft = store.draft!.withPhoto(p.asSetPhoto());
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => root.delete(recursive: true));
      });
      final checker = _PausedCheck();
      final service = PausedService(store);
      var generated = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ContributionHome(
            modern: true,
            store: store,
            service: service,
            photoSuitability: checker,
            aiDescription: () async => 'Test',
            onGenerateFortune: (_) async {
              generated++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Fotoğraf kontrol ediliyor…'), findsOneWidget);
      checker.result.complete();
      await _settle(tester);
      expect(
        find.textContaining('Fincanın içini ve telveyi daha net göster.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Kontrolü Yeniden Dene'), findsOneWidget);
      await tester.tap(find.text('Bu fotoğraflarla devam et'));
      await tester.pumpAndSettle();
      final action = find
          .ancestor(
            of: find.text('Falımı Oluştur'),
            matching: find.byType(AtlasPrimaryButton),
          )
          .first;
      expect(tester.widget<AtlasPrimaryButton>(action).onPressed, isNull);
      expect(find.text('İşaret').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Yalnız Kaydet'));
      await tester.pumpAndSettle();
      expect(service.submissions, 1);
      expect(store.rows, hasLength(1));
      expect(generated, 0);
    },
  );

  for (final status in [
    'uncertain',
    'unsuitable',
    'error',
    'changed-before-request',
  ]) {
    testWidgets(
      '$status cannot bypass the saved-record generation guard',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory root;
        late AiRuntime runtime;
        late ReviewSession session;
        late _Client client;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          PhotoSuitability.imageScreenChannel,
          (_) async => {
            'modelSha256': localImageScreenModelSha256,
            'scores': switch (status) {
              'unsuitable' => [
                localImageScreenRejectBelow - 1,
                localImageScreenRejectBelow - 1,
              ],
              'error' => [double.nan, 0.0],
              _ => [0.0, 0.0],
            },
          },
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            PhotoSuitability.imageScreenChannel,
            null,
          ),
        );
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('atlas-ai-photo-gate-');
          final source = DraftStore(Directory('${root.path}/source'));
          await source.initialize();
          client = _Client(
            FortunePrompt(
              await rootBundle.loadString('assets/fortune-prompt-v1.json'),
            ),
          );
          runtime = await AiRuntime.create(
            source,
            client: client,
            readKey: (_) async => '',
          );
          final photo = await runtime.reviews.importPhoto(
            testImage(),
            surface: ReviewSurface.cup,
          );
          session = ReviewSession(
            id: 'gate',
            groupId: 'gate-group',
            createdAtUtc: '2026-10-22T00:00:00Z',
            localConsentAtUtc: '2026-10-22T00:00:00Z',
            sameSampleDeclared: true,
            photos: [photo.update(confirmedAt: '2026-10-22T00:00:00Z')],
          );
          await runtime.reviews.save(session);
          await runtime.store.saveProfile(
            const AiProfile(
              id: 'fake',
              name: 'fake',
              url: 'https://fake.example/v1',
              model: 'fake',
              provider: AiProvider.direct,
            ),
          );
          if (status == 'changed-before-request') {
            // Preflight succeeds. Mutate the bytes only when the transport invokes
            // its final request callback, after preparation has finished.
            final checker = PhotoSuitability(
              Directory('${root.path}/photo-suitability'),
            );
            final accepted = await checker.continueWith(
              photo.photo,
              await SupportedSuitability().assess(
                runtime.reviews.file(photo.photo.localName),
                photo.photo,
              ),
            );
            session = session.withPhoto(
              session.photos.single.update(
                suitability: accepted,
                photo: photo.photo.annotated([
                  RegionAnnotation(
                    id: 'bird',
                    label: 'bird',
                    box: RegionBox(.2, .2, .2, .2),
                  ),
                ], PhotoDecision.marked),
              ),
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
            client.beforePreflight = () async =>
                runtime.reviews.file(photo.photo.localName).writeAsBytes([0]);
          }
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.runAsync(
          () => tester.pumpWidget(
            MaterialApp(
              theme: atlasTheme(),
              home: AiFortunePage(
                runtime: runtime,
                session: session,
                simple: true,
                autoGenerate: true,
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(client.requests, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          (await tester.runAsync(
            () => runtime.reviews.sessions(),
          ))!.single.photos,
          hasLength(1),
        );
        if (status == 'uncertain') {
          expect(
            find.textContaining('Fincanın içini ve telveyi daha net göster.'),
            findsOneWidget,
          );
        }
        if (status == 'changed-before-request') {
          expect(
            (await tester.runAsync(
              () => runtime.store.results(session.id),
            ))!.single['state'],
            'failed',
          );
        }
        expect(tester.takeException(), isNull);
      },
      skip: !localImageScreenEnabled,
    );
  }
}
