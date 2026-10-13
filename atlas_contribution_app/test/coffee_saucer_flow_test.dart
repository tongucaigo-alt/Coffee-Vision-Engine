import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/annotation_sequence.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;
import 'suitability_fixture.dart';

class _Store extends MemoryStore {
  _Store(super.directory, super.draft);
  @override
  Future<void> collectOrphans() async {}
  int saves = 0;
  bool failNext = false;
  @override
  Future<void> save(ContributionDraft d) async {
    saves++;
    if (failNext) {
      failNext = false;
      throw StateError('Synthetic save failure');
    }
    await super.save(d);
  }

  @override
  Future<void> releaseCapture(CameraCaptureResult capture) async {}
}

class _Picker implements GalleryPicker {
  final responses = <Object?>[];
  int calls = 0;
  @override
  Future<Uint8List?> pick() async {
    calls++;
    final response = responses.isEmpty ? null : responses.removeAt(0);
    if (response is Exception || response is Error) throw response!;
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
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  late Directory root;
  late _Store store;
  late _Picker picker;
  late PausedService service;
  final cameraResponses = <Object?>[];
  var cameraCalls = 0;
  Future<void> mount(
    WidgetTester tester, {
    bool gallery = true,
    int cups = 1,
    bool cupDone = false,
    bool saucerDone = false,
    bool queued = false,
  }) async {
    tester.view.physicalSize = const Size(412, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('atlas-v62-saucer-');
      store = _Store(root, setDraft(gallery: gallery));
      var draft = store.draft!;
      for (var i = 0; i < cups; i++) {
        final imported = await store.importGallery(setImage(i));
        draft = draft.withPhoto(
          imported.asSetPhoto(
            photoId: 'cup-$i',
            angle: gallery ? null : freeCaptureRoles[i],
          ),
        );
      }
      store.draft = draft.copy(
        cupSelectionDone: cupDone,
        saucerDecided: saucerDone,
        queued: queued,
      );
      store.rows.add({'id': 'existing-record'});
    });
    picker = _Picker();
    service = PausedService(store);
    cameraCalls = 0;
    cameraResponses.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: atlasTheme(),
        home: ContributionHome(
          modern: true,
          store: store,
          service: service,
          photoSuitability: SupportedSuitability(),
          galleryPicker: picker,
          cameraLauncher:
              (
                _, {
                required config,
                required captureTitle,
                required captureInstruction,
                onFinishSequence,
              }) async => null,
          saucerLauncher: (_) async {
            cameraCalls++;
            final response = cameraResponses.isEmpty
                ? null
                : cameraResponses.removeAt(0);
            if (response is Exception || response is Error) throw response!;
            return response as CameraCaptureResult?;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        FileImage(store.file(store.draft!.photos.first.localName)),
        tester.element(find.byType(ContributionHome)),
      ),
    );
    await tester.tap(find.byTooltip('Kaldığın Yerden Devam Et'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await root.delete(recursive: true);
      });
    });
  }

  Future<CameraCaptureResult> capture(int id) async {
    late CameraCaptureResult result;
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bytes = setImage(id);
      final file = File('${root.path}/capture-$id.png');
      await file.writeAsBytes(bytes);
      result = CameraCaptureResult(
        filePath: file.path,
        croppedCupPath: file.path,
        cropRect: const Rect.fromLTWH(0, 0, 160, 200),
        widthPixels: 160,
        heightPixels: 200,
        fileSizeBytes: bytes.length,
        croppedWidthPixels: 160,
        croppedHeightPixels: 200,
        croppedFileSizeBytes: bytes.length,
        capturedAt: DateTime.now().toUtc(),
        qualityScore: 80,
        coffeePresenceScore: .8,
        coffeeDetected: true,
        mode: CameraCaptureMode.manual,
      );
    });
    return result;
  }

  Future<void> choose(
    WidgetTester tester,
    String source, {
    bool replace = false,
  }) async {
    await tester.tap(
      replace ? find.text('Değiştir') : find.byTooltip('Tabak fotoğrafı ekle'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(source));
    await _drain(tester);
  }

  for (final gallery in [true, false]) {
    for (final flags in [(false, false), (true, false), (true, true)]) {
      testWidgets(
        'old draft opens without writes: gallery=$gallery flags=$flags',
        (tester) async {
          await mount(
            tester,
            gallery: gallery,
            cups: gallery ? 1 : 3,
            cupDone: flags.$1,
            saucerDone: flags.$2,
          );
          final before = store.draft!.toJson();
          expect(store.saves, 0);
          expect(find.text('Tabaksız devam et'), findsNothing);
          await tester.tap(find.byTooltip('Tabak fotoğrafı ekle'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Vazgeç'));
          await tester.pumpAndSettle();
          expect(store.draft!.toJson(), before);
          expect(store.saves, 0);
        },
      );
    }
  }
  for (final source in ['Kamera', 'Galeri']) {
    testWidgets(
      '$source adds, replaces and removes one saucer on the same preview',
      (tester) async {
        await mount(tester);
        final cup = store.draft!.cups.single.toJson();
        if (source == 'Kamera') {
          cameraResponses.add(await capture(3));
        } else {
          picker.responses.add(setImage(3));
        }
        await choose(tester, source);
        expect(store.draft!.saucers, hasLength(1));
        final saucer = store.draft!.saucers.single;
        expect(find.text('Fotoğraf 2/2'), findsOneWidget);
        expect(find.text('Tabak ekle'), findsNothing);
        if (source == 'Kamera') {
          cameraResponses.add(await capture(4));
        } else {
          picker.responses.add(setImage(4));
        }
        await choose(tester, source, replace: true);
        expect(store.draft!.saucers.single.id, saucer.id);
        expect(store.draft!.saucers.single.checksum, isNot(saucer.checksum));
        expect(store.draft!.cups.single.toJson(), cup);
        await tester.tap(find.text('Kaldır'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Kaldır'));
        await _drain(tester);
        expect(store.draft!.saucers, isEmpty);
        expect(find.text('Tabak ekle').hitTestable(), findsOneWidget);
        expect(store.rows.single['id'], 'existing-record');
        expect(service.submissions, 0);
        expect(source == 'Kamera' ? cameraCalls : picker.calls, 2);
      },
    );
    testWidgets('$source cancellation and error retain all photos', (
      tester,
    ) async {
      await mount(tester);
      final before = store.draft!.toJson();
      await choose(tester, source);
      expect(store.draft!.toJson(), before);
      if (source == 'Kamera') {
        cameraResponses.add(StateError('camera failed'));
      } else {
        picker.responses.add(const FormatException('import failed'));
      }
      await choose(tester, source);
      expect(store.draft!.toJson(), before);
      if (source == 'Galeri') {
        picker.responses.add(setImage(3));
        await tester.tap(find.text('Yeniden dene'));
        await _drain(tester);
        expect(store.draft!.saucers, hasLength(1));
      }
      expect(store.rows.single['id'], 'existing-record');
    });
  }

  testWidgets('double press opens one picker and imports one saucer', (
    tester,
  ) async {
    await mount(tester);
    final action = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Tabak ekle'))
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final pending = Completer<Uint8List?>();
    picker.responses.add(pending);
    await tester.tap(find.text('Galeri'));
    for (var i = 0; i < 40 && picker.calls == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    action();
    expect(picker.calls, 1);
    pending.complete(setImage(3));
    await _drain(tester);
    expect(store.draft!.saucers, hasLength(1));
  });

  testWidgets(
    'same-cup confirmation and one advance survive save failure and back',
    (tester) async {
      await mount(tester, cups: 3);
      final before = store.draft!.toJson();
      final next = find.widgetWithText(
        FilledButton,
        'Bu fotoğraflarla devam et',
      );
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      expect(find.byType(CheckboxListTile), findsNothing);
      store.failNext = true;
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(store.draft!.toJson(), before);
      expect(find.byType(AnnotationSequence), findsNothing);
      final action = tester.widget<FilledButton>(next).onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(find.byType(AnnotationSequence), findsOneWidget);
      expect(store.saves, 2); // failed write plus one successful retry
      expect(store.draft!.complete, true);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Fotoğraflarına Bak'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.vertical,
        ),
        findsNothing,
      );
      expect(service.submissions, 0);
    },
  );
}
