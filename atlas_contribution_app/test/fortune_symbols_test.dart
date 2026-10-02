import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'fixtures.dart';

void main() {
  final photo = testPhoto(CaptureRole.free);
  Widget screen({
    bool enabled = true,
    bool reduce = false,
    FortunePhase phase = FortunePhase.generating,
    ContributionPhoto? source,
    List<Offset>? anchors,
    VoidCallback? onCancel,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(
        body: FortuneScan(
          progress: FortuneProgress(phase),
          photos: [source ?? photo],
          imageFor: (_) => MemoryImage(testImage()),
          showDecorativeSymbols: enabled,
          symbolAnchorsFor: anchors == null ? null : (_) => anchors,
          onCancel: onCancel,
        ),
      ),
    ),
  );
  final symbols = find.byKey(const ValueKey('fortune-decorative-symbols'));

  testWidgets('first breath is visible immediately and positions stay stable', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    final opacity = tester
        .widget<Opacity>(
          find.descendant(of: symbols, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity, greaterThan(.5));
    final centres = [
      for (var i = 0; i < 3; i++)
        tester.getCenter(find.byKey(ValueKey('fortune-symbol-$i'))),
    ];
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 3; i++) {
      expect(
        tester.getCenter(find.byKey(ValueKey('fortune-symbol-$i'))),
        centres[i],
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'fallback shows three decorative symbols and allows cancellation',
    (tester) async {
      var cancelled = false;
      await tester.pumpWidget(screen(onCancel: () => cancelled = true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(symbols, findsOneWidget);
      expect(
        find.descendant(of: symbols, matching: find.byType(Icon)),
        findsNWidgets(3),
      );
      final initial = tester
          .widget<Transform>(
            find
                .descendant(of: symbols, matching: find.byType(Transform))
                .first,
          )
          .transform
          .entry(0, 0);
      await tester.pump(const Duration(milliseconds: 500));
      final next = tester
          .widget<Transform>(
            find
                .descendant(of: symbols, matching: find.byType(Transform))
                .first,
          )
          .transform
          .entry(0, 0);
      expect(next, isNot(initial));
      await tester.scrollUntilVisible(find.text('Durdur'), 300);
      await tester.tap(find.text('Durdur'));
      expect(cancelled, isTrue);
      expect(photo.regions, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ten symbol types rotate without duplicates or exceeding three slots',
    (tester) async {
      await tester.pumpWidget(screen());
      final seen = <IconData>{};
      for (var breath = 0; breath < 5; breath++) {
        final icons = tester
            .widgetList<Icon>(
              find.descendant(of: symbols, matching: find.byType(Icon)),
            )
            .map((icon) => icon.icon!)
            .toSet();
        expect(icons, hasLength(3));
        seen.addAll(icons);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(seen, {
        for (final label in [
          'fish',
          'heart',
          'eye',
          'bird',
          'moon',
          'sun',
          'tree',
          'flower',
          'crown',
          'anchor',
        ])
          labelIcons[label]!,
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'symbols scatter inside scan ring, move on respawn and handle invalid anchors',
    (tester) async {
      final cropped = ContributionPhoto.fromJson({
        ...photo.toJson(),
        'displayCrop': PhotoCrop(.2, .2, .6, .6).toJson(),
      });
      await tester.pumpWidget(
        screen(
          source: cropped,
          anchors: const [
            Offset(.5, .5),
            Offset(double.nan, .3),
            Offset(.01, .01),
          ],
        ),
      );
      await tester.pump();
      expect(
        find.descendant(of: symbols, matching: find.byType(Icon)),
        findsNWidgets(3),
      );
      final centre = tester.getCenter(
        find.byKey(const ValueKey('fortune-symbol-0')),
      );
      final area = tester.getRect(symbols);
      expect(
        (centre - area.center).distance,
        lessThanOrEqualTo(area.shortestSide * .36),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));
      final respawn = tester.getCenter(
        find.byKey(const ValueKey('fortune-symbol-0')),
      );
      expect((respawn - centre).distance, greaterThan(1));
      await tester.pumpWidget(
        screen(source: cropped, anchors: const [Offset(.01, .01)]),
      );
      await tester.pump();
      expect(
        find.descendant(of: symbols, matching: find.byType(Icon)),
        findsNWidgets(3),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('decorations are opt-in and disabled for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(screen(enabled: false));
    expect(symbols, findsNothing);
    await tester.pumpWidget(screen(reduce: true));
    await tester.pumpAndSettle();
    expect(symbols, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final phase in [
    FortunePhase.completed,
    FortunePhase.failed,
    FortunePhase.cancelled,
  ]) {
    testWidgets('decorations disappear when preparation ends: $phase', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      expect(symbols, findsOneWidget);
      await tester.pumpWidget(screen(phase: phase));
      await tester.pumpAndSettle();
      expect(symbols, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
