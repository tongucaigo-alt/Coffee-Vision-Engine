import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/photo_view.dart';
import 'package:atlas_contribution_app/src/cropped_photo.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

void main() {
  testWidgets(
    'compact photo preserves aspect and forwards vertical drag to page',
    (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                const Text('Falını Oku'),
                MarkedPhoto(
                  photo: testPhoto(CaptureRole.free),
                  image: MemoryImage(testImage()),
                  maxPreviewHeight: 240,
                ),
                const SizedBox(height: 1100),
                TextButton(onPressed: () {}, child: const Text('Son eylem')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final photo = find.byType(CroppedPhoto);
      final rect = tester.getRect(photo);
      expect(rect.height, closeTo(240, .01));
      expect(rect.width / rect.height, closeTo(160 / 200, .01));
      await tester.dragFrom(rect.center, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(50));
      await tester.scrollUntilVisible(find.text('Son eylem'), 300);
      expect(find.text('Son eylem').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );
}
