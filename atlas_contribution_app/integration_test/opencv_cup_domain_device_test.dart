import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/opencv_traces.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cup-only masks on real user photos, separate test identity', (
    tester,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i <= 3; i++) {
      final source = await File(
        '/data/local/tmp/atlas-cup-domain/photo-$i.jpg',
      ).readAsBytes();
      final png = prepareTraceImage({
        'bytes': source,
        'area': [0.0, 0.0, 1.0, 1.0],
      });
      final baseline = await TraceService.channel
          .invokeMapMethod<String, dynamic>('analyze', {
            'png': png,
            'legacyDomain': true,
          });
      final result = await TraceService.channel
          .invokeMapMethod<String, dynamic>('analyze', {'png': png});
      validateTraceResult(result);
      final ellipse = (result!['cupBoundary'] as List).cast<num>();
      expect(
        ellipse.length,
        5,
        reason: 'Known test cup must have a measured boundary',
      );
      expect(result['candidates'], isNotEmpty);
      final w = result['width'] as int;
      final theta = ellipse[4] * math.pi / 180;
      for (final c in result['candidates'] as List) {
        for (final p in (c['pixels'] as List).cast<int>()) {
          final x = p % w - ellipse[0];
          final y = p ~/ w - ellipse[1];
          final xx =
              (x * math.cos(theta) + y * math.sin(theta)) / (ellipse[2] / 2);
          final yy =
              (-x * math.sin(theta) + y * math.cos(theta)) / (ellipse[3] / 2);
          expect(xx * xx + yy * yy, lessThanOrEqualTo(1.06));
        }
      }
      rows.add({'photo': i, 'baseline': baseline, 'result': result});
    }
    final regression = <Map<String, dynamic>>[];
    final manifest =
        jsonDecode(
              await File(
                '/data/local/tmp/atlas-adaptive-traces/fixtures.json',
              ).readAsString(),
            )
            as List;
    for (final row in manifest) {
      final png = await File(
        '/data/local/tmp/atlas-adaptive-traces/${row['id']}.png',
      ).readAsBytes();
      final result = await TraceService.channel
          .invokeMapMethod<String, dynamic>('analyze', {'png': png});
      validateTraceResult(result);
      regression.add({'id': row['id'], 'result': result});
    }
    for (final level in [35, 220]) {
      final png = img.encodePng(
        img.Image(width: 256, height: 256)
          ..clear(img.ColorRgb8(level, level, level)),
      );
      final result = await TraceService.channel
          .invokeMapMethod<String, dynamic>('analyze', {'png': png});
      expect(result!['candidates'], isEmpty);
    }
    final temp = await getTemporaryDirectory();
    await File(
      '${temp.path}/cup-domain-results.json',
    ).writeAsString(jsonEncode({'rows': rows, 'regression': regression}));
  });
}
