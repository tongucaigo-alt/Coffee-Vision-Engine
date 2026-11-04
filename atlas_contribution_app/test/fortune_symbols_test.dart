import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/trace_symbols.dart';
import 'package:atlas_contribution_app/src/trace_overlay.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

List<TraceCandidate> symbolTraces({bool boundary = true, int photo = 0}) {
  final result = <String, dynamic>{
    'width': 512,
    'height': 512,
    if (boundary) 'surfaceBoundary': [256, 256, 470, 470, 27],
  };
  return [
    for (var i = 0; i < 7; i++)
      TraceCandidate(photo, result, {
        'id': i,
        'score': 100.0 - i,
        'pixels': [
          for (var y = -6; y <= 6; y++)
            for (var x = -6; x <= 6; x++)
              (256 + (120 * math.sin(i * 2 * math.pi / 7)).round() + y) * 512 +
                  256 +
                  (120 * math.cos(i * 2 * math.pi / 7)).round() +
                  x,
        ],
        'boundary': <int>[],
        'box': [0, 0, 512, 512],
      }, PhotoCrop.full),
  ];
}

void main() {
  final photo = testPhoto(CaptureRole.free);
  final finder = find.byKey(const ValueKey('fortune-decorative-symbols'));
  Widget screen({
    List<TraceCandidate>? traces,
    bool reduce = false,
    bool enabled = true,
    FortunePhase phase = FortunePhase.generating,
    ContributionPhoto? source,
    PhotoCrop? crop,
  }) {
    final p = source ?? photo;
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: FortuneScan(
            progress: FortuneProgress(phase),
            photos: [p],
            imageFor: (_) => MemoryImage(testImage()),
            showDecorativeSymbols: enabled,
            traces: TraceSet([p], traces ?? symbolTraces()),
            onCancel: () => {},
          ),
        ),
      ),
    );
  }

  List<Icon> icons(WidgetTester t) => t
      .widgetList<Icon>(
        find.descendant(of: finder, matching: find.byType(Icon)),
      )
      .toList();

  int traceIndexFor(
    WidgetTester tester,
    Icon icon,
    List<TraceCandidate> traces,
  ) {
    final anchors = traceSymbolAnchors(
      traces,
      PhotoCrop.full,
      tester.getSize(finder),
    );
    final point =
        tester.getCenter(find.byKey(icon.key!)) - tester.getTopLeft(finder);
    return anchors
        .singleWhere((a) => (a.position - point).distance < .001)
        .traceIndex;
  }

  test('seven palette entries are distinct and preserve the first four', () {
    expect(traceColors, hasLength(7));
    expect(traceColors.toSet(), hasLength(7));
    expect(traceColors.take(4), [
      const Color(0xff0eae98),
      const Color(0xffdf4a78),
      const Color(0xff4388df),
      const Color(0xffe1aa19),
    ]);
  });
  test(
    'anchors are real mask pixels and full footprints fit a rotated ellipse',
    () {
      final traces = symbolTraces();
      final anchors = traceSymbolAnchors(
        traces,
        PhotoCrop.full,
        const Size(412, 412),
      );
      expect(anchors, hasLength(7));
      for (final a in anchors) {
        final source = a.position * (512 / 412);
        expect(
          traces[a.traceIndex].pixels,
          contains(source.dy.floor() * 512 + source.dx.floor()),
        );
        final r = Rect.fromCircle(
          center: a.position,
          radius: traceSymbolMargin,
        );
        for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
          final p = c * (512 / 412) - const Offset(256, 256);
          final u =
              (p.dx * math.cos(27 * math.pi / 180) +
                  p.dy * math.sin(27 * math.pi / 180)) /
              235;
          final v =
              (-p.dx * math.sin(27 * math.pi / 180) +
                  p.dy * math.cos(27 * math.pi / 180)) /
              235;
          expect(u * u + v * v, lessThanOrEqualTo(1));
        }
      }
      expect(
        traceSymbolAnchors(
          symbolTraces(boundary: false),
          PhotoCrop.full,
          const Size(412, 412),
        ),
        isEmpty,
      );
      expect(
        traceSymbolAnchors(
          traces,
          PhotoCrop(.9, .9, .1, .1),
          const Size(200, 200),
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'three stable contrasting slots rotate through all seven traces and ten icons',
    (tester) async {
      final traces = symbolTraces();
      await tester.pumpWidget(screen(traces: traces));
      await tester.pump(const Duration(milliseconds: 600));
      expect(icons(tester), hasLength(3));
      final oldPositions = [
        for (var i = 0; i < 3; i++)
          tester.getCenter(find.byKey(ValueKey('fortune-symbol-$i'))),
      ];
      final oldColors = icons(tester).map((i) => i.color).toList();
      await tester.pump(const Duration(milliseconds: 400));
      expect(icons(tester).map((i) => i.color), oldColors);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.getCenter(find.byKey(ValueKey('fortune-symbol-$i'))),
          oldPositions[i],
        );
      }
      final seenTraces = <int>{}, seenIcons = <IconData>{};
      for (var cycle = 0; cycle < 12; cycle++) {
        final current = icons(tester);
        expect(current.length, lessThanOrEqualTo(3));
        final traceIndices = current
            .map((i) => traceIndexFor(tester, i, traces))
            .toSet();
        expect(traceIndices, hasLength(current.length));
        seenTraces.addAll(traceIndices);
        seenIcons.addAll(current.map((i) => i.icon!));
        for (final icon in current) {
          expect(icon.shadows, hasLength(1));
          expect(icon.shadows!.single.blurRadius, 4);
          expect(icon.shadows!.single.color.a, closeTo(.5, .001));
          final index = traceIndexFor(tester, icon, traces);
          expect(icon.color, isNot(traceColors[index]));
          expect(icon.color, traceSymbolColorFor(index));
          expect(icon.size, traceSymbolIconSize);
        }
        final anchors = traceSymbolAnchors(
          traces,
          PhotoCrop.full,
          tester.getSize(finder),
        );
        for (final icon in current) {
          final expected = anchors
              .firstWhere(
                (a) => a.traceIndex == traceIndexFor(tester, icon, traces),
              )
              .position;
          final actual =
              tester.getCenter(find.byKey(icon.key!)) -
              tester.getTopLeft(finder);
          expect((actual - expected).distance, lessThan(.001));
        }
        final positions = [
          for (final icon in current) tester.getCenter(find.byKey(icon.key!)),
        ];
        for (var i = 0; i < positions.length; i++) {
          for (var j = i + 1; j < positions.length; j++) {
            expect(
              (positions[i] - positions[j]).distance,
              greaterThanOrEqualTo(traceSymbolGap),
            );
          }
        }
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(seenTraces, {0, 1, 2, 3, 4, 5, 6});
      expect(seenIcons, hasLength(10));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('two photos with six traces each visit both groups of three', (
    tester,
  ) async {
    final first = photo.asSetPhoto(photoId: 'first');
    final second = photo.asSetPhoto(photoId: 'second');
    String? current;
    final seen = {'first': <int>{}, 'second': <int>{}};
    final set = TraceSet(
      [first, second],
      [...symbolTraces().take(6), ...symbolTraces(photo: 1).take(6)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FortuneScan(
            progress: const FortuneProgress(FortunePhase.generating),
            photos: [first, second],
            imageFor: (p) {
              current = p.id;
              return MemoryImage(testImage());
            },
            traces: set,
            showDecorativeSymbols: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var cycle = 0; cycle < 12; cycle++) {
      seen[current!]!.addAll(
        icons(
          tester,
        ).map((i) => traceIndexFor(tester, i, symbolTraces().take(6).toList())),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(seen['first'], {0, 1, 2, 3, 4, 5});
    expect(seen['second'], {0, 1, 2, 3, 4, 5});
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'nearby traces alternate instead of starving behind a visible neighbour',
    (tester) async {
      final base = symbolTraces();
      const centres = [Offset(220, 240), Offset(224, 240), Offset(340, 340)];
      final traces = [
        for (var i = 0; i < 3; i++)
          TraceCandidate(0, base[i].result, {
            ...base[i].data,
            'pixels': [
              for (var y = -2; y <= 2; y++)
                for (var x = -2; x <= 2; x++)
                  (centres[i].dy.toInt() + y) * 512 + centres[i].dx.toInt() + x,
            ],
          }, PhotoCrop.full),
      ];
      await tester.pumpWidget(screen(traces: traces));
      await tester.pump(const Duration(milliseconds: 600));
      final seen = <int>{};
      for (var cycle = 0; cycle < 8; cycle++) {
        final current = icons(tester);
        expect(current.length, lessThanOrEqualTo(2));
        seen.addAll(current.map((i) => traceIndexFor(tester, i, traces)));
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(seen, {0, 1, 2});
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('no traces or no boundary invents no decorations', (
    tester,
  ) async {
    await tester.pumpWidget(screen(traces: []));
    expect(finder, findsNothing);
    await tester.pumpWidget(screen(traces: symbolTraces(boundary: false)));
    expect(icons(tester), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'saucer uses the same palette; photo changes cannot retain old anchors',
    (tester) async {
      final saucer = photo.asSetPhoto(
        type: PhotoSurface.saucer,
        photoId: 'plate',
      );
      await tester.pumpWidget(screen(source: saucer));
      await tester.pump(const Duration(milliseconds: 600));
      expect(icons(tester), isNotEmpty);
      await tester.pumpWidget(
        screen(source: photo, traces: symbolTraces(boundary: false)),
      );
      expect(icons(tester), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('photo and closeup painters share per-photo seven colours', (
    tester,
  ) async {
    final traces = [...symbolTraces(), ...symbolTraces(photo: 1)];
    final original = TracePainter(
      traces: traces,
      photoIndex: 1,
      display: PhotoCrop.full,
    );
    expect(original.traces.where((t) => t.photoIndex == 1), hasLength(7));
    // Pump both display crops to exercise actual painter paths and palette bounds.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(painter: original),
            ),
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: TracePainter(
                  traces: traces,
                  photoIndex: 1,
                  display: PhotoCrop(.2, .2, .5, .5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final phase in [
    FortunePhase.completed,
    FortunePhase.failed,
    FortunePhase.cancelled,
  ]) {
    testWidgets('decorations stop at $phase', (tester) async {
      await tester.pumpWidget(screen());
      expect(finder, findsOneWidget);
      await tester.pumpWidget(screen(phase: phase));
      await tester.pumpAndSettle();
      expect(finder, findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('opt-in and reduced motion are respected', (tester) async {
    await tester.pumpWidget(screen(enabled: false));
    expect(finder, findsNothing);
    await tester.pumpWidget(screen(reduce: true));
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
