import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_capture_evidence.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DraftStore store;
  late File original;
  late PhotoCaptureEvidence evidence;
  final time = DateTime.utc(2026, 10, 22, 12);

  CameraCaptureResult capture({
    CameraCaptureMode mode = CameraCaptureMode.automatic,
    bool detected = true,
    bool strict = false,
  }) => CameraCaptureResult(
    filePath: original.path,
    widthPixels: 160,
    heightPixels: 200,
    fileSizeBytes: original.lengthSync(),
    capturedAt: time,
    qualityScore: 85,
    coffeePresenceScore: .9,
    coffeeDetected: detected,
    requiresStrictPhotoVerification: strict,
    mode: mode,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-capture-evidence-');
    store = DraftStore(Directory('${root.path}/photos'));
    await store.initialize();
    original = await File(
      '${root.path}/original.png',
    ).writeAsBytes(testImage());
    evidence = PhotoCaptureEvidence(Directory('${root.path}/evidence'));
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'automatic positive evidence survives review rename but not crop or content change',
    () async {
      final result = capture();
      final p = (await store.importCapture(
        CaptureRole.free,
        result,
      )).asSetPhoto();
      await evidence.record(p, result);
      expect(await PhotoCaptureEvidence(evidence.directory).supports(p), true);
      final renamed = ContributionPhoto.fromJson({
        ...p.toJson(),
        'localName': 'linked-review.jpg',
      });
      expect(await evidence.supports(renamed), true);
      final changed = ContributionPhoto.fromJson({
        ...p.toJson(),
        'checksum': 'sha256:${'0' * 64}',
      });
      expect(await evidence.supports(changed), false);
      final cropped = ContributionPhoto.fromJson({
        ...p.toJson(),
        'displayCrop': PhotoCrop(.1, .1, .8, .8).toJson(),
      });
      expect(await evidence.supports(cropped), false);
    },
  );

  for (final mode in CameraCaptureMode.values) {
    test(
      'capture evidence mode=$mode does not invent an absent scan',
      () async {
        final result = capture(mode: mode, detected: false);
        final p = await store.importCapture(CaptureRole.free, result);
        await evidence.record(p, result);
        expect(await evidence.supports(p), false);
      },
    );
  }

  test('dense fallback capture is saved without supporting evidence', () async {
    final result = capture(strict: true);
    final p = await store.importCapture(CaptureRole.free, result);
    await evidence.record(p, result);
    expect(await evidence.supports(p), false);
    expect(await store.file(p.localName).exists(), true);
  });

  test(
    'dense auto scan cannot promote an uncertain photo or override a negative',
    () async {
      final result = capture(strict: true);
      final p = await store.importCapture(CaptureRole.free, result);
      final checker = PhotoSuitability(Directory('${root.path}/checks'));
      await checker.recordCaptureEvidence(p, result);
      final low = localImageScreenRejectBelow - 1;
      final high = localImageScreenSupportAbove + 1;
      final middle =
          (localImageScreenRejectBelow + localImageScreenSupportAbove) / 2;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          PhotoSuitability.imageScreenChannel,
          null,
        ),
      );
      for (final entry in [
        ([high, middle], 'uncertain'),
        ([middle, high], 'uncertain'),
        ([low, high], 'uncertain'),
        ([high, low], 'uncertain'),
        ([low, low], 'unsuitable'),
        ([double.nan, high], 'error'),
        ([high, high], 'supported'),
      ]) {
        messenger.setMockMethodCallHandler(
          PhotoSuitability.imageScreenChannel,
          (_) async => {
            'modelSha256': localImageScreenModelSha256,
            'scores': entry.$1,
          },
        );
        final decision = await checker.assess(
          store.file(p.localName),
          p,
          retry: true,
        );
        expect(decision['status'], entry.$2);
        expect(suitabilityAccepted(decision, p), entry.$2 == 'supported');
      }
    },
    skip: !localImageScreenEnabled,
  );

  test(
    'manual scan, gallery, saucer, and mismatched original cannot provide evidence',
    () async {
      final manual = capture(mode: CameraCaptureMode.manual);
      final p = (await store.importCapture(
        CaptureRole.free,
        manual,
      )).asSetPhoto();
      await evidence.record(p, manual);
      expect(await evidence.supports(p), false);
      final gallery = (await store.importGallery(testImage())).asSetPhoto();
      await evidence.record(gallery, capture());
      expect(await evidence.supports(gallery), false);
      final saucer = p.asSetPhoto(type: PhotoSurface.saucer);
      await evidence.record(saucer, capture());
      expect(await evidence.supports(saucer), false);
      await original.writeAsBytes(Uint8List.fromList([1, 2, 3]));
      await evidence.record(p, capture());
      expect(await evidence.supports(p), false);
    },
  );

  test(
    'optional evidence write failure leaves imported photo usable',
    () async {
      final result = capture();
      final p = await store.importCapture(CaptureRole.free, result);
      await File('${root.path}/blocked').writeAsString('not a directory');
      final unavailable = PhotoCaptureEvidence(
        Directory('${root.path}/blocked/evidence'),
      );
      await unavailable.record(p, result);
      expect(await unavailable.supports(p), false);
      expect(await store.file(p.localName).exists(), true);
    },
  );

  test(
    'evidence loss invalidates cached support; changed bytes invalidate any cached decision',
    () async {
      final result = capture();
      final p = await store.importCapture(CaptureRole.free, result);
      final checker = PhotoSuitability(Directory('${root.path}/checks'));
      await checker.recordCaptureEvidence(p, result);
      var calls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(PhotoSuitability.imageScreenChannel, (
        _,
      ) async {
        calls++;
        return {
          'modelSha256': localImageScreenModelSha256,
          'scores': [
            (localImageScreenRejectBelow + localImageScreenSupportAbove) / 2,
            localImageScreenSupportAbove + 1,
          ],
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          PhotoSuitability.imageScreenChannel,
          null,
        ),
      );
      final accepted = await checker.assess(store.file(p.localName), p);
      expect(accepted['status'], 'supported');
      expect(suitabilityAccepted(accepted, p), true);
      final dir = Directory('${checker.directory.path}/capture-evidence');
      for (final f in dir.listSync().whereType<File>()) {
        await f.delete();
      }
      final held = await checker.assess(store.file(p.localName), p);
      expect(held['status'], 'uncertain');
      expect(suitabilityAccepted(held, p), false);
      expect(calls, 2);
      await store.file(p.localName).writeAsBytes(Uint8List.fromList([1]));
      final mismatch = await checker.assess(store.file(p.localName), p);
      expect(mismatch['status'], 'error');
      expect(calls, 2);
    },
    skip: !localImageScreenEnabled,
  );
}
