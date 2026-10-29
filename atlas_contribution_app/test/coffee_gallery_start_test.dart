import 'home_action_finder.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;
import 'suitability_fixture.dart';

// This fixture keeps its draft in memory, rather than draft.json.
class _GalleryStore extends MemoryStore {
  _GalleryStore(super.directory, super.draft);
  @override
  Future<void> collectOrphans() async {
    await removeUnreferencedPhotos([?draft]);
  }
}

class _Picker implements GalleryPicker {
  _Picker(this.responses);
  final List<Object?> responses;
  int calls = 0;
  @override
  Future<Uint8List?> pick() async {
    calls++;
    final response = responses.isEmpty ? null : responses.removeAt(0);
    if (response is Exception) throw response;
    if (response is Completer<Uint8List?>) return response.future;
    return response as Uint8List?;
  }

  @override
  Future<Uint8List?> recover() async => null;
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main({Future<void> Function(String)? capture, bool device = false}) {
  setUpAll(() async {
    for (final (name, asset) in [
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
  });
  late Directory root;
  late MemoryStore store;
  late _Picker picker;
  Future<void> mount(
    WidgetTester tester, {
    ContributionDraft? draft,
    double width = 360,
    double scale = 1,
    List<Object?> responses = const [],
  }) async {
    if (!device) {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('atlas-v55-gallery-');
      store = _GalleryStore(root, draft)..accepted = true;
      store.rows.add({'id': 'retained-record'});
      for (final p in draft?.photos ?? <ContributionPhoto>[]) {
        await store.file(p.localName).writeAsBytes(setImage(0));
      }
    });
    picker = _Picker(List.of(responses));
    final service = PausedService(store)..fail = draft?.queued == true;
    await tester.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('coffee-test-surface'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: ContributionHome(
          modern: true,
          tarotPage: const SizedBox(),
          store: store,
          service: service,
          galleryPicker: picker,
          photoSuitability: SupportedSuitability(),
          cameraLauncher:
              (
                _, {
                required config,
                required captureTitle,
                required captureInstruction,
                onFinishSequence,
              }) async => null,
        ),
      ),
    );
    await _drain(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => root.delete(recursive: true));
    });
  }

  for (final width in capture == null ? [360.0, 412.0] : [360.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final source
          in capture == null ? ['none', 'camera', 'gallery'] : ['camera']) {
        testWidgets(
          'empty $source draft opens gallery, cancellation retries: $width / $scale',
          (tester) async {
            await mount(
              tester,
              width: width,
              scale: scale,
              draft: source == 'none'
                  ? null
                  : setDraft(gallery: source == 'gallery'),
            );
            await tester.ensureVisible(homeAction('Galeriden Seç'));
            await tester.tap(homeAction('Galeriden Seç'));
            await _drain(tester);
            expect(picker.calls, 1);
            expect(store.draft!.isGallery, true);
            expect(
              find.text('Henüz fotoğraf eklemedin').hitTestable(),
              findsOneWidget,
            );
            expect(
              find.text('Galeriden fotoğraf seç').hitTestable(),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text('Kameraya geç'));
            expect(find.text('Kameraya geç').hitTestable(), findsOneWidget);
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is Scrollable &&
                    axisDirectionToAxis(w.axisDirection) == Axis.vertical,
              ),
              findsNothing,
            );
            expect(
              find.text('Önce mevcut çalışmanı tamamla veya taslağı sil.'),
              findsNothing,
            );
            if (capture != null) {
              await capture('gallery-empty-${scale.toInt()}');
            }
            await tester.ensureVisible(find.text('Galeriden fotoğraf seç'));
            await tester.tap(find.text('Galeriden fotoğraf seç'));
            await _drain(tester);
            expect(picker.calls, 2);
            expect(store.rows.single['id'], 'retained-record');
            await tester.ensureVisible(find.text('Kameraya geç'));
            await tester.tap(find.text('Kameraya geç'));
            await _drain(tester);
            expect(store.draft!.isGallery, false);
            expect(find.text('Galeriden seç').hitTestable(), findsOneWidget);
            await tester.tap(find.text('Galeriden seç'));
            await _drain(tester);
            expect(picker.calls, 3);
            expect(store.draft!.isGallery, true);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final gallery in [false, true]) {
    testWidgets(
      'legacy empty draft switches source without blocking: gallery=$gallery',
      (tester) async {
        final base = setDraft();
        final old = ContributionDraft(
          id: base.id,
          rootId: base.rootId,
          groupId: base.groupId,
          createdAt: base.createdAt,
          consentedAt: base.consentedAt,
          kind: gallery
              ? ContributionKind.gallerySingle
              : ContributionKind.threeAngle,
        );
        await mount(tester, draft: old, scale: 2);
        await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
        await _drain(tester);
        await tester.tap(find.text(gallery ? 'Kameraya geç' : 'Galeriden seç'));
        await _drain(tester);
        expect(store.draft!.isGallery, !gallery);
        expect(picker.calls, gallery ? 0 : 1);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                axisDirectionToAxis(w.axisDirection) == Axis.vertical,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final decision in [
    'Vazgeç',
    'Mevcut çalışmaya devam et',
    'Taslağı sil ve galeriden başlat',
  ]) {
    testWidgets('photo draft gallery decision: $decision', (tester) async {
      late ContributionDraft old;
      await tester.runAsync(() async {
        final importedRoot = await Directory.systemTemp.createTemp(
          'atlas-v55-source-',
        );
        final importStore = MemoryStore(importedRoot, null);
        final p = await importStore.importGallery(setImage(0));
        old = setDraft().withPhoto(p.asSetPhoto());
        await importedRoot.delete(recursive: true);
      });
      await mount(tester, draft: old, responses: [setImage(1)]);
      await tester.tap(homeAction('Galeriden Seç'));
      await tester.pumpAndSettle();
      expect(find.text('Yarım kalan çalışman var'), findsOneWidget);
      // Re-entering the same callback while the choice is open must not stack dialogs.
      final action = tester
          .widget<TextButton>(homeAction('Galeriden Seç'))
          .onPressed!;
      action();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(decision));
      await _drain(tester);
      expect(store.rows.single['id'], 'retained-record');
      if (decision == 'Taslağı sil ve galeriden başlat') {
        expect(picker.calls, 1);
        expect(store.draft!.id, isNot(old.id));
        expect(
          store.draft!.photos.single.checksum,
          isNot(old.photos.single.checksum),
        );
      } else {
        expect(picker.calls, 0);
        expect(store.draft!.toJson(), old.toJson());
        expect(
          find.text('Fotoğraflarına Bak'),
          decision == 'Vazgeç' ? findsNothing : findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('queued draft cannot be replaced from gallery or camera', (
    tester,
  ) async {
    final old = setDraft().copy(queued: true);
    await mount(tester, draft: old);
    await tester.tap(homeAction('Galeriden Seç'));
    await _drain(tester);
    expect(picker.calls, 0);
    expect(store.draft!.toJson(), old.toJson());
    expect(find.text('Çalışman gönderim kuyruğunda.'), findsOneWidget);
    final remove = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Taslağı sil'),
    );
    expect(remove.onPressed, isNull);
    expect(store.rows.single['id'], 'retained-record');
  });

  testWidgets(
    'gallery import failure has a working retry; previous photo remains',
    (tester) async {
      await mount(
        tester,
        responses: [
          const FormatException('Synthetic import failure'),
          setImage(1),
        ],
      );
      await tester.tap(homeAction('Galeriden Seç'));
      await _drain(tester);
      expect(find.text('Yeniden dene').hitTestable(), findsOneWidget);
      expect(store.draft!.photos, isEmpty);
      await tester.tap(find.text('Yeniden dene'));
      await _drain(tester);
      expect(store.draft!.photos, hasLength(1));
      final original = store.draft!.photos.single;
      picker.responses.add(const FormatException('Replacement failed'));
      await tester.tap(find.byTooltip('Fotoğrafı değiştir'));
      await _drain(tester);
      expect(store.draft!.photos.single.toJson(), original.toJson());
      expect(find.text('Yeniden dene').hitTestable(), findsOneWidget);
      if (capture != null) await capture('gallery-retry');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('double gallery start opens one picker and retains one draft', (
    tester,
  ) async {
    final result = Completer<Uint8List?>();
    await mount(tester, responses: [result]);
    final start = tester
        .widget<TextButton>(homeAction('Galeriden Seç'))
        .onPressed!;
    await tester.runAsync(() async {
      start();
      start();
      for (var i = 0; i < 100 && picker.calls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(picker.calls, 1);
    final id = store.draft!.id;
    start();
    result.complete(null);
    await _drain(tester);
    expect(picker.calls, 1);
    expect(store.draft!.id, id);
    expect(store.rows.single['id'], 'retained-record');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('selection cap explains retry without changing draft: $scale', (
      tester,
    ) async {
      const message = 'En fazla 3 fincan fotoğrafı seçebilirsin.';
      await mount(
        tester,
        scale: scale,
        responses: [const GallerySelectionLimit(message), setImage(1)],
      );
      await tester.tap(homeAction('Galeriden Seç'));
      await _drain(tester);
      expect(store.draft!.photos, isEmpty);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Yeniden dene').hitTestable(), findsOneWidget);
      expect(find.text('Fotoğraf eklenemedi.'), findsNothing);
      await tester.tap(find.text('Yeniden dene'));
      await _drain(tester);
      expect(store.draft!.cups, hasLength(1));
      expect(find.text(message), findsNothing);
      expect(store.rows.single['id'], 'retained-record');
      expect(tester.takeException(), isNull);
    });
  }
}
