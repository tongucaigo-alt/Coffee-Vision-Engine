import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import '../test/fixtures.dart';
import '../test/photo_set_widget_test.dart' as flow;
import '../test/contribution_capture_flow_test.dart' as capture;
import 'export_device_test.dart' as exports;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flow.main();
  capture.main();
  exports.main();
  testWidgets('real device scan shows stored markings and can stop', (
    tester,
  ) async {
    var stopped = false;
    final photo = testPhoto(
      CaptureRole.free,
      decision: PhotoDecision.marked,
      regions: [
        RegionAnnotation(
          id: 'synthetic-marker',
          box: RegionBox(.3, .3, .15, .15),
          label: contributionLabels.keys.first,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FortuneScan(
            progress: const FortuneProgress(FortunePhase.analyzing),
            photos: [photo],
            imageFor: (_) => MemoryImage(testImage()),
            onCancel: () => stopped = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Telve dağılımı inceleniyor'), findsOneWidget);
    await tester.ensureVisible(find.text('Durdur'));
    await tester.tap(find.text('Durdur'));
    expect(stopped, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
