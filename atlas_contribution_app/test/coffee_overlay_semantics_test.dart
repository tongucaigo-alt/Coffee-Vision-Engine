import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/photo_navigation.dart';

void main() {
  testWidgets(
    'compact photo arrows retain accessible names, actions and 48dp targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PhotoNavigation(
                index: 0,
                count: 2,
                overlay: true,
                onSelect: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      final next = find.byKey(const ValueKey('coffee-next-photo'));
      final previous = find.byKey(const ValueKey('coffee-previous-photo'));
      expect(
        tester.getSemantics(next),
        isSemantics(
          label: 'Sonraki fotoğraf',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(previous),
        isSemantics(label: 'Önceki fotoğraf', isButton: true, isEnabled: false),
      );
      expect(tester.getSize(next), const Size(48, 48));
      // Edge of the transparent target, outside the smaller visible surface.
      await tester.tapAt(tester.getRect(next).topLeft + const Offset(2, 2));
      expect(selected, 1);
      semantics.dispose();
    },
  );
}
