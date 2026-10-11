import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'long story scrolls from text to expanded research at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
          session = ReviewSession(
            id: 'access',
            groupId: 'group',
            createdAtUtc: '2026-10-02T00:00:00Z',
            localConsentAtUtc: '2026-10-02T00:00:00Z',
            photos: [],
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(bottom: 32),
                  viewPadding: const EdgeInsets.only(bottom: 32),
                  disableAnimations: true,
                ),
                child: child!,
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
        final title = find.text('Araştırmaya katkı');
        // Deliberately drag over story text, never the outer padding.
        for (
          var i = 0;
          i < 100 && title.hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.dragFrom(const Offset(180, 540), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(title.hitTestable(), findsOneWidget);
        await tester.tap(title);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 350)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final permission = find.byType(CheckboxListTile);
        expect(permission.hitTestable(), findsOneWidget);
        final rect = tester.getRect(permission);
        expect(rect.bottom, lessThanOrEqualTo(668));
        expect(tester.widget<CheckboxListTile>(permission).value, false);
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
