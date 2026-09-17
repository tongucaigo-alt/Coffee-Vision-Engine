import 'dart:io';

import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/cropped_photo.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'fixtures.dart';
import 'gallery_import_test.dart' show FakeGallery;

// Keep real media import/crop validation, while isolating the widget from
// unrelated draft-file and Android cache-directory transactions.
class _CaptureStore extends DraftStore {
  _CaptureStore(super.directory, [this.current]);
  ContributionDraft? current;
  final released = <CameraCaptureResult>[];
  @override
  Future<ContributionDraft?> load() async => current;
  @override
  Future<void> save(ContributionDraft draft) async => current = draft;
  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<void> collectOrphans() async {}
  @override
  Future<void> releaseCapture(CameraCaptureResult capture) async {
    released.add(capture);
  }
}

class _CameraRequest {
  _CameraRequest(this.config, this.title, this.instruction);
  final CoffeeCameraConfig config;
  final String title, instruction;
}

class _FakeCamera {
  _FakeCamera(this.responses);
  final List<Object?> responses;
  final requests = <_CameraRequest>[];
  Future<CameraCaptureResult?> call(
    BuildContext context, {
    required CoffeeCameraConfig config,
    required String captureTitle,
    required String captureInstruction,
  }) async {
    requests.add(_CameraRequest(config, captureTitle, captureInstruction));
    final response = responses.removeAt(0);
    if (response is Exception) throw response;
    return response as CameraCaptureResult?;
  }
}

Future<CameraCaptureResult> _generatedCapture(
  Directory directory,
  int id,
) async {
  final bytes = testImage();
  final source = File('${directory.path}/generated-camera-$id.png');
  final crop = File('${directory.path}/generated-crop-$id.png');
  final cropBytes = img.encodePng(
    img.copyCrop(img.decodeImage(bytes)!, x: 32, y: 40, width: 80, height: 100),
  );
  await source.writeAsBytes(bytes);
  await crop.writeAsBytes(cropBytes);
  return CameraCaptureResult(
    filePath: source.path,
    croppedCupPath: crop.path,
    cropRect: const Rect.fromLTWH(32, 40, 80, 100),
    widthPixels: 160,
    heightPixels: 200,
    fileSizeBytes: bytes.length,
    croppedWidthPixels: 80,
    croppedHeightPixels: 100,
    croppedFileSizeBytes: cropBytes.length,
    capturedAt: DateTime.now().toUtc(),
    qualityScore: 80,
    coffeePresenceScore: .8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}

ContributionDraft _draft(ContributionKind kind) {
  final base = testDraft();
  return ContributionDraft(
    id: base.id,
    rootId: base.rootId,
    groupId: base.groupId,
    createdAt: base.createdAt,
    consentedAt: base.consentedAt,
    kind: kind,
  );
}

Future<void> _mount(
  WidgetTester tester,
  _CaptureStore store,
  _FakeCamera camera,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: contributionTheme(),
      home: ContributionHome(
        store: store,
        service: OfflineContributionService(store),
        galleryPicker: FakeGallery(),
        cameraLauncher: camera.call,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.text('Kaldığın yerden devam et').evaluate().isNotEmpty) {
    await tester.tap(find.text('Kaldığın yerden devam et'));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapAndWait(
  WidgetTester tester,
  Finder finder,
  bool Function() completed,
) async {
  await tester.ensureVisible(finder);
  await tester.runAsync(() => tester.tap(finder));
  // Route completion needs frames, while file/codec work needs real async I/O.
  // Let both advance instead of waiting in runAsync with a frozen route.
  for (var attempt = 0; attempt < 1500 && !completed(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(completed(), true, reason: 'ContributionHome action did not complete');
  await tester.pumpAndSettle();
  for (var frame = 0; frame < 5; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _removeFixture(Directory directory) async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  // Windows may finish closing a decoded FileImage just after widget disposal.
  for (var attempt = 0; ; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 9) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

void _expectRequest(_CameraRequest request, int step, CameraHandleGuide guide) {
  expect(request.config.backgroundBlurSigma, 5);
  expect(request.config.handleGuide, guide);
  expect(request.title, startsWith('$step / 3'));
  expect(request.instruction, 'Fincanı sabit tut, kamerayı hareket ettir.');
}

void main() {
  testWidgets(
    'new offline consent routes all three captures through focused camera',
    (tester) async {
      late Directory temp;
      late List<CameraCaptureResult> captures;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp(
          'atlas-contribution-flow-',
        );
        captures = [
          for (var i = 0; i < 3; i++) await _generatedCapture(temp, i),
        ];
      });
      addTearDown(() => _removeFixture(temp));
      final store = _CaptureStore(temp);
      final camera = _FakeCamera(captures);
      await _mount(tester, store, camera);
      await tester.ensureVisible(find.text('Fincan çek'));
      await tester.tap(find.text('Fincan çek'));
      await tester.pumpAndSettle();
      expect(camera.requests, isEmpty);
      expect(store.current, isNull);
      final checks = find.byType(CheckboxListTile);
      await tester.ensureVisible(checks.at(0));
      await tester.tap(checks.at(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(checks.at(1));
      await tester.tap(checks.at(1));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checks.at(0)).value, true);
      expect(tester.widget<CheckboxListTile>(checks.at(1)).value, true);
      await _tapAndWait(
        tester,
        find.text('Devam et'),
        () => store.current != null,
      );
      expect(store.current!.kind, ContributionKind.freeThreeAngle);
      const roles = [
        CaptureRole.free,
        CaptureRole.handleRight,
        CaptureRole.handleLeft,
      ];
      const guides = [
        CameraHandleGuide.none,
        CameraHandleGuide.right,
        CameraHandleGuide.left,
      ];
      for (var i = 0; i < 3; i++) {
        await _tapAndWait(
          tester,
          find.text('${roles[i].title} çek'),
          () => store.current!.photos.length == i + 1,
        );
        expect(store.current!.photos.last.role, roles[i]);
        _expectRequest(camera.requests[i], i + 1, guides[i]);
        expect(
          store.current!.photos.last.displayCrop!.toJson(),
          PhotoCrop(.2, .2, .5, .5).toJson(),
        );
      }
      expect(
        camera.requests.first.title,
        contains('Telvenin en yoğun olduğu bölgeyi göster'),
      );
      expect(store.current!.complete, true);
      expect(store.released, hasLength(3));
      expect(find.text('Üst açı'), findsNothing);
      final previewCrops = tester.widgetList<CroppedPhoto>(
        find.byType(CroppedPhoto),
      );
      expect(previewCrops, hasLength(3));
      expect(
        previewCrops.every(
          (p) =>
              p.crop!.toJson().toString() ==
              PhotoCrop(.2, .2, .5, .5).toJson().toString(),
        ),
        true,
      );

      // Open the actual saved first photo through Home's annotation action.
      final firstCard = find.ancestor(
        of: find.text(CaptureRole.free.title),
        matching: find.byType(Card),
      );
      final annotate = find.descendant(
        of: firstCard,
        matching: find.text('Şekil işaretle'),
      );
      await tester.ensureVisible(annotate);
      await tester.tap(annotate);
      await tester.pumpAndSettle();
      final page = tester.widget<AnnotationPage>(find.byType(AnnotationPage));
      expect(page.displayCrop!.toJson(), PhotoCrop(.2, .2, .5, .5).toJson());
      expect(page.photo.role, CaptureRole.free);
      expect(
        tester.widget<CroppedPhoto>(find.byType(CroppedPhoto)).crop!.toJson(),
        page.displayCrop!.toJson(),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancel and camera failure keep step; retake preserves following photos',
    (tester) async {
      late Directory temp;
      late List<CameraCaptureResult> captures;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp(
          'atlas-contribution-retry-',
        );
        captures = [
          for (var i = 0; i < 3; i++) await _generatedCapture(temp, i),
        ];
      });
      addTearDown(() => _removeFixture(temp));
      final store = _CaptureStore(
        temp,
        _draft(ContributionKind.freeThreeAngle),
      );
      final camera = _FakeCamera([
        null,
        captures[0],
        Exception('synthetic cancellation failure'),
        captures[1],
        captures[2],
      ]);
      await _mount(tester, store, camera);
      await _tapAndWait(
        tester,
        find.text('Serbest açı çek'),
        () => camera.requests.length == 1,
      );
      expect(store.current!.photos, isEmpty);
      expect(find.text('Serbest açı çek'), findsOneWidget);
      await _tapAndWait(
        tester,
        find.text('Serbest açı çek'),
        () => store.current!.photos.length == 1,
      );
      final free = store.current!.photos.single;
      await _tapAndWait(
        tester,
        find.text('Kulp sağda çek'),
        () => camera.requests.length == 3,
      );
      expect(store.current!.photos.single, same(free));
      expect(find.text('Kulp sağda çek'), findsOneWidget);
      await _tapAndWait(
        tester,
        find.text('Kulp sağda çek'),
        () => store.current!.photos.length == 2,
      );
      final right = store.current!.photos.last;
      await _tapAndWait(
        tester,
        find.byTooltip('Serbest açı yeniden çek'),
        () => store.current!.photos.first.localName != free.localName,
      );
      expect(store.current!.photos, hasLength(2));
      expect(store.current!.photos.last, same(right));
      expect(store.current!.photos.first.role, CaptureRole.free);
      expect(camera.requests.map((r) => r.title.split(' / ').first), [
        '1',
        '1',
        '2',
        '2',
        '1',
      ]);
      expect(find.text('Kulp solda çek'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('resuming legacy three-angle draft keeps top and its next role', (
    tester,
  ) async {
    late Directory temp;
    late CameraCaptureResult capture;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp(
        'atlas-contribution-legacy-',
      );
      capture = await _generatedCapture(temp, 0);
      await File('${temp.path}/top.jpg').writeAsBytes(testImage());
    });
    addTearDown(() => _removeFixture(temp));
    final top = testPhoto(CaptureRole.top);
    final store = _CaptureStore(temp, testDraft(photos: [top]));
    final camera = _FakeCamera([capture, null]);
    await _mount(tester, store, camera);
    expect(find.text('Üst açı'), findsOneWidget);
    expect(find.text('Serbest açı çek'), findsNothing);
    await _tapAndWait(
      tester,
      find.text('Kulp sağda çek'),
      () => store.current!.photos.length == 2,
    );
    expect(store.current!.kind, ContributionKind.threeAngle);
    expect(store.current!.photos.first, same(top));
    expect(store.current!.photos.map((p) => p.role), [
      CaptureRole.top,
      CaptureRole.handleRight,
    ]);
    _expectRequest(camera.requests.single, 2, CameraHandleGuide.right);
    await _tapAndWait(
      tester,
      find.byTooltip('Üst açı yeniden çek'),
      () => camera.requests.length == 2,
    );
    expect(camera.requests.last.title, '1 / 3 · Üst açı');
    expect(store.current!.photos.first, same(top));
    expect(find.text('Kulp solda çek'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
