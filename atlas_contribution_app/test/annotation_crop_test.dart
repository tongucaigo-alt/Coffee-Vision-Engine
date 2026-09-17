import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/cropped_photo.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'fixtures.dart';

final _viewport = find.byKey(const ValueKey('annotation-viewport'));
final _canvas = find.byKey(const ValueKey('annotation-canvas'));
final _selected = find.byKey(const ValueKey('selected-region'));
final _crop = PhotoCrop(.2, .1, .6, .5);

Future<void> _mount(
  WidgetTester tester, {
  PhotoCrop? crop,
  ContributionPhoto? photo,
  Future<void> Function(ContributionPhoto)? onSave,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: contributionTheme(),
      home: AnnotationPage(
        key: UniqueKey(),
        photo: photo ?? testPhoto(CaptureRole.top),
        image: MemoryImage(testImage()),
        displayCrop: crop,
        onSave: onSave ?? (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveBird(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Bu alanı seç'));
  await tester.tap(find.text('Bu alanı seç'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(LabelPicker), matching: find.text('Kuş')),
  );
  await tester.pumpAndSettle();
}

ContributionPhoto _marked(RegionBox box) => testPhoto(
  CaptureRole.top,
  decision: PhotoDecision.marked,
  regions: [RegionAnnotation(id: 'bird-region', box: box, label: 'bird')],
);

void _expectBox(RegionBox actual, RegionBox expected) {
  for (final field in ['x', 'y', 'width', 'height']) {
    expect(actual.toJson()[field], closeTo(expected.toJson()[field], 1e-9));
  }
}

void main() {
  testWidgets(
    'shared cropped display uses exact source bounds and aspect ratio',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 240,
              child: CroppedPhoto(
                image: MemoryImage(testImage()),
                photoWidth: 160,
                photoHeight: 200,
                crop: _crop,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final display = tester.getRect(find.byType(CroppedPhoto));
      final image = tester.getRect(find.byType(Image));
      expect(display.width / display.height, closeTo(.96, 1e-10));
      expect(image.width, closeTo(display.width / _crop.width, 1e-10));
      expect(image.height, closeTo(display.height / _crop.height, 1e-10));
      expect(image.left + _crop.x * image.width, closeTo(display.left, 1e-10));
      expect(image.top + _crop.y * image.height, closeTo(display.top, 1e-10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cropped annotation saves canonical boxes and reopens same view',
    (tester) async {
      ContributionPhoto? saved;
      await _mount(tester, crop: _crop, onSave: (photo) async => saved = photo);
      final size = tester.getSize(_canvas);
      expect(size.aspectRatio, closeTo(.96, 1e-10));
      await tester.tap(find.text('İşaret'));
      await tester.pumpAndSettle();
      await tester.tap(_viewport);
      await tester.pumpAndSettle();
      final firstRect = tester.getRect(_selected);
      await _saveBird(tester);
      _expectBox(
        saved!.regions.single.box,
        _crop.toFullBox(RegionBox(.425, .425, .15, .15)),
      );
      await _mount(tester, crop: _crop, photo: saved);
      await tester.tap(find.text('Kuş'));
      await tester.pumpAndSettle();
      final reopened = tester.getRect(_selected);
      expect((reopened.topLeft - firstRect.topLeft).distance, lessThan(.01));
      expect(reopened.width, closeTo(firstRect.width, .01));
      expect(reopened.height, closeTo(firstRect.height, .01));
    },
  );

  testWidgets('zoomed crop move and resize persist in full-photo coordinates', (
    tester,
  ) async {
    final sourceBox = _crop.toFullBox(RegionBox(.35, .35, .2, .2));
    ContributionPhoto? saved;
    await _mount(
      tester,
      crop: _crop,
      photo: _marked(sourceBox),
      onSave: (photo) async => saved = photo,
    );
    await tester.tap(find.text('Kuş'));
    await tester.tap(find.byTooltip('Yakınlaştır'));
    await tester.pumpAndSettle();
    final image = tester.getRect(_canvas);
    final initial = tester.getRect(_selected);
    var finger = await tester.startGesture(initial.center);
    await finger.moveBy(const Offset(10, 7));
    await finger.up();
    await tester.pumpAndSettle();
    var changed = tester.getRect(_selected);
    expect(changed.left, closeTo(initial.left + 10, .01));
    expect(changed.top, closeTo(initial.top + 7, .01));
    finger = await tester.startGesture(changed.bottomRight);
    await finger.moveBy(const Offset(8, 6));
    await finger.up();
    await tester.pumpAndSettle();
    changed = tester.getRect(_selected);
    expect(changed.width, closeTo(initial.width + 8, .01));
    expect(changed.height, closeTo(initial.height + 6, .01));
    await _saveBird(tester);
    _expectBox(
      saved!.regions.single.box,
      RegionBox(
        sourceBox.x + 10 / image.width * _crop.width,
        sourceBox.y + 7 / image.height * _crop.height,
        sourceBox.width + 8 / image.width * _crop.width,
        sourceBox.height + 6 / image.height * _crop.height,
      ),
    );
  });

  testWidgets('cropped pinch and cancellation preserve canonical annotation', (
    tester,
  ) async {
    final sourceBox = _crop.toFullBox(RegionBox(.4, .4, .15, .15));
    ContributionPhoto? saved;
    await _mount(
      tester,
      crop: _crop,
      photo: _marked(sourceBox),
      onSave: (photo) async => saved = photo,
    );
    await tester.tap(find.text('Kuş'));
    await tester.pumpAndSettle();
    var first = await tester.startGesture(
      tester.getCenter(_selected),
      pointer: 1,
    );
    await first.moveBy(const Offset(7, 8));
    await tester.pump();
    await first.cancel();
    await tester.pumpAndSettle();
    first = await tester.startGesture(tester.getCenter(_selected), pointer: 1);
    await first.moveBy(const Offset(6, 9));
    final second = await tester.startGesture(
      tester.getCenter(_viewport) + const Offset(-60, 50),
      pointer: 2,
    );
    await first.moveBy(const Offset(20, -10));
    await second.moveBy(const Offset(-20, 20));
    await tester.pump();
    await second.up();
    await first.moveBy(const Offset(30, 20));
    await first.up();
    await tester.pumpAndSettle();
    await _saveBird(tester);
    _expectBox(saved!.regions.single.box, sourceBox);
  });

  testWidgets(
    'outside annotation falls back to full image without truncation',
    (tester) async {
      final outside = RegionBox(.05, .1, .25, .25);
      ContributionPhoto? saved;
      await _mount(
        tester,
        crop: _crop,
        photo: _marked(outside),
        onSave: (photo) async => saved = photo,
      );
      expect(tester.getSize(_canvas).aspectRatio, closeTo(.8, 1e-10));
      expect(
        tester.widget<CroppedPhoto>(find.byType(CroppedPhoto)).crop!.isFull,
        true,
      );
      await tester.tap(find.text('Kuş'));
      await tester.pumpAndSettle();
      await _saveBird(tester);
      _expectBox(saved!.regions.single.box, outside);
    },
  );
}
