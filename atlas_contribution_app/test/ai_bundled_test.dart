import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/local_store.dart';

void main() {
  test('bundled credentials reject changed destination and model', () {
    for (final patch in [
      {'url': 'https://other.example/v1'},
      {'model': 'another-model'},
      {'provider': 'atlas'},
      {'id': 'copied-profile'},
      {'noThink': false},
    ]) {
      final p = AiProfile.fromJson({...bundledKimiProfile.toJson(), ...patch});
      expect(() => bundledCredential(p), throwsA(isA<AiFailure>()));
    }
    expect(jsonEncode(bundledKimiProfile.toJson()).contains('KEY'), false);
    expect(usesKimiInstant(bundledKimiProfile), true);
  });

  testWidgets('ready profile cannot open credential editor', (tester) async {
    late Directory dir;
    late AiRuntime runtime;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('atlas-bundled-');
      final source = DraftStore(Directory('${dir.path}/source'));
      await source.initialize();
      runtime = await AiRuntime.create(source);
      await runtime.store.saveProfile(bundledKimiProfile);
    });
    await tester.runAsync(
      () => tester.pumpWidget(MaterialApp(home: AiLabPage(runtime: runtime))),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Atlas · Kimi Test'), findsOneWidget);
    await tester.tap(find.text('Atlas · Kimi Test'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.runAsync(() async {
      await expectLater(
        runtime.saveProfile(bundledKimiProfile, 'unused'),
        throwsA(isA<AiFailure>()),
      );
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
