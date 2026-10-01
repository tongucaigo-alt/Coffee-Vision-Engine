import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'package:atlas_contribution_app/src/mvp/photo_residue_check.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> scores(String label, double score) => {
    for (final key in ['full', 'crop'])
      key: [
        {'label': label, 'score': score},
      ],
  };
  test(
    'relative darkness does not confuse a uniform black image with residue',
    () async {
      for (final level in [0, 100, 240]) {
        final bytes = img.encodePng(
          img.Image(width: 120, height: 160)
            ..clear(img.ColorRgb8(level, level, level)),
        );
        final result = await measurePhotoResidue({
          'bytes': bytes,
          'crop': [0.0, 0.0, 1.0, 1.0],
        });
        expect((result['full'] as Map)['relativeDarkRatio'], 0);
        expect(
          residueDecision(scores('cup', .95), result, saucer: false),
          level == 0 ? 'uncertain' : 'residueFree',
        );
      }
    },
  );
  test('mask follows actual crop; source pixels remain unchanged', () async {
    final image = img.Image(width: 100, height: 100)
      ..clear(img.ColorRgb8(230, 230, 230));
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 19,
      y2: 99,
      color: img.ColorRgb8(30, 30, 30),
    );
    final bytes = img.encodePng(image),
        before = sha256.convert(img.encodePng(image));
    final result = await measurePhotoResidue({
      'bytes': bytes,
      'crop': [.3, 0.0, .7, 1.0],
    });
    expect((result['full'] as Map)['relativeDarkRatio'], greaterThan(.15));
    expect((result['crop'] as Map)['relativeDarkRatio'], 0);
    expect(sha256.convert(bytes), before);
    expect(
      residueDecision(scores('computer keyboard', .99), result, saucer: false),
      'uncertain',
    );
  });
  test(
    'background and preflight coalesce, retry once, cache by surface and crop',
    () async {
      final dir = await Directory.systemTemp.createTemp('atlas-residue-test-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = testImage();
      final file = await File('${dir.path}/image.png').writeAsBytes(bytes);
      final p = ContributionPhoto.fromJson({
        ...testPhoto(CaptureRole.free).toJson(),
        'checksum': 'sha256:${sha256.convert(bytes)}',
      });
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PhotoSuitability.channel, (call) async {
            calls++;
            if (calls == 1) throw PlatformException(code: 'temporary');
            return scores('cup', .95);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PhotoSuitability.channel, null),
      );
      final checker = PhotoSuitability(Directory('${dir.path}/checks'));
      final results = await Future.wait([
        checker.assess(file, p),
        PhotoSuitability(checker.directory).assess(file, p),
      ]);
      expect(calls, 2);
      expect(results[0]['attempts'], 2);
      expect(results[0]['candidateStatus'], 'residueFree');
      expect(results[0]['status'], 'uncertain'); // release gate not passed
      expect(results[0]['continuedAtUtc'], isNull);
      expect(jsonEncode(results[0]), jsonEncode(results[1]));
      await checker.assess(file, p);
      expect(calls, 2);
      final saucer = p.asSetPhoto(type: PhotoSurface.saucer);
      expect(suitabilityAccepted(results[0], saucer), isFalse);
      await checker.assess(file, saucer);
      expect(calls, 3);
    },
  );
  test(
    'persistent native failure retries only once and cannot be accepted',
    () async {
      final dir = await Directory.systemTemp.createTemp('atlas-failure-test-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = testImage();
      final file = await File('${dir.path}/image.png').writeAsBytes(bytes);
      final p = ContributionPhoto.fromJson({
        ...testPhoto(CaptureRole.free).toJson(),
        'checksum': 'sha256:${sha256.convert(bytes)}',
      });
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PhotoSuitability.channel, (_) async {
            calls++;
            throw PlatformException(code: 'failed');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PhotoSuitability.channel, null),
      );
      final checker = PhotoSuitability(Directory('${dir.path}/checks'));
      final error = await checker.assess(file, p);
      expect(calls, 2);
      expect(error['status'], 'error');
      expect(
        suitabilityAccepted({...error, 'continuedAtUtc': 'legacy'}, p),
        isFalse,
      );
      await checker.assess(file, p);
      expect(calls, 2);
      await checker.assess(file, p, retry: true);
      expect(calls, 4);
    },
  );
}
