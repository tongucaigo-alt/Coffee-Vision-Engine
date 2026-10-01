import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/play_access_page.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/local_store.dart';

void main() {
  testWidgets(
    'closed test access has no model/provider controls and rejects HTTP before saving',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory directory;
      late AiRuntime runtime;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('atlas-play-access-');
        final source = DraftStore(Directory('${directory.path}/source'));
        await source.initialize();
        runtime = await AiRuntime.create(source, readKey: (_) async => '');
      });
      addTearDown(() => directory.delete(recursive: true));
      await tester.pumpWidget(
        MaterialApp(home: PlayAccessPage(runtime: runtime)),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        if (tester.widget<TextField>(find.byType(TextField).first).enabled ==
            true) {
          break;
        }
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Kendi AI sunucum'), findsNothing);
      await tester.enterText(
        find.byType(TextField).first,
        'http://192.168.1.20:8787',
      );
      await tester.tap(find.text('Bağlantıyı Kaydet'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTPS kullan.'), findsOneWidget);
      await tester.runAsync(
        () async => expect(await runtime.store.profiles(), isEmpty),
      );
    },
  );

  test(
    'delivery checks retain certainty and reasoning while ignoring editorial length',
    () {
      expect(
        fortuneQualityError(
          'Belki kendine zaman ayırmak iyi gelebilir.',
          'stop',
          editorial: false,
        ),
        isNull,
      );
      expect(
        fortuneQualityError(
          'Kesinlikle kazanacaksın.',
          'stop',
          editorial: false,
        ),
        'certainty',
      );
      expect(
        fortuneQualityError(
          '<think>Belki düşünmek iyi gelebilir.',
          'stop',
          editorial: false,
        ),
        'reasoning',
      );
      expect(fortuneQualityError('', 'stop', editorial: false), 'incomplete');
      expect(
        physicalCues({
          'photos': [
            {
              'surface': 'cup',
              'regionalSummary': {
                'bands': [],
                'components': [
                  {'x': .5, 'y': .5},
                ],
              },
            },
          ],
        }),
        ['fincanın orta bölümündeki leke'],
      );
    },
  );
}
