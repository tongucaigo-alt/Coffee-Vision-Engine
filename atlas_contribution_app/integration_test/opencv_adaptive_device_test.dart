import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/opencv_traces.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated native contrast comparison; no UI or AI requests', (
    tester,
  ) async {
    final manifest =
        jsonDecode(
              await File(
                '/data/local/tmp/atlas-adaptive-traces/fixtures.json',
              ).readAsString(),
            )
            as List;
    final rows = <Map<String, dynamic>>[];
    for (final row in manifest) {
      final png = await File(
        '/data/local/tmp/atlas-adaptive-traces/${row['id']}.png',
      ).readAsBytes();
      final variants = <String, dynamic>{};
      for (final clip in [2, 1, 3, 0]) {
        final elapsed = Stopwatch()..start();
        final result = await TraceService.channel
            .invokeMapMethod<String, dynamic>('analyze', {
              'png': png,
              if (clip == 1 || clip == 3) 'comparisonClip': clip,
              if (clip == 0) 'adaptive': true,
            });
        expect(result, isNotNull);
        validateTraceResult(result);
        variants['$clip'] = {
          'wallMs': elapsed.elapsedMilliseconds,
          'result': result,
        };
      }
      rows.add({'id': row['id'], 'group': row['group'], 'variants': variants});
    }
    // Repeated on actual hardware, median overhead avoids cold-start noise.
    final timings = <Map<String, dynamic>>[];
    for (final row in manifest.take(12)) {
      final png = await File(
        '/data/local/tmp/atlas-adaptive-traces/${row['id']}.png',
      ).readAsBytes();
      final baseline = <int>[], adaptive = <int>[];
      for (var i = 0; i < 5; i++) {
        for (final enabled in [false, true]) {
          final clock = Stopwatch()..start();
          await TraceService.channel.invokeMethod('analyze', {
            'png': png,
            if (enabled) 'adaptive': true,
          });
          (enabled ? adaptive : baseline).add(clock.elapsedMilliseconds);
        }
      }
      baseline.sort();
      adaptive.sort();
      timings.add({
        'id': row['id'],
        'baselineMedianMs': baseline[2],
        'adaptiveMedianMs': adaptive[2],
        'extraMedianMs': adaptive[2] - baseline[2],
      });
    }
    final directory = await getTemporaryDirectory();
    for (final level in [35, 220]) {
      final png = img.encodePng(
        img.Image(width: 256, height: 256)
          ..clear(img.ColorRgb8(level, level, level)),
      );
      final baseline = await TraceService.channel
          .invokeMapMethod<String, dynamic>('analyze', {'png': png});
      final selective = await TraceService.channel
          .invokeMapMethod<String, dynamic>('analyze', {
            'png': png,
            'adaptive': true,
          });
      expect(selective!['candidates'], baseline!['candidates']);
    }
    final png = await File(
      '/data/local/tmp/atlas-adaptive-traces/${manifest.first['id']}.png',
    ).readAsBytes();
    final baseline = await TraceService.channel
        .invokeMapMethod<String, dynamic>('analyze', {'png': png});
    final expired = await TraceService.channel.invokeMapMethod<String, dynamic>(
      'analyze',
      {'png': png, 'adaptive': true, 'extraBudgetMs': 0},
    );
    expect(expired!['candidates'], baseline!['candidates']);
    await expectLater(
      TraceService.channel.invokeMethod('analyze', {
        'png': [0, 1, 2],
      }),
      throwsA(isA<Exception>()),
    );
    await File(
      '${directory.path}/adaptive-device-results.json',
    ).writeAsString(jsonEncode({'rows': rows, 'timings': timings}));
    expect(rows.length, 24);
  });
}
