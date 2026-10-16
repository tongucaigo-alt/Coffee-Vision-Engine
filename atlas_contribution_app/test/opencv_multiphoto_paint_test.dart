import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/trace_overlay.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

TraceCandidate _trace(int photo, int local) => TraceCandidate(
  photo,
  {'width': 64, 'height': 64},
  {
    'id': local,
    'score': 100.0,
    'pixels': [local + 65],
    'boundary': [local + 65],
    'box': [1 + local, 1, 1, 1],
    'aspect': 1.0,
  },
  PhotoCrop.full,
);

Future<List<int>> _paint(
  List<TraceCandidate> traces,
  int photo,
  PhotoCrop crop,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  TracePainter(
    traces: traces,
    photoIndex: photo,
    display: crop,
  ).paint(canvas, const Size(64, 64));
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final bytes = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final result = bytes!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'preparation cycles through all twelve traces without dropping a photo',
    (tester) async {
      final photos = [
        for (final role in freeCaptureRoles)
          ContributionPhoto.fromJson({
            ...testPhoto(role).toJson(),
            'id': 'photo-${role.name}',
          }),
      ];
      final traces = [
        for (var p = 0; p < 3; p++)
          for (var i = 0; i < 4; i++) _trace(p, i),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FortuneScan(
              progress: const FortuneProgress(FortunePhase.generating),
              photos: photos,
              imageFor: (_) => MemoryImage(testImage()),
              traces: TraceSet(photos, traces),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var photo = 0; photo < 3; photo++) {
        final overlay = tester.widget<TraceOverlay>(find.byType(TraceOverlay));
        expect(overlay.set.indexOf(overlay.photo), photo);
        expect(
          overlay.set.selected.where((t) => t.photoIndex == photo),
          hasLength(4),
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 4100));
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  for (final counts in [
    [1, 4, 3],
    [4, 4, 4],
  ]) {
    test(
      'all combined $counts traces paint with photo-local stable colors',
      () async {
        final all = [
          for (var p = 0; p < counts.length; p++)
            for (var i = 0; i < counts[p]; i++) _trace(p, i),
        ];
        for (final photo in [0, 1, 2, 1, 0, 2]) {
          final local = all.where((t) => t.photoIndex == photo).toList();
          for (final crop in [PhotoCrop.full, PhotoCrop(0, 0, .5, .5)]) {
            final together = await _paint(all, photo, crop);
            expect(together, await _paint(local, photo, crop));
            for (var i = 0; i < local.length; i++) {
              final scale = crop.isFull ? 1 : 2;
              final offset = ((1 * scale) * 64 + (1 + i) * scale) * 4;
              final color = traceColors[i];
              final channels = [color.r, color.g, color.b];
              for (var channel = 0; channel < 3; channel++) {
                expect(
                  together[offset + channel],
                  closeTo(channels[channel] * 255, 1),
                );
              }
              expect(together[offset + 3], greaterThan(230));
            }
          }
        }
      },
    );
  }
  test('zero-trace photo remains transparent', () async {
    expect(await _paint([_trace(0, 0)], 1, PhotoCrop.full), everyElement(0));
  });
}
