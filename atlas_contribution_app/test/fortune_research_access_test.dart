import 'dart:io';
import 'photo_set_test.dart' show setImage;
import 'package:atlas_contribution_app/src/trace_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';

void main({Future<void> Function(String)? capture}) {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'ordinary story remains readable without research controls at scale $scale',
      (tester) async {
        if (capture == null) {
          tester.view.physicalSize = const Size(360, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
        late Directory temp;
        late AiRuntime runtime;
        late ReviewSession session;
        var nativeCalls = 0;
        const channel = MethodChannel('atlas.photo/suitability');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              nativeCalls++;
              throw PlatformException(code: 'unexpected');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await tester.runAsync(() async {
          temp = await Directory.systemTemp.createTemp(
            'atlas-research-access-',
          );
          final store = DraftStore(Directory('${temp.path}/source'));
          await store.initialize();
          runtime = await AiRuntime.create(store, readKey: (_) async => '');
          final photo = await store.importGallery(setImage(0));
          await runtime.reviews
              .file(photo.localName)
              .parent
              .create(recursive: true);
          await store
              .file(photo.localName)
              .copy(runtime.reviews.file(photo.localName).path);
          session = ReviewSession(
            id: 'access',
            groupId: 'group',
            createdAtUtc: '2026-10-02T00:00:00Z',
            localConsentAtUtc: '2026-10-02T00:00:00Z',
            photos: [
              ReviewPhoto(
                id: 'photo-one',
                photo: photo,
                surface: ReviewSurface.cup,
              ),
            ],
            sameSampleDeclared: true,
          );
          await runtime.reviews.save(session);
          await runtime.store.saveResult({
            'id': 'result',
            'sessionId': session.id,
            'groupId': session.groupId,
            'createdAtUtc': '2026-10-02T00:00:00Z',
            'state': 'completed',
            'sourceFingerprint': 'old',
            'context': {'photos': []},
            'answers': [
              {
                'text': List.generate(
                  4,
                  (i) => List.filled(
                    30,
                    'Sakin bir düşünce sana eşlik edebilir.',
                  ).join(' '),
                ).join('\n\n'),
                'model': 'test',
                'durationMs': 1,
              },
            ],
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: atlasTheme(),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('coffee-test-surface'),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(bottom: 32),
                    viewPadding: const EdgeInsets.only(bottom: 32),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              ),
              home: AiFortunePage(
                runtime: runtime,
                session: session,
                simple: true,
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pumpAndSettle();
        final photoTop = tester.getTopLeft(find.byType(TracePhoto)).dy;
        final vertical = find
            .descendant(
              of: find.byWidgetPredicate(
                (w) => w is ListView && w.scrollDirection == Axis.vertical,
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(FortuneStory),
          150,
          scrollable: vertical,
        );
        final position = tester.state<ScrollableState>(vertical).position;
        expect(
          photoTop,
          lessThan(
            tester.getTopLeft(find.byType(FortuneStory).first).dy +
                position.pixels,
          ),
        );
        position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TracePhoto));
        await tester.pumpAndSettle();
        expect(find.text('Kapat').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();
        if (capture != null) await capture('story-fixture-${scale.toInt()}');
        for (var i = 0; i < 20; i++) {
          await tester.dragFrom(const Offset(180, 540), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(find.text('Araştırmaya katkı'), findsNothing);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          (await tester.runAsync(
            () => runtime.reviews.sessions(),
          ))!.single.researchConsentAtUtc,
          isNull,
        );
        expect(
          nativeCalls,
          0,
          reason: 'Reading an old fortune must not classify or produce again',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => temp.delete(recursive: true));
      },
    );
  }
}
