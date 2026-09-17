import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'fixtures.dart';

void main() {
  testWidgets(
    'selected box survives photo pan, centered zoom and mode changes',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ContributionPhoto? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: contributionTheme(),
          home: AnnotationPage(
            photo: testPhoto(CaptureRole.top),
            image: MemoryImage(testImage()),
            onSave: (p) async {
              saved = p;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('annotation-canvas'));
      final viewer = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      expect(find.byKey(const ValueKey('annotation-viewport')), findsOneWidget);
      await tester.tap(canvas);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selected-region')), findsNothing);
      await tester.tap(find.text('İşaret'));
      await tester.pumpAndSettle();
      await tester.tap(canvas);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('move-region-handle')), findsNothing);
      await tester.tap(find.byTooltip('Yakınlaştır'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fotoğraf'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resize-corner-0')), findsNothing);
      final beforePan = controller.value.clone();
      await tester.drag(viewer, const Offset(-20, -25));
      await tester.pumpAndSettle();
      expect(controller.value, isNot(beforePan));
      final center = tester.getSize(viewer).center(Offset.zero);
      final focalPoint = controller.toScene(center);
      await tester.tap(find.byTooltip('Yakınlaştır'));
      await tester.pumpAndSettle();
      expect((controller.toScene(center) - focalPoint).distance, lessThan(.01));
      await tester.tap(find.text('İşaret'));
      await tester.pumpAndSettle();
      expect(tester.widget<InteractiveViewer>(viewer).panEnabled, false);
      await tester.tap(find.byTooltip('Fotoğrafı sığdır'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(800, 412);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Bu alanı seç'));
      await tester.tap(find.text('Bu alanı seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kuş'));
      await tester.pumpAndSettle();
      final b = saved!.regions.single.box;
      expect(b.x, closeTo(.425, .001));
      expect(b.y, closeTo(.425, .001));
      expect(b.width, .15);
      expect(b.height, .15);
    },
  );
  for (final zoom in [false, true]) {
    testWidgets(
      'short region drag is immediate without scrolling, zoom=$zoom',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: contributionTheme(),
            home: AnnotationPage(
              photo: testPhoto(CaptureRole.top),
              image: MemoryImage(testImage()),
              onSave: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('İşaret'));
        await tester.pumpAndSettle();
        if (zoom) {
          await tester.tap(find.byTooltip('Yakınlaştır'));
          await tester.pumpAndSettle();
        }
        final canvas = find.byKey(const ValueKey('annotation-canvas'));
        await tester.tapAt(tester.getTopLeft(canvas) + const Offset(150, 170));
        await tester.pumpAndSettle();
        final box = find.byKey(const ValueKey('selected-region'));
        final before = tester.getRect(box);
        final imageOrigin = tester.getTopLeft(canvas);
        final finger = await tester.startGesture(tester.getCenter(box));
        await finger.moveBy(const Offset(4, 6));
        await tester.pump();
        expect(tester.getRect(box).left, closeTo(before.left + 4, .1));
        expect(tester.getRect(box).top, closeTo(before.top + 6, .1));
        await finger.moveBy(const Offset(24, 44));
        await tester.pump();
        expect(tester.getRect(box).left, closeTo(before.left + 28, .1));
        expect(tester.getRect(box).top, closeTo(before.top + 50, .1));
        expect(tester.getRect(box).width, closeTo(before.width, .001));
        expect(tester.getRect(box).height, closeTo(before.height, .001));
        expect(tester.getTopLeft(canvas), imageOrigin);
        await finger.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'corner resize responds to a short drag and keeps opposite corner',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: contributionTheme(),
          home: AnnotationPage(
            photo: testPhoto(CaptureRole.top),
            image: MemoryImage(testImage()),
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('İşaret'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('annotation-canvas')));
      await tester.pumpAndSettle();
      final box = find.byKey(const ValueKey('selected-region'));
      final before = tester.getRect(box);
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('resize-corner-3'))),
      );
      await finger.moveBy(const Offset(5, 7));
      await tester.pump();
      expect(tester.getRect(box).topLeft, before.topLeft);
      expect(tester.getRect(box).width, closeTo(before.width + 5, .1));
      expect(tester.getRect(box).height, closeTo(before.height + 7, .1));
      await finger.up();
    },
  );
  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'annotation and 20-symbol picker ${size.width} scale $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          ContributionPhoto? saved;
          await tester.pumpWidget(
            MaterialApp(
              theme: contributionTheme(),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: AnnotationPage(
                photo: testPhoto(CaptureRole.top),
                image: MemoryImage(testImage()),
                onSave: (p) async {
                  saved = p;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('İşaret'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('annotation-canvas')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Bu alanı seç'));
          await tester.tap(find.text('Bu alanı seç'));
          await tester.pumpAndSettle();
          expect(find.byType(LabelPicker), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('İnsan Figürü'),
            280,
            scrollable: find.descendant(
              of: find.byType(LabelPicker),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(GridView), const Offset(0, 3500));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Kuş'));
          await tester.pumpAndSettle();
          expect(saved!.regions.single.label, 'bird');
          expect(saved!.decision, PhotoDecision.marked);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('three abstention options and region uncertainty stay separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: AnnotationPage(
          photo: testPhoto(CaptureRole.top),
          image: MemoryImage(testImage()),
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Emin değilim'), findsOneWidget);
    expect(find.text('Şimdilik geç'), findsOneWidget);
    expect(find.text('Bu fotoğrafta şekil seçemedim'), findsOneWidget);
  });
  testWidgets('zoomed movement preserves image-space displacement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ContributionPhoto? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: AnnotationPage(
          photo: testPhoto(CaptureRole.top),
          image: MemoryImage(testImage()),
          onSave: (p) async {
            saved = p;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yakınlaştır'));
    await tester.pumpAndSettle();
    final canvas = find.byKey(const ValueKey('annotation-canvas'));
    final render = tester.renderObject<RenderBox>(canvas);
    final center = render.localToGlobal(
      Offset(render.size.width * .4, render.size.height * .4),
    );
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    final selectedCenter = tester.getCenter(
      find.byKey(const ValueKey('selected-region')),
    );
    expect(selectedCenter.dx, closeTo(center.dx, 1));
    expect(selectedCenter.dy, closeTo(center.dy, 1));
    await tester.dragFrom(selectedCenter, const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bu alanı seç'));
    await tester.tap(find.text('Bu alanı seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuş'));
    await tester.pumpAndSettle();
    final expected = .325 + 60 / (render.size.width * 1.25);
    expect(saved!.regions.single.box.x, closeTo(expected, .025));
  });
}
