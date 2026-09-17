import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_capture_settings.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_camera/src/quality/quality_checker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'mvp_review_test.dart' show fakeEngine, review, timestamp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new sequence is free/right/left; old top occupies first slot', () {
    expect(reviewCaptureRoles, [
      CaptureRole.free,
      CaptureRole.handleRight,
      CaptureRole.handleLeft,
    ]);
    expect(nextReviewCaptureRole([]), CaptureRole.free);
    expect(nextReviewCaptureRole([CaptureRole.free]), CaptureRole.handleRight);
    expect(nextReviewCaptureRole([CaptureRole.top]), CaptureRole.handleRight);
    expect(
      nextReviewCaptureRole([CaptureRole.free, CaptureRole.handleRight]),
      CaptureRole.handleLeft,
    );
    expect(CaptureRole.top.title, 'Üst açı');
    expect(CaptureRole.free.title, 'Serbest açı');
    expect(
      () => testDraft(photos: [testPhoto(CaptureRole.free)]),
      throwsArgumentError,
    );
  });

  test('free angle config keeps physical checks and selects one handle', () {
    final free = reviewCameraConfig(CaptureRole.free);
    final right = reviewCameraConfig(CaptureRole.handleRight);
    final left = reviewCameraConfig(CaptureRole.handleLeft);
    expect(free.handleGuide, CameraHandleGuide.none);
    expect(right.handleGuide, CameraHandleGuide.right);
    expect(left.handleGuide, CameraHandleGuide.left);
    expect(free.backgroundBlurSigma, greaterThan(0));
    expect(
      free.thresholds.minimumBrightness,
      right.thresholds.minimumBrightness,
    );
    expect(free.thresholds.minimumSharpness, right.thresholds.minimumSharpness);
    expect(free.strings.holdOverCup, isNot(contains('yukarıdan')));
    expect(
      reviewCaptureInstruction(CaptureRole.free),
      'Fincanı sabit tut, kamerayı hareket ettir.',
    );
    final input = FrameAnalysisResult.initial().copyWith(
      brightness: .8,
      sharpness: .8,
      angleDegrees: 55,
      isStable: true,
    );
    const quality = QualityChecker();
    final freeAssessment = quality.assess(
      result: input,
      viewportSize: const Size(400, 800),
      config: free,
    );
    final topAssessment = quality.assess(
      result: input,
      viewportSize: const Size(400, 800),
      config: reviewCameraConfig(CaptureRole.top),
    );
    expect(freeAssessment.angleOk, true);
    expect(topAssessment.angleOk, false);
    expect(
      freeAssessment.autoCaptureReady,
      false,
    ); // Angle alone cannot authorize capture.
  });

  test('v2 top documents round trip and upgrade only upon next revision', () {
    final photo = ReviewPhoto(
      id: 'old-photo',
      photo: testPhoto(CaptureRole.top),
      surface: ReviewSurface.cup,
      declaredRole: CaptureRole.top,
    );
    final old = ReviewSession(
      id: 'old',
      groupId: 'group',
      createdAtUtc: timestamp,
      localConsentAtUtc: timestamp,
      recordVersion: observationReviewVersion,
      photos: [photo],
    );
    final encoded = jsonEncode(old.toJson());
    final restored = ReviewSession.fromJson(jsonDecode(encoded));
    expect(jsonEncode(restored.toJson()), encoded);
    expect(restored.photos.single.displayCrop, isNull);
    expect(restored.photos.single.title, 'Üst açı');
    expect(restored.next().recordVersion, reviewVersion);
  });

  test(
    'real crop import survives analysis edits reopen and consented ZIP',
    () async {
      final temp = await Directory.systemTemp.createTemp('atlas-focus-review-');
      addTearDown(() => temp.delete(recursive: true));
      final store = ReviewStore(temp);
      final bytes = testImage();
      final capture = CameraCaptureResult(
        filePath: 'test-source.png',
        croppedCupPath: 'test-crop.png',
        cropRect: const Rect.fromLTWH(32, 40, 80, 100),
        widthPixels: 160,
        heightPixels: 200,
        fileSizeBytes: bytes.length,
        croppedWidthPixels: 80,
        croppedHeightPixels: 100,
        capturedAt: DateTime.parse(timestamp),
        qualityScore: 95,
        coffeePresenceScore: .6,
        mode: CameraCaptureMode.manual,
      );
      final imported = await store.importPhoto(
        bytes,
        surface: ReviewSurface.cup,
        declaredRole: CaptureRole.free,
        capture: capture,
      );
      expect(
        imported.displayCrop!.toJson(),
        PhotoCrop(.2, .2, .5, .5).toJson(),
      );
      final originalBytes = await store.readPhoto(imported);
      final canonicalBox = RegionBox(.3, .35, .075, .075);
      var p = imported.update(
        confirmedAt: timestamp,
        photo: imported.photo.annotated([
          RegionAnnotation(id: 'user-bird', label: 'bird', box: canonicalBox),
        ], PhotoDecision.marked),
      );
      var session = review(photos: [p], consent: true);
      await store.save(session);
      final controller = ReviewController(
        store: store,
        session: session,
        loadEngine: () async => fakeEngine(),
      );
      addTearDown(controller.dispose);
      await controller.analyze();
      session = (await ReviewStore(temp).sessions()).single;
      final snapshot = jsonEncode(session.initialObservations);
      final first =
          (session.currentInitialObservation!['photos'] as List).single as Map;
      expect(first['declaredRole'], 'free');
      expect(first['displayCrop'], p.displayCrop!.toJson());
      expect(
        first['observationCoordinateSpace'],
        'orientedFullPhotoNormalized',
      );
      expect((first['regions'] as List).single['box'], canonicalBox.toJson());
      final payload = session.preparedInput!['payload'] as Map;
      expect(payload['photos'][0]['declaredRole'], 'free');
      expect(
        payload['photos'][0]['userObservations'][0]['box'],
        canonicalBox.toJson(),
      );
      expect(jsonEncode(payload), isNot(contains('displayCrop')));
      expect(jsonEncode(payload), isNot(contains(p.photo.localName)));
      expect(await store.readPhoto(session.photos.single), originalBytes);

      p = session.photos.single;
      final altered = p.toJson()
        ..['displayCrop'] = PhotoCrop(.1, .1, .8, .8).toJson();
      await expectLater(
        store.save(session.withPhoto(ReviewPhoto.fromJson(altered))),
        throwsStateError,
      );
      await controller.save(
        session.withPhoto(
          p.update(
            photo: p.photo.annotated([
              RegionAnnotation(
                id: 'user-bird',
                label: 'tree',
                box: canonicalBox,
              ),
            ], PhotoDecision.marked),
          ),
        ),
      );
      expect(controller.session.preparedInput, isNull);
      await controller.analyze();
      session = controller.session;
      expect(jsonEncode(session.initialObservations), snapshot);

      const channel = MethodChannel('test.focus.export');
      Uint8List? zipBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            zipBytes = await File(
              (call.arguments as Map)['sourcePath'] as String,
            ).readAsBytes();
            return 'test-download';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await store.exportToDownloads(channel: channel);
      final archive = ZipDecoder().decodeBytes(zipBytes!);
      final record = jsonDecode(
        utf8.decode(
          archive.findFile('reviews/${session.id}/record.json')!.content,
        ),
      );
      expect(
        record['photos'][0]['displayCrop'],
        imported.displayCrop!.toJson(),
      );
      expect(
        archive.findFile('reviews/${session.id}/${p.id}.jpg')!.content,
        originalBytes,
      );
      await controller.save(session.next(researchAllowed: false));
      await expectLater(
        store.exportToDownloads(channel: channel),
        throwsStateError,
      );
      expect(
        jsonEncode((await store.sessions()).single.initialObservations),
        snapshot,
      );
      await controller.close();
    },
  );
}
