import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/opencv_traces.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'V76 native masks and five measured repetitions in isolated package',
    (tester) async {
      final manifest =
          jsonDecode(
                await File(
                  '/data/local/tmp/atlas-v76/manifest.json',
                ).readAsString(),
              )
              as List;
      final rows = <Map<String, dynamic>>[];
      for (final row in manifest) {
        final png = prepareTraceImage({
          'bytes': await File(
            '/data/local/tmp/atlas-v76/${row['id']}.jpg',
          ).readAsBytes(),
          'area': [0.0, 0.0, 1.0, 1.0],
        });
        final timings = <int>[];
        Map<String, dynamic>? first;
        for (var repeat = 0; repeat < 5; repeat++) {
          final clock = Stopwatch()..start();
          final result = validateTraceResult(
            await TraceService.channel.invokeMapMethod<String, dynamic>(
              'analyze',
              {'png': png},
            ),
          );
          timings.add(clock.elapsedMilliseconds);
          first ??= result;
          final stable = Map<String, dynamic>.from(result)
            ..remove('durationMs');
          final original = Map<String, dynamic>.from(first)
            ..remove('durationMs');
          expect(
            stable,
            original,
            reason: 'Stable masks and coordinates across warm repetitions',
          );
        }
        rows.add({'id': row['id'], 'result': first, 'wallMs': timings});
      }
      for (final level in [35, 220]) {
        final png = img.encodePng(
          img.Image(width: 256, height: 256)
            ..clear(img.ColorRgb8(level, level, level)),
        );
        final result = validateTraceResult(
          await TraceService.channel.invokeMapMethod<String, dynamic>(
            'analyze',
            {'png': png},
          ),
        );
        expect(result['candidates'], isEmpty);
        expect(result['cupBoundary'], isEmpty);
      }
      final temp = await getTemporaryDirectory();
      await File(
        '${temp.path}/v76-native-results.json',
      ).writeAsString(jsonEncode(rows));
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
