import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_sequence.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Literata', 'assets/brand/Literata.ttf'),
      ('Plus Jakarta Sans', 'assets/brand/PlusJakartaSans.ttf'),
      (
        'packages/lucide_icons_flutter/Lucide',
        'packages/lucide_icons_flutter/assets/lucide.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  testWidgets(
    'canonical focus persists across reopen without touching photos',
    (tester) async {
      var stored = 'money';
      final changes = <String>[];
      final photos = [
        testPhoto(CaptureRole.top),
        testPhoto(CaptureRole.handleRight),
      ];
      final before = photos.map((p) => p.toJson()).toList();
      var saves = 0;
      Future<void> mount() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: atlasTheme(),
            home: AnnotationSequence(
              initialFocus: stored,
              onFocusChanged: (focus) async {
                stored = focus;
                changes.add(focus);
              },
              photos: photos,
              imageFor: (_) => MemoryImage(testImage()),
              onSave: (_) async {
                saves++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      String? selection() => tester
          .widget<AnnotationPage>(find.byType(AnnotationPage))
          .selectedFocus;
      await mount();
      expect(selection(), 'Para');
      await tester.tap(find.byKey(const ValueKey('coffee-focus-Aşk')));
      await tester.pumpAndSettle();
      expect(stored, 'love');
      await mount();
      expect(selection(), 'Aşk');
      await tester.tap(find.byKey(const ValueKey('coffee-next-photo')));
      await tester.pumpAndSettle();
      expect(selection(), 'Aşk');
      await tester.tap(find.byKey(const ValueKey('coffee-focus-Aşk')));
      await tester.pumpAndSettle();
      expect(stored, 'general');
      await mount();
      expect(selection(), isNull);
      expect(changes, ['love', 'general']);
      expect(saves, 0);
      expect(photos.map((p) => p.toJson()).toList(), before);
    },
  );

  testWidgets(
    'focus write blocks finish and keeps the previous value on failure',
    (tester) async {
      final write = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          home: AnnotationSequence(
            initialFocus: 'work',
            onFocusChanged: (_) => write.future,
            photos: [testPhoto(CaptureRole.top)],
            imageFor: (_) => MemoryImage(testImage()),
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('coffee-focus-Aşk')));
      await tester.pump();
      var page = tester.widget<AnnotationPage>(find.byType(AnnotationPage));
      expect(page.selectedFocus, 'İş');
      expect(page.focusBusy, true);
      expect(page.onFinish, isNull);
      expect(page.onSaveOnly, isNull);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).first).canPop,
        false,
      );
      write.completeError(StateError('synthetic preference write failure'));
      await tester.pumpAndSettle();
      page = tester.widget<AnnotationPage>(find.byType(AnnotationPage));
      expect(page.selectedFocus, 'İş');
      expect(page.focusBusy, false);
      expect(page.onFinish, isNotNull);
      expect(
        find.text('Konu seçimin kaydedilemedi. Yeniden deneyebilirsin.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('focus is optional and shared across photos: $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final photos = [
          testPhoto(CaptureRole.top),
          testPhoto(CaptureRole.handleRight),
        ];
        final before = photos.map((p) => p.toJson()).toList();
        var saves = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: atlasTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('focus-preview'),
              child: AnnotationSequence(
                photos: photos,
                imageFor: (_) => MemoryImage(testImage()),
                onSave: (_) async {
                  saves++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final frame = tester.getRect(
          find.byKey(const ValueKey('coffee-photo-frame')),
        );
        final mode = tester.getRect(
          find.byKey(const ValueKey('coffee-mode-control')),
        );
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          isNull,
        );
        final love = find.byKey(const ValueKey('coffee-focus-Aşk'));
        final work = find.byKey(const ValueKey('coffee-focus-İş'));
        final modeSurface = tester.getRect(
          find.byKey(const ValueKey('coffee-mode-surface-true')),
        );
        for (final label in ['Aşk', 'İş', 'Para']) {
          final surface = tester.getRect(
            find.byKey(ValueKey('coffee-focus-surface-$label')),
          );
          expect(surface.center.dy, closeTo(modeSurface.center.dy, .1));
          expect(surface.bottom, lessThanOrEqualTo(frame.top));
        }
        if (scale == 1) {
          for (final label in ['Aşk', 'İş', 'Para']) {
            final choice = find.byKey(ValueKey('coffee-focus-$label'));
            expect(choice.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(choice).left,
              greaterThanOrEqualTo(mode.right),
            );
            expect(tester.getRect(choice).bottom, lessThanOrEqualTo(frame.top));
          }
        }
        await tester.ensureVisible(love);
        await tester.tap(love);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          'Aşk',
        );
        await tester.tap(find.byKey(const ValueKey('coffee-next-photo')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          'Aşk',
        );
        await tester.ensureVisible(work);
        await tester.tap(work);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          'İş',
        );
        await tester.tap(find.byKey(const ValueKey('coffee-previous-photo')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          'İş',
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('coffee-photo-frame'))),
          frame,
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('coffee-mode-control'))),
          mode,
        );
        const screenshot = String.fromEnvironment('ATLAS_FOCUS_SCREENSHOT');
        if (screenshot.isNotEmpty && width == 412 && scale == 1) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('focus-preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(screenshot).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(work);
        await tester.tap(work);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnnotationPage>(find.byType(AnnotationPage))
              .selectedFocus,
          isNull,
        );
        expect(saves, 0);
        expect(photos.map((p) => p.toJson()).toList(), before);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
