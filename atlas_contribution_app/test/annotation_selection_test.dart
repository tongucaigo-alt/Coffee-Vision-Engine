import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

final _canvas = find.byKey(const ValueKey('annotation-canvas'));
final _selected = find.byKey(const ValueKey('selected-region'));
final _birdChip = find.widgetWithText(ChoiceChip, 'Kuş');

ContributionPhoto _photo() => testPhoto(
  CaptureRole.top,
  decision: PhotoDecision.marked,
  regions: [
    RegionAnnotation(id: 'bird', box: RegionBox(.2, .3, .2, .2), label: 'bird'),
    RegionAnnotation(
      id: 'star',
      box: RegionBox(.65, .6, .2, .2),
      label: 'star',
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  ContributionPhoto photo,
  Future<void> Function(ContributionPhoto) save, {
  double width = 384,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 832);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: coffeeFlowTheme(atlasTheme()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: AnnotationPage(
        modern: true,
        photo: photo,
        image: MemoryImage(testImage()),
        onSave: save,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset _center(WidgetTester tester, RegionAnnotation region) {
  final image = tester.getRect(_canvas);
  return image.topLeft +
      Offset(
        image.width * (region.box.x + region.box.width / 2),
        image.height * (region.box.y + region.box.height / 2),
      );
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'Literata': 'assets/brand/Literata.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final chip in [true, false]) {
        testWidgets(
          'repeat ${chip ? 'chip' : 'photo'} tap clears selection only at $width / $scale',
          (tester) async {
            var photo = _photo();
            final before = jsonEncode(photo.toJson());
            var saves = 0;
            await _mount(
              tester,
              photo,
              (next) async {
                saves++;
                photo = next;
              },
              width: width,
              scale: scale,
            );
            final point = _center(tester, photo.regions.first);
            for (final selected in [true, false, true]) {
              if (chip) {
                await tester.tap(_birdChip);
              } else {
                await tester.tapAt(point);
              }
              await tester.pumpAndSettle();
              expect(_selected, selected ? findsOneWidget : findsNothing);
              expect(tester.widget<ChoiceChip>(_birdChip).selected, selected);
              expect(
                find.byKey(const ValueKey('coffee-selected-name')),
                selected ? findsOneWidget : findsNothing,
              );
              expect(jsonEncode(photo.toJson()), before);
              expect(saves, 0);
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }

  testWidgets('tapping a different mark switches selection without saving', (
    tester,
  ) async {
    final photo = _photo();
    var saves = 0;
    await _mount(tester, photo, (_) async => saves++);
    await tester.tap(_birdChip);
    await tester.pumpAndSettle();
    await tester.tapAt(_center(tester, photo.regions.last));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(_birdChip).selected, false);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('coffee-selected-name')),
        matching: find.text('Yıldız'),
      ),
      findsOneWidget,
    );
    expect(_selected, findsOneWidget);
    expect(saves, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final gesture in ['drag', 'pinch', 'cancel']) {
    testWidgets('$gesture does not become a deselection tap', (tester) async {
      var photo = _photo();
      final before = jsonEncode(photo.toJson());
      var saves = 0;
      await _mount(tester, photo, (next) async {
        saves++;
        photo = next;
      });
      await tester.tap(_birdChip);
      await tester.pumpAndSettle();
      final center = tester.getCenter(_selected);
      final first = await tester.startGesture(center, pointer: 1);
      if (gesture == 'pinch') {
        final second = await tester.startGesture(
          center + const Offset(50, 0),
          pointer: 2,
        );
        await first.moveBy(const Offset(-20, 0));
        await second.moveBy(const Offset(20, 0));
        await first.up();
        await second.up();
      } else {
        await first.moveBy(const Offset(28, 20));
        if (gesture == 'cancel') {
          await first.cancel();
        } else {
          await first.up();
        }
      }
      await tester.pumpAndSettle();
      if (gesture == 'drag') {
        expect(saves, 1);
        expect(photo.regions.first.id, 'bird');
        expect(photo.regions.first.box.x, greaterThan(.2));
        expect(photo.regions.first.box.y, greaterThan(.3));
        expect(photo.regions.last.toJson(), _photo().regions.last.toJson());
      } else {
        expect(_selected, findsOneWidget);
        expect(tester.widget<ChoiceChip>(_birdChip).selected, true);
        expect(saves, 0);
        expect(jsonEncode(photo.toJson()), before);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'deselection keeps marks until explicit removal after reselection',
    (tester) async {
      var photo = _photo();
      var saves = 0;
      await _mount(tester, photo, (next) async {
        saves++;
        photo = next;
      });
      await tester.tap(_birdChip);
      await tester.pumpAndSettle();
      await tester.tap(_birdChip);
      await tester.pumpAndSettle();
      expect(find.text('Kaldır'), findsNothing);
      expect(photo.regions, hasLength(2));
      expect(saves, 0);
      await tester.tap(_birdChip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaldır'));
      await tester.pumpAndSettle();
      expect(photo.regions.single.id, 'star');
      expect(photo.decision, PhotoDecision.marked);
      expect(saves, 1);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Yıldız'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaldır'));
      await tester.pumpAndSettle();
      expect(photo.regions, isEmpty);
      expect(photo.decision, PhotoDecision.unreviewed);
      expect(saves, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
