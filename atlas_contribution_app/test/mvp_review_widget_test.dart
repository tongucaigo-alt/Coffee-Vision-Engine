import 'dart:io';

import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_page.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'mvp_review_test.dart' show fakeEngine;

void main() {
  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'review layout $size scale $scale, truthful user-only input',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          late Directory temp;
          late ReviewStore store;
          late ReviewSession session;
          await tester.runAsync(() async {
            temp = await Directory.systemTemp.createTemp('atlas-mvp-widget-');
            store = ReviewStore(Directory('${temp.path}/reviews'));
            await store.initialize();
            final p = await store.importPhoto(
              testImage(),
              surface: ReviewSurface.cup,
            );
            session = ReviewSession(
              id: 'test-review',
              groupId: 'test-group',
              createdAtUtc: '2026-09-14T00:00:00Z',
              localConsentAtUtc: '2026-09-14T00:00:00Z',
              sameSampleDeclared: true,
              photos: [
                p.update(
                  confirmedAt: '2026-09-14T00:00:00Z',
                  photo: p.photo.annotated([
                    RegionAnnotation(
                      id: 'test-user-tree',
                      box: RegionBox(.1, .1, .3, .3),
                      label: 'tree',
                    ),
                  ], PhotoDecision.marked),
                ),
              ],
            );
            await store.save(session);
          });
          addTearDown(() async => temp.delete(recursive: true));
          await tester.pumpWidget(
            MaterialApp(
              theme: contributionTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ReviewPage(
                controller: ReviewController(store: store, session: session),
                captureStore: DraftStore(
                  Directory('${temp.path}/old-contributions'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Fincan incelemesi'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('İşaretlerin ilk yorum öncesinde kaydedilecek.'),
            250,
          );
          expect(find.text('1 kullanıcı işareti'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('empty session cannot analyze, research checkbox is opt-in', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('atlas-mvp-empty-'),
    ))!;
    addTearDown(() => temp.delete(recursive: true));
    final s = ReviewSession(
      id: 'test-review',
      groupId: 'test-group',
      createdAtUtc: '2026-09-14T00:00:00Z',
      localConsentAtUtc: '2026-09-14T00:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: ReviewPage(
          controller: ReviewController(store: ReviewStore(temp), session: s),
          captureStore: DraftStore(temp),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final analyze = find.widgetWithText(FilledButton, 'İncelemeyi tamamla');
    expect(tester.widget<FilledButton>(analyze).onPressed, isNull);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((c) => c.value == false),
      true,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'skip completes locally and technical details show only prepared payload',
    (tester) async {
      late Directory temp;
      late ReviewStore store;
      late ReviewSession session;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('atlas-part1-widget-');
        store = ReviewStore(temp);
        await store.initialize();
        final photo = await store.importPhoto(
          testImage(),
          surface: ReviewSurface.cup,
        );
        session = ReviewSession(
          id: 'test-skip',
          groupId: 'private-group',
          createdAtUtc: '2026-09-15T00:00:00Z',
          localConsentAtUtc: '2026-09-15T00:00:00Z',
          sameSampleDeclared: true,
          photos: [photo.update(confirmedAt: '2026-09-15T00:00:00Z')],
        );
        await store.save(session);
      });
      addTearDown(() => temp.delete(recursive: true));
      var setupFails = true;
      final controller = ReviewController(
        store: store,
        session: session,
        loadEngine: () async {
          if (setupFails) throw StateError('fixture setup failure');
          return fakeEngine();
        },
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: contributionTheme(),
            home: ReviewPage(
              controller: controller,
              captureStore: DraftStore(temp),
            ),
          ),
        );
        await precacheImage(
          FileImage(store.file(session.photos.single.photo.localName)),
          tester.element(find.byType(ReviewPage)),
        );
      });
      await tester.pumpAndSettle();
      final complete = find.widgetWithText(FilledButton, 'İncelemeyi tamamla');
      await tester.scrollUntilVisible(complete, 250);
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      await tester.runAsync(() async {
        tester.widget<FilledButton>(complete).onPressed!();
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (controller.busy && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(
        controller.session.photos.single.photo.decision,
        PhotoDecision.skipped,
      );
      expect(controller.session.currentInitialObservation, isNotNull);
      expect(controller.session.preparedInput, isNotNull);
      expect(controller.session.preparedInput!['status'], 'analysisPending');
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      setupFails = false;
      await tester.runAsync(() async {
        tester.widget<FilledButton>(complete).onPressed!();
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (controller.busy && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(controller.session.preparedInput!['status'], 'empty');
      await tester.scrollUntilVisible(find.text('Teknik ayrıntılar'), 100);
      await tester.tap(find.text('Teknik ayrıntılar'));
      await tester.pumpAndSettle();
      expect(find.text('Hazırlanan AI girdisi'), findsOneWidget);
      final jsonText = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .single
          .data!;
      expect(jsonText, isNot(contains('private-group')));
      expect(jsonText, isNot(contains(session.photos.single.photo.localName)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
