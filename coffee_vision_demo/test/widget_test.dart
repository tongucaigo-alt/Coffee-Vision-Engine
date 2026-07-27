import 'package:coffee_vision/coffee_vision.dart';
import 'package:coffee_vision_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with cup selected and analysis disabled', (tester) async {
    await tester.pumpWidget(const CoffeeVisionDemoApp(restoreLostData: false));

    expect(find.text('Coffee Vision Density Debug'), findsOneWidget);
    expect(find.text('Görsel seçilmedi'), findsOneWidget);
    expect(find.text('Fincan'), findsOneWidget);
    expect(find.text('Tabak'), findsOneWidget);

    final analyzeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Analiz Et'),
    );
    expect(analyzeButton.onPressed, isNull);

    final selector = tester.widget<SegmentedButton<VisionSurfaceType>>(
      find.byType(SegmentedButton<VisionSurfaceType>),
    );
    expect(selector.selected, {VisionSurfaceType.cup});
  });

  testWidgets('allows switching the selected surface', (tester) async {
    await tester.pumpWidget(const CoffeeVisionDemoApp(restoreLostData: false));

    await tester.tap(find.text('Tabak'));
    await tester.pump();

    final selector = tester.widget<SegmentedButton<VisionSurfaceType>>(
      find.byType(SegmentedButton<VisionSurfaceType>),
    );
    expect(selector.selected, {VisionSurfaceType.saucer});
  });
}
