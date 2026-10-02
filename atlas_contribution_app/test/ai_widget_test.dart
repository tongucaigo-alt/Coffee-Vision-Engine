import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'dart:convert';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'dart:io';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'suitability_fixture.dart';
import 'package:atlas_contribution_app/offline_main.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'fixtures.dart';
import 'mvp_review_test.dart' show fakeEngine;

class _Client extends AiClient {
  _Client(super.prompt);
  final inputs = <Map<String, dynamic>>[];
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
  }) async {
    inputs.add(context);
    return {
      'text': List.filled(
        25,
        'Belki bu dağılım sana sakinlik için bir alan çağrıştırıyor.',
      ).join(' '),
      'model': 'hidden-${p.model}',
      'durationMs': 10,
      'promptVersion': prompt.version,
      'promptHash': prompt.hash,
      'noThink': true,
    };
  }
}

void main() {
  testWidgets('main records screen opens one canonical linked AI review', (
    tester,
  ) async {
    late Directory temp;
    late DraftStore source;
    late AiRuntime runtime;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('atlas-ai-main-');
      source = DraftStore(Directory('${temp.path}/source'));
      await source.initialize();
      final prepared = preparePhoto(testImage());
      final bytes = prepared['bytes']! as Uint8List;
      final photos = <ContributionPhoto>[];
      for (final role in freeCaptureRoles) {
        final name = '${role.name}.jpg';
        await source.file(name).writeAsBytes(bytes);
        photos.add(
          ContributionPhoto(
            role: role,
            localName: name,
            checksum: prepared['checksum'] as String,
            originalChecksum: prepared['originalChecksum'] as String,
            width: prepared['width'] as int,
            height: prepared['height'] as int,
            byteLength: bytes.length,
            capturedAt: DateTime.now().toUtc().toIso8601String(),
            decision: PhotoDecision.skipped,
          ),
        );
      }
      final base = testDraft();
      final draft = ContributionDraft(
        id: base.id,
        rootId: base.rootId,
        groupId: base.groupId,
        createdAt: base.createdAt,
        consentedAt: base.consentedAt,
        kind: ContributionKind.freeThreeAngle,
        photos: photos,
      );
      await source.saveReceipt(
        await OfflineContributionService(
          source,
        ).submit(draft, (p) => source.file(p.localName).readAsBytes(), (_) {}),
      );
      runtime = await AiRuntime.create(source, readKey: (_) async => '');
      await tester.pumpWidget(
        OfflineContributionApp(store: source, ai: runtime),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    addTearDown(() async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await temp.delete(recursive: true);
    });
    Future<void> settleIo() async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
    }

    await settleIo();
    await tester.ensureVisible(find.text('Kayıtlarım').first);
    await tester.runAsync(() => tester.tap(find.text('Kayıtlarım').first));
    await settleIo();
    await tester.runAsync(
      () => tester.tap(find.textContaining('Fincanın Hikâyesi').first),
    );
    await settleIo();
    await tester.ensureVisible(find.text('Fal Oluştur'));
    await tester.runAsync(() => tester.tap(find.text('Fal Oluştur')));
    await settleIo();
    expect(find.byType(AiFortunePage), findsOneWidget);
    final sessions = await tester.runAsync(() => runtime.reviews.sessions());
    expect(sessions, hasLength(1));
    expect(sessions!.single.photos.map((p) => p.photo.role), freeCaptureRoles);
    expect(sessions.single.observationHistory, 'unknown');
    final home = tester.widget<ContributionHome>(
      find.byType(ContributionHome, skipOffstage: false),
    );
    final row = (await tester.runAsync(() => source.receipts()))!.single;
    final sourcePhotos = ContributionDraft.fromJson(
      Map<String, dynamic>.from(row['document'] as Map),
    ).photos;
    final identities = sourcePhotos
        .map((p) => '${p.localName}|${p.checksum}')
        .toSet();
    await tester.runAsync(() async {
      final checker = PhotoSuitability(
        Directory('${source.directory.parent.path}/photo-suitability'),
      );
      for (final p in sourcePhotos) {
        await checker.continueWith(
          p,
          await SupportedSuitability().assess(source.file(p.localName), p),
        );
      }
      await home.onConfirmedRecorded!(row, identities);
    });
    final confirmed = (await tester.runAsync(
      () => runtime.reviews.sessions(),
    ))!.single;
    expect(confirmed.ready, true);
    expect(confirmed.currentInitialObservation, isNotNull);
    expect(confirmed.preparedInput, isNotNull);
    final firstObservation = jsonEncode(confirmed.initialObservations);
    await tester.runAsync(() => home.onConfirmedRecorded!(row, identities));
    final retried = (await tester.runAsync(
      () => runtime.reviews.sessions(),
    ))!.single;
    expect(jsonEncode(retried.initialObservations), firstObservation);
    expect(retried.observationHistory, 'unknown');

    // Finishing an app-wide overlay must re-enable the route's system back.
    final scope = find
        .descendant(
          of: find.byType(AiFortunePage),
          matching: find.byWidgetPredicate((w) => w is PopScope),
        )
        .first;
    runtime.preparation.begin(
      photos: sourcePhotos,
      imageFor: (_) => MemoryImage(testImage()),
      onCancel: () {},
    );
    await tester.pump();
    expect(tester.widget<PopScope>(scope).canPop, isFalse);
    runtime.preparation.finish();
    await tester.pumpAndSettle();
    expect(tester.widget<PopScope>(scope).canPop, isTrue);
    await tester.binding.handlePopRoute();
    await settleIo();
    expect(find.byType(AiFortunePage), findsNothing);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'A/B uses same input, hides model identity until vote, survives reopening',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory temp;
      late AiRuntime runtime;
      late ReviewSession session;
      late _Client client;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('atlas-ai-widget-');
        final source = DraftStore(Directory('${temp.path}/source'));
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
        final photos = <ReviewPhoto>[];
        for (var i = 0; i < 3; i++) {
          final p = await runtime.reviews.importPhoto(
            testImage(),
            surface: ReviewSurface.cup,
          );
          photos.add(
            p.update(
              confirmedAt: '2026-09-17T10:00:00Z',
              photo: p.photo.annotated([
                RegionAnnotation(
                  id: 'region-$i',
                  box: RegionBox(.2, .2, .15, .15),
                  label: 'bird',
                ),
              ], PhotoDecision.marked),
            ),
          );
        }
        final checker = PhotoSuitability(
          Directory('${source.directory.parent.path}/photo-suitability'),
        );
        for (final p in photos) {
          await checker.continueWith(
            p.photo,
            await SupportedSuitability().assess(
              runtime.reviews.file(p.photo.localName),
              p.photo,
            ),
          );
        }
        session = ReviewSession(
          id: 'widget-review',
          groupId: 'widget-group',
          createdAtUtc: '2026-09-17T10:00:00Z',
          localConsentAtUtc: '2026-09-17T10:00:00Z',
          sameSampleDeclared: true,
          photos: photos,
        );
        await runtime.reviews.save(session);
        final c = ReviewController(
          store: runtime.reviews,
          session: session,
          loadEngine: () async => fakeEngine(),
        );
        await c.analyze();
        session = c.session;
        c.dispose();
        for (final id in ['one', 'two']) {
          await runtime.store.saveProfile(
            AiProfile(
              id: id,
              name: id,
              url: 'https://$id.example/v1',
              model: id,
              provider: AiProvider.direct,
            ),
          );
        }
      });
      addTearDown(() async {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await temp.delete(recursive: true);
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: AiFortunePage(runtime: runtime, session: session),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('İki AI’yı kör karşılaştır'),
        250,
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButton<String>).last);
      await tester.tap(find.byType(DropdownButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('two · two').last);
      await tester.pumpAndSettle();
      // A manual usability tick must not bypass system preflight, even in lab/A-B.
      final checkedPhoto = session.photos.first.photo;
      final checker = PhotoSuitability(
        Directory(
          '${runtime.bridge.source.directory.parent.path}/photo-suitability',
        ),
      );
      await tester.runAsync(() async {
        final value = await SupportedSuitability().assess(
          runtime.reviews.file(checkedPhoto.localName),
          checkedPhoto,
        );
        await checker.continueWith(checkedPhoto, {
          ...value,
          'status': 'unsuitable',
          'experimental': false,
        });
      });
      await tester.ensureVisible(find.text('A/B fal oluştur'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('A/B fal oluştur')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      expect(client.inputs, isEmpty);
      await tester.scrollUntilVisible(
        find.textContaining('Bu karede fincanının hikâyesine ulaşamadık'),
        -400,
      );
      expect(
        find.textContaining('Bu karede fincanının hikâyesine ulaşamadık'),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await checker.continueWith(
          checkedPhoto,
          await SupportedSuitability().assess(
            runtime.reviews.file(checkedPhoto.localName),
            checkedPhoto,
          ),
        );
      });
      await tester.ensureVisible(find.text('A/B fal oluştur'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('A/B fal oluştur')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      expect(client.inputs, hasLength(2));
      expect(client.inputs[0], client.inputs[1]);
      final finished = await tester.runAsync(
        () => runtime.store.results(session.id),
      );
      expect(finished!.single['state'], 'completed');
      // Drag in ListView padding, not the nested SelectableText scroll areas.
      for (var i = 0; i < 40 && find.text('A').evaluate().isEmpty; i++) {
        await tester.dragFrom(const Offset(8, 600), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('A'));
      expect(find.textContaining('hidden-'), findsNothing);
      await tester.runAsync(() => tester.tap(find.text('A')));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      final details = find.text('Model ve teknik bilgiler').last;
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.textContaining('hidden-'), findsWidgets);
      final saved = await tester.runAsync(
        () => runtime.store.results(session.id),
      );
      expect(saved!.single['vote'], 'A');
      final exposures = await tester.runAsync(
        () => runtime.reviews.knownGroupExposures(session),
      );
      expect(exposures, contains(containsPair('kind', 'aiNarrative')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => runtime.store.read());
      runtime = (await tester.runAsync(
        () => AiRuntime.create(
          DraftStore(Directory('${temp.path}/source')),
          client: client,
          readKey: (_) async => '',
        ),
      ))!;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: AiFortunePage(runtime: runtime, session: session),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      for (
        var i = 0;
        i < 40 && find.text('Tercihin: A').evaluate().isEmpty;
        i++
      ) {
        await tester.dragFrom(const Offset(8, 600), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(
        find.text('Tercihin: A'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      final reopened = await tester.runAsync(
        () => runtime.store.results(session.id),
      );
      expect(reopened!.single['answers'], saved.single['answers']);
      expect(client.inputs, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
