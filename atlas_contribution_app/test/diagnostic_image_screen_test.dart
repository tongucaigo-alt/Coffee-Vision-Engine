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
  test('positive evidence and conflicting views cannot reject a photo', () {
    Map<String, dynamic> response(Object scores) => {
      'scores': scores,
      'modelSha256':
          '17cb073e902c459ebc04fe9b14a2ba10ec968a4c378c40fbd8199f7c5b0ff5d4',
    };
    expect(classifyLocalImageScreen(response([.03, .03])), 'uncertain');
    expect(classifyLocalImageScreen(response([-.4, .03])), 'uncertain');
    expect(classifyLocalImageScreen(response([-.4, .6])), 'supported');
    expect(classifyLocalImageScreen(response([-.8, -.7])), 'unsuitable');
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
  });
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
                  'supported' => [0.6, 0.6],
                  'uncertain' => [0.1, 0.1],
                  'unsuitable' => [-0.8, -0.8],
                  _ => [double.nan, 0.3],
                },
                'modelSha256':
                    '17cb073e902c459ebc04fe9b14a2ba10ec968a4c378c40fbd8199f7c5b0ff5d4',
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
        final first = await checker.assess(file, photo);
        expect(first['status'], status == 'invalid' ? 'error' : status);
        expect(
          suitabilityAccepted(first, photo),
          ['supported', 'uncertain'].contains(status),
        );
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
}
