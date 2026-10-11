import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'rich_fortune_device_test.dart' as flow;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flow.main();
  testWidgets('real local model shares preview decision and durable cache', (
    tester,
  ) async {
    expect(diagnosticImageScreen, isTrue);
    const base = '/data/local/tmp/atlas-suitability/image-screen';
    final manifest =
        jsonDecode(await File('$base/manifest.json').readAsString()) as List;
    final root = await Directory.systemTemp.createTemp(
      'atlas-local-screen-flow-',
    );
    final checker = PhotoSuitability(Directory('${root.path}/checks'));
    try {
      for (final name in [
        'sample-502.jpg',
        'sample-546.jpg',
        'sample-594.jpg',
      ]) {
        final item = manifest.singleWhere((row) => row['file'] == name) as Map;
        final bytes = await File('$base/$name').readAsBytes();
        expect(sha256.convert(bytes).toString(), item['sha256']);
        final prepared = preparePhoto(bytes);
        final file = await File(
          '${root.path}/$name',
        ).writeAsBytes(prepared['bytes'] as List<int>);
        final photo = ContributionPhoto(
          role: CaptureRole.free,
          localName: name,
          checksum: prepared['checksum'] as String,
          originalChecksum: 'sha256:${item['sha256']}',
          width: prepared['width'] as int,
          height: prepared['height'] as int,
          byteLength: await file.length(),
          displayCrop: PhotoCrop(.1, .1, .8, .8),
          capturedAt: '2026-10-03T00:00:00Z',
        );
        final result = await checker.assess(file, photo);
        final accepted = name == 'sample-502.jpg';
        expect(suitabilityAccepted(result, photo), accepted);
        expect(result['status'], accepted ? 'supported' : 'unsuitable');
        expect(result['diagnosticOnly'], true);
        expect(result['continuedAtUtc'], isNull);
        final cached = await PhotoSuitability(
          checker.directory,
        ).assess(file, photo);
        expect(cached['checkedAtUtc'], result['checkedAtUtc']);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PhotoSuitabilityNotice(photo: photo, value: result),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('fincanının hikâyesine ulaşamadık'),
          accepted ? findsNothing : findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Bu fotoğrafla devam et'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await root.delete(recursive: true);
    }
  });
}
