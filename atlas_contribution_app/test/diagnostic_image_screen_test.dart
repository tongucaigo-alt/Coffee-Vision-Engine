import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cup validation does not enable legacy saucer rejection', () async {
    final root = await Directory.systemTemp.createTemp('atlas-saucer-test-');
    addTearDown(() => root.delete(recursive: true));
    final bytes = testImage();
    final file = await File('${root.path}/photo.png').writeAsBytes(bytes);
    final photo = ContributionPhoto(
      role: CaptureRole.free,
      surface: PhotoSurface.saucer,
      localName: 'photo.png',
      checksum: 'sha256:${sha256.convert(bytes)}',
      originalChecksum: 'sha256:${sha256.convert(bytes)}',
      width: 160,
      height: 200,
      byteLength: bytes.length,
      capturedAt: '2026-10-03T00:00:00Z',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      PhotoSuitability.channel,
      (_) async => {
        'full': [
          {'label': 'computer keyboard', 'score': .99},
        ],
        'crop': [
          {'label': 'computer keyboard', 'score': .99},
        ],
      },
    );
    messenger.setMockMethodCallHandler(PhotoSuitability.imageScreenChannel, (
      _,
    ) async {
      fail('Cup model must not assess a saucer');
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(PhotoSuitability.channel, null);
      messenger.setMockMethodCallHandler(
        PhotoSuitability.imageScreenChannel,
        null,
      );
    });
    final result = await PhotoSuitability(
      Directory('${root.path}/cache'),
    ).assess(file, photo);
    expect(result['candidateStatus'], 'unsuitable');
    expect(result['status'], 'uncertain');
    expect(result['experimental'], true);
    expect(suitabilityAccepted(result, photo), true);
  });
  test(
    'two-view decision table and automatic evidence never override a negative',
    () {
      Map<String, dynamic> response(Object scores) => {
        'scores': scores,
        'modelSha256': localImageScreenModelSha256,
      };
      final low = localImageScreenRejectBelow - 1;
      final high = localImageScreenSupportAbove + 1;
      final middle =
          (localImageScreenRejectBelow + localImageScreenSupportAbove) / 2;
      for (final automatic in [false, true]) {
        for (final entry in [
          ([low, low], 'unsuitable'),
          ([low, high], 'uncertain'),
          ([high, low], 'uncertain'),
          ([low, middle], 'uncertain'),
          ([middle, low], 'uncertain'),
          ([middle, middle], 'uncertain'),
          ([high, high], 'supported'),
          ([middle, high], automatic ? 'supported' : 'uncertain'),
          ([high, middle], automatic ? 'supported' : 'uncertain'),
        ]) {
          expect(
            classifyLocalImageScreen(
              response(entry.$1),
              automaticEvidence: automatic,
            ),
            entry.$2,
          );
        }
      }
      for (final scores in [
        [],
        [.2],
        [.2, .3, .4],
        ['.2', .3],
        [double.infinity, .2],
      ]) {
        expect(
          () => classifyLocalImageScreen(response(scores)),
          throwsFormatException,
        );
      }
      expect(() => classifyLocalImageScreen(null), throwsFormatException);
      expect(
        () => classifyLocalImageScreen({
          ...response([high, high]),
          'modelSha256': 'old-model',
        }),
        throwsFormatException,
      );
    },
  );
  for (final status in ['supported', 'uncertain', 'unsuitable', 'invalid']) {
    test(
      'diagnostic $status decision is shared and cached without confirmation',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'atlas-screen-test-',
        );
        addTearDown(() => root.delete(recursive: true));
        final bytes = testImage();
        final file = await File('${root.path}/photo.png').writeAsBytes(bytes);
        final photo = ContributionPhoto(
          role: CaptureRole.free,
          localName: 'photo.png',
          checksum: 'sha256:${sha256.convert(bytes)}',
          originalChecksum: 'sha256:${sha256.convert(bytes)}',
          width: 160,
          height: 200,
          byteLength: bytes.length,
          capturedAt: '2026-10-03T00:00:00Z',
        );
        var calls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PhotoSuitability.imageScreenChannel, (
              call,
            ) async {
              calls++;
              expect(call.method, 'assess');
              return {
                'candidateStatus': status,
                'scores': switch (status) {
                  'supported' => [
                    localImageScreenSupportAbove + 1,
                    localImageScreenSupportAbove + 1,
                  ],
                  'uncertain' => [
                    localImageScreenRejectBelow,
                    localImageScreenSupportAbove,
                  ],
                  'unsuitable' => [
                    localImageScreenRejectBelow - 1,
                    localImageScreenRejectBelow - 1,
                  ],
                  _ => [double.nan, 0.3],
                },
                'modelSha256': localImageScreenModelSha256,
              };
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                PhotoSuitability.imageScreenChannel,
                null,
              ),
        );
        final checker = PhotoSuitability(Directory('${root.path}/cache'));
        final simultaneous = await Future.wait([
          checker.assess(file, photo),
          PhotoSuitability(checker.directory).assess(file, photo),
        ]);
        final first = simultaneous.first;
        expect(simultaneous.last, first);
        expect(first['status'], status == 'invalid' ? 'error' : status);
        expect(suitabilityAccepted(first, photo), status == 'supported');
        final cached = await checker.assess(file, photo);
        expect(cached['checkedAtUtc'], first['checkedAtUtc']);
        expect(calls, status == 'invalid' ? 2 : 1);
        expect(first['continuedAtUtc'], isNull);
        if (status != 'invalid') {
          expect(first['diagnosticOnly'], diagnosticImageScreen);
        }
      },
      skip: !localImageScreenEnabled,
    );
  }
  test(
    'old cache and changed crop are recomputed without deleting records',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'atlas-cache-version-',
      );
      addTearDown(() => root.delete(recursive: true));
      final bytes = testImage();
      final file = await File('${root.path}/photo.png').writeAsBytes(bytes);
      final p = ContributionPhoto(
        role: CaptureRole.free,
        localName: 'photo.png',
        checksum: 'sha256:${sha256.convert(bytes)}',
        originalChecksum: 'sha256:${sha256.convert(bytes)}',
        width: 160,
        height: 200,
        byteLength: bytes.length,
        capturedAt: '2026-10-03T00:00:00Z',
      );
      final checker = PhotoSuitability(Directory('${root.path}/cache'));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var calls = 0;
      messenger.setMockMethodCallHandler(PhotoSuitability.imageScreenChannel, (
        _,
      ) async {
        calls++;
        return {
          'modelSha256': localImageScreenModelSha256,
          'scores': [0.0, 0.0],
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          PhotoSuitability.imageScreenChannel,
          null,
        ),
      );
      final current = await checker.assess(file, p);
      await checker.continueWith(p, {
        ...current,
        'version': 'old-model',
        'status': 'supported',
      });
      expect((await checker.assess(file, p))['status'], 'uncertain');
      await checker.continueWith(p, {
        ...current,
        'cropKey': 'different-crop',
        'status': 'supported',
      });
      expect((await checker.assess(file, p))['status'], 'uncertain');
      expect(calls, 3);
      expect(await file.exists(), true);
    },
    skip: !localImageScreenEnabled,
  );
}
