import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import '../test/simple_flow_test.dart' as storage;
import '../test/photo_set_widget_test.dart' as gallery;
import '../test/contribution_capture_flow_test.dart' as capture;
import 'export_device_test.dart' as exports;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  storage.main();
  gallery.main();
  capture.main();
  exports.main();
  testWidgets('real bundled classifier evaluates local reference photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Yerel fotoğraf kontrolü testi')),
      ),
    );
    final input = Directory('/data/local/tmp/atlas-suitability');
    final files =
        (await input.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files.length, greaterThanOrEqualTo(30));
    final rows = <Map<String, dynamic>>[];
    for (final file in files) {
      final timer = Stopwatch()..start();
      final scores = await PhotoSuitability.channel
          .invokeMapMethod<dynamic, dynamic>('classify', {
            'path': file.path,
            'crop': [0.0, 0.0, 1.0, 1.0],
          });
      final status = classifySuitability(scores!);
      rows.add({
        'file': file.uri.pathSegments.last,
        'status': status,
        'milliseconds': timer.elapsedMilliseconds,
        'scores': scores,
      });
    }
    final out = File(
      '${(await getApplicationSupportDirectory()).path}/suitability-benchmark.json',
    );
    await out.writeAsString(
      jsonEncode({
        'version': suitabilityVersion,
        'blockingEnabled': suitabilityBlockingValidated,
        'rows': rows,
      }),
    );
    expect(
      rows.where((r) => r['status'] == 'unsuitable'),
      isEmpty,
      reason: 'Real coffee reference images must not be blocked',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
