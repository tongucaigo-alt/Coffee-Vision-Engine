import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'fixtures.dart';

final viewport = find.byKey(const ValueKey('annotation-viewport'));
final canvas = find.byKey(const ValueKey('annotation-canvas'));
final selected = find.byKey(const ValueKey('selected-region'));

TransformationController transform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!;

List<double> normalized(WidgetTester tester) {
  final image = tester.getRect(canvas), box = tester.getRect(selected);
  return [
    (box.left - image.left) / image.width,
    (box.top - image.top) / image.height,
    box.width / image.width,
    box.height / image.height,
  ];
}

void expectSameBox(WidgetTester tester, List<double> expected) {
  final actual = normalized(tester);
  for (var i = 0; i < 4; i++) {
    expect(actual[i], closeTo(expected[i], .00001));
  }
}

Future<void> mount(
  WidgetTester tester, {
  bool gallery = false,
  RegionBox? initialBox,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final photo = gallery
      ? ContributionPhoto(
          role: null,
          localName: 'test-gallery.jpg',
          checksum: 'sha256:${'a' * 64}',
          originalChecksum: 'sha256:${'b' * 64}',
          width: 160,
          height: 200,
          byteLength: 1000,
          capturedAt: null,
          importedAt: DateTime.now().toUtc().toIso8601String(),
        )
      : testPhoto(
          CaptureRole.top,
          decision: initialBox == null
              ? PhotoDecision.unreviewed
              : PhotoDecision.marked,
          regions: initialBox == null
              ? const []
              : [
                  RegionAnnotation(
                    id: 'small-region',
                    box: initialBox,
                    label: 'bird',
                  ),
                ],
        );
  await tester.pumpWidget(
    MaterialApp(
      theme: contributionTheme(),
      home: AnnotationPage(
        photo: photo,
        image: MemoryImage(testImage()),
        onSave: (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final location in [
    const Offset(.5, .5),
    const Offset(.01, .01),
    const Offset(.99, .01),
    const Offset(.01, .99),
    const Offset(.99, .99),
  ]) {
    testWidgets('15 percent box is centered and clamped at $location', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(find.text('İşaret'));
      await tester.pumpAndSettle();
      final image = tester.getRect(canvas);
      await tester.tapAt(
        image.topLeft +
            Offset(image.width * location.dx, image.height * location.dy),
      );
      await tester.pumpAndSettle();
      expectSameBox(tester, [
        (location.dx - .075).clamp(0, .85),
        (location.dy - .075).clamp(0, .85),
        .15,
        .15,
      ]);
    });
  }

  testWidgets('new box keeps 15 percent image size after zoom and pan', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Yakınlaştır'));
    await tester.tap(find.byTooltip('Yakınlaştır'));
    await tester.pumpAndSettle();
    await tester.drag(viewport, const Offset(-20, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    final image = tester.getRect(canvas);
    final tap = tester.getCenter(viewport) + const Offset(20, -15);
    await tester.tapAt(tap);
    await tester.pumpAndSettle();
    expectSameBox(tester, [
      (tap.dx - image.left) / image.width - .075,
      (tap.dy - image.top) / image.height - .075,
      .15,
      .15,
    ]);
    expect((tester.getCenter(selected) - tap).distance, lessThan(.01));
  });

  for (final zoom in [false, true]) {
    testWidgets(
      'small box center moves despite overlapping corners zoom=$zoom',
      (tester) async {
        await mount(tester, initialBox: RegionBox(.45, .45, .04, .04));
        await tester.tap(find.text('Kuş'));
        await tester.pumpAndSettle();
        if (zoom) {
          await tester.tap(find.byTooltip('Yakınlaştır'));
          await tester.pumpAndSettle();
        }
        final before = tester.getRect(selected);
        final start = before.center + Offset(before.width / 10, 0);
        for (var i = 0; i < 4; i++) {
          expect(
            tester
                .getRect(find.byKey(ValueKey('resize-corner-$i')))
                .contains(start),
            isTrue,
          );
        }
        final finger = await tester.startGesture(start);
        await finger.moveBy(const Offset(6, 8));
        await tester.pump();
        final after = tester.getRect(selected);
        expect(after.left, closeTo(before.left + 6, .01));
        expect(after.top, closeTo(before.top + 8, .01));
        expect(after.size, before.size);
        await finger.up();
      },
    );
  }

  for (var corner = 0; corner < 4; corner++) {
    testWidgets('overlapping targets resize nearest actual corner $corner', (
      tester,
    ) async {
      await mount(tester, initialBox: RegionBox(.45, .45, .04, .04));
      await tester.tap(find.text('Kuş'));
      await tester.pumpAndSettle();
      final before = tester.getRect(selected);
      final start = Offset(
        corner.isEven ? before.left + 1 : before.right - 1,
        corner < 2 ? before.top + 1 : before.bottom - 1,
      );
      final delta = Offset(corner.isEven ? -4 : 4, corner < 2 ? -5 : 5);
      final finger = await tester.startGesture(start);
      await finger.moveBy(delta);
      await tester.pump();
      final after = tester.getRect(selected);
      expect(after.width, closeTo(before.width + 4, .01));
      expect(after.height, closeTo(before.height + 5, .01));
      expect(
        corner.isEven ? after.right : after.left,
        closeTo(corner.isEven ? before.right : before.left, .01),
      );
      expect(
        corner < 2 ? after.bottom : after.top,
        closeTo(corner < 2 ? before.bottom : before.top, .01),
      );
      await finger.up();
    });
  }

  testWidgets(
    'equal-distance corner targets consistently choose first corner',
    (tester) async {
      await mount(tester, initialBox: RegionBox(.45, .45, .04, .04));
      await tester.tap(find.text('Kuş'));
      await tester.pumpAndSettle();
      final before = tester.getRect(selected);
      final finger = await tester.startGesture(
        Offset(before.center.dx, before.top - 2),
      );
      await finger.moveBy(const Offset(-4, -5));
      await tester.pump();
      final after = tester.getRect(selected);
      expect(after.right, closeTo(before.right, .01));
      expect(after.bottom, closeTo(before.bottom, .01));
      expect(after.width, closeTo(before.width + 4, .01));
      await finger.up();
    },
  );

  testWidgets('small box retains existing minimum resize dimensions', (
    tester,
  ) async {
    await mount(tester, initialBox: RegionBox(.45, .45, .04, .04));
    await tester.tap(find.text('Kuş'));
    await tester.pumpAndSettle();
    final finger = await tester.startGesture(tester.getBottomRight(selected));
    await finger.moveBy(const Offset(-100, -100));
    await tester.pump();
    expectSameBox(tester, [.45, .45, .025, .025]);
    await finger.up();
  });

  for (final gallery in [false, true]) {
    for (final mark in [false, true]) {
      for (final target in ['inside', 'corner', 'outside']) {
        testWidgets(
          'pinch rollback and remaining finger: gallery=$gallery mark=$mark first=$target',
          (tester) async {
            await mount(tester, gallery: gallery);
            await tester.tap(find.text('İşaret'));
            await tester.pumpAndSettle();
            await tester.tap(viewport);
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Yakınlaştır'));
            await tester.pumpAndSettle();
            final corner = tester.getCenter(
              find.byKey(const ValueKey('resize-corner-3')),
            );
            if (!mark) {
              await tester.tap(find.text('Fotoğraf'));
              await tester.pumpAndSettle();
            }
            final before = normalized(tester);
            final firstPosition = target == 'inside'
                ? tester.getCenter(selected)
                : target == 'corner'
                ? corner
                : tester.getTopLeft(viewport) + const Offset(12, 12);
            final first = await tester.startGesture(firstPosition, pointer: 1);
            await first.moveBy(const Offset(3, 4));
            await tester.pump();
            final second = await tester.startGesture(
              tester.getCenter(viewport) + const Offset(-70, 55),
              pointer: 2,
            );
            await tester.pump();
            expectSameBox(tester, before);
            final matrix = transform(tester).value.clone();
            await first.moveBy(const Offset(25, -15));
            await second.moveBy(const Offset(-20, 25));
            await tester.pump();
            expect(transform(tester).value, isNot(matrix));
            expectSameBox(tester, before);
            await second.up();
            await tester.pump();
            final afterPinch = transform(tester).value.clone();
            await first.moveBy(const Offset(30, 30));
            await tester.pump();
            expect(transform(tester).value, afterPinch);
            expectSameBox(tester, before);
            await first.up();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final target in ['inside', 'corner', 'outside']) {
    testWidgets('second finger starts $target and first finger lifts early', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(find.text('İşaret'));
      await tester.pumpAndSettle();
      await tester.tap(viewport);
      await tester.pumpAndSettle();
      final before = normalized(tester);
      final first = await tester.startGesture(
        tester.getTopLeft(viewport) + const Offset(20, 20),
        pointer: 1,
      );
      final second = await tester.startGesture(
        target == 'inside'
            ? tester.getCenter(selected)
            : target == 'corner'
            ? tester.getCenter(find.byKey(const ValueKey('resize-corner-3')))
            : tester.getBottomRight(viewport) - const Offset(20, 20),
        pointer: 2,
      );
      await first.moveBy(const Offset(-15, -15));
      await second.moveBy(const Offset(25, 25));
      await tester.pump();
      expect(transform(tester).value.getMaxScaleOnAxis(), greaterThan(1));
      expectSameBox(tester, before);
      await first.up();
      final matrix = transform(tester).value.clone();
      await second.moveBy(const Offset(-20, -20));
      await tester.pump();
      expect(transform(tester).value, matrix);
      expectSameBox(tester, before);
      await second.up();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('second finger prevents empty tap from creating a region', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    final center = tester.getCenter(viewport);
    final a = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await a.moveBy(const Offset(-40, 0));
    await b.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(transform(tester).value.getMaxScaleOnAxis(), closeTo(2, .001));
    await b.up();
    await a.up();
    await tester.pumpAndSettle();
    expect(selected, findsNothing);
  });

  testWidgets('cancel and mode switch roll back a tentative region drag', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    await tester.tap(viewport);
    await tester.pumpAndSettle();
    final before = normalized(tester);
    var finger = await tester.startGesture(
      tester.getCenter(selected),
      pointer: 1,
    );
    await finger.moveBy(const Offset(8, 7));
    await tester.pump();
    expect(normalized(tester), isNot(before));
    await finger.cancel();
    await tester.pumpAndSettle();
    expectSameBox(tester, before);
    finger = await tester.startGesture(tester.getCenter(selected), pointer: 1);
    await finger.moveBy(const Offset(8, 7));
    await tester.pump();
    await tester.tap(find.text('Fotoğraf'));
    await tester.pumpAndSettle();
    await finger.moveBy(const Offset(25, 20));
    await tester.pump();
    expectSameBox(tester, before);
    await finger.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
