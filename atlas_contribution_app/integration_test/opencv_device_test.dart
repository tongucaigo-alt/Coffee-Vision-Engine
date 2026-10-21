import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/trace_overlay.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import '../test/fortune_flow_presentation_test.dart' as presentation;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  presentation.main();
  testWidgets(
    'real OpenCV on twelve cups, continuous preparation and compact closeup',
    (tester) async {
      final temp = await getTemporaryDirectory();
      final service = TraceService(Directory('${temp.path}/opencv-device-v49'));
      final rows = <Map<String, dynamic>>[], photos = <ContributionPhoto>[];
      final files = <String, File>{};
      TraceSet? firstSet;
      final progress = ValueNotifier(
        const FortuneProgress(FortunePhase.saving),
      );
      final flow = FortunePreparationController(progress);
      for (var i = 1; i <= 12; i++) {
        final file = File('/data/local/tmp/atlas-opencv-v49/c$i.jpg');
        final bytes = await file.readAsBytes();
        final image = img.bakeOrientation(img.decodeImage(bytes)!);
        final p = ContributionPhoto(
          role: freeCaptureRoles[(i - 1) % 3],
          localName: 'native-$i.jpg',
          checksum: 'sha256:${sha256.convert(bytes)}',
          originalChecksum: 'sha256:${sha256.convert(bytes)}',
          width: image.width,
          height: image.height,
          byteLength: bytes.length,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
          decision: PhotoDecision.skipped,
        );
        photos.add(p);
        files[p.localName] = file;
        final clock = Stopwatch()..start();
        final result = await service.analyze('fixture-$i', file, p);
        final set = TraceSet(
          [p],
          selectTraces([
            for (final c in result['candidates'] as List)
              TraceCandidate(
                0,
                result,
                Map<String, dynamic>.from(c as Map),
                p.visibleCrop,
              ),
          ]),
        );
        rows.add({
          'fixture': i,
          'totalMs': clock.elapsedMilliseconds,
          'nativeMs': result['durationMs'],
          'selected': set.selected.length,
        });
        expect(set.selected.length, lessThanOrEqualTo(4));
        expect(validateTraceResult(result)['width'], lessThanOrEqualTo(512));
        if (firstSet == null && set.selected.isNotEmpty) firstSet = set;
      }
      expect(
        firstSet,
        isNotNull,
        reason: 'Real reference cups must yield a selectable trace.',
      );
      final chosen = firstSet!;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              FortunePreparationHost(controller: flow, child: child!),
          home: const Scaffold(),
        ),
      );
      flow.begin(
        photos: photos.take(3).toList(),
        imageFor: (p) => FileImage(files[p.localName]!),
        onCancel: () {},
      );
      await tester.pump();
      final state = tester.state(find.byType(FortuneScan));
      final clock = Stopwatch()..start();
      final set = await service.loadSet(
        owner: 'three-cups',
        photos: photos.take(3).toList(),
        fileFor: (p) => files[p.localName]!,
        onUpdate: (value, p) {
          progress.value = FortuneProgress(
            FortunePhase.highlighting,
            photoId: p.localName,
          );
          flow.updateTraces(value);
        },
      );
      final setMs = clock.elapsedMilliseconds;
      await tester.pump();
      expect(tester.state(find.byType(FortuneScan)), same(state));
      expect(set.selected.length, lessThanOrEqualTo(4));
      progress.value = const FortuneProgress(FortunePhase.generating);
      await tester.pump();
      expect(tester.state(find.byType(FortuneScan)), same(state));
      flow.finish();
      final p = chosen.photos.first, trace = chosen.selected.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TracePhotoViewer(
                photo: p,
                image: FileImage(files[p.localName]!),
                set: chosen,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pixel = trace.pixels[trace.pixels.length ~/ 2];
      final bounds = tester.getRect(find.byType(TracePhoto));
      await tester.tapAt(
        Offset(
          bounds.left + (pixel % trace.width + .5) / trace.width * bounds.width,
          bounds.top +
              (pixel ~/ trace.width + .5) / trace.height * bounds.height,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Telve izi'), findsOneWidget);
      await tester.ensureVisible(find.text('Kapat'));
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orijinal'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TracePhoto>(find.byType(TracePhoto)).colored,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      final memory = (await File('/proc/self/status').readAsLines())
          .where((s) => s.startsWith('VmRSS:') || s.startsWith('VmHWM:'))
          .toList();
      final report = {
        'nativeResults': rows,
        'threeCupMs': setMs,
        'memory': memory,
      };
      binding.reportData = report;
      final output = await getExternalStorageDirectory();
      await File(
        '${output!.path}/opencv-v49-device.json',
      ).writeAsString(jsonEncode(report));
      debugPrint('OPENCV_V49_DEVICE ${jsonEncode(report)}');
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
      progress.dispose();
    },
  );
}
