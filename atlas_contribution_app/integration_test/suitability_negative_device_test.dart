import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';

/// Measurement only: a green test means valid inference, not good rejection.
/// Run only in the separate diagnostic package with locally supplied fixtures.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'measure negative and residue-free references without changing policy',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Yerel olumsuz örnek ölçümü')),
        ),
      );
      const base = '/data/local/tmp/atlas-suitability/negative-20260929';
      final manifest =
          jsonDecode(await File('$base/manifest.json').readAsString()) as List;
      expect(manifest, isNotEmpty);
      final rows = <Map<String, dynamic>>[];
      final privateRoot = await getApplicationSupportDirectory();
      var errors = 0;
      for (final item in manifest) {
        final name = item['file'] as String;
        expect(RegExp(r'^negative-[0-9]+\.jpg$').hasMatch(name), isTrue);
        // Exercise the same private-directory path as real camera records.
        final file = await File('$base/$name').copy('${privateRoot.path}/$name');
        expect(
          sha256.convert(await file.readAsBytes()).toString(),
          item['checksum'],
        );
        final clock = Stopwatch()..start();
        final row = <String, dynamic>{
          'file': name,
          'group': item['group'],
          'checksum': item['checksum'],
        };
        try {
          final scores = await PhotoSuitability.channel
              .invokeMapMethod<dynamic, dynamic>('classify', {
                'path': file.path,
                'crop': [0.0, 0.0, 1.0, 1.0],
              });
          row.addAll({
            'status': classifySuitability(scores!),
            'scores': scores,
          });
        } catch (_) {
          row['status'] = 'error';
          errors++;
        }
        row['milliseconds'] = clock.elapsedMilliseconds;
        rows.add(row);
      }
      final output = File(
        '${(await getApplicationSupportDirectory()).path}/suitability-negative-benchmark.json',
      );
      await output.writeAsString(
        jsonEncode({
          'version': suitabilityVersion,
          'blockingEnabled': suitabilityBlockingValidated,
          'residueAssessment': 'notAssessed',
          'view': 'original photo; full and crop identical',
          'releaseAcceptance': 'notEvaluated',
          'rows': rows,
        }),
      );
      expect(
        errors,
        0,
        reason:
            'Technical errors recorded; do not interpret them as photo rejection.',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
