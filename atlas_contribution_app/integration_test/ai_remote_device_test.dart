import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import '../test/ai_test.dart' show contextData;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('phone reaches Atlas over public HTTPS without USB forwarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Atlas · mobil internet bağlantı testi')),
      ),
    );
    // Operator provisions this temporary file only inside the diagnostic sandbox.
    // No credential is compiled into any APK or printed in test output.
    final file = File(
      '/data/user/0/com.coffeeplatform.atlas_contribution_app.diagnostic/files/remote-ai-test.json',
    );
    final outcome = await tester.runAsync(() async {
      try {
        final config = jsonDecode(await file.readAsString()) as Map;
        final profile = AiProfile(
          id: 'remote-diagnostic',
          name: 'Atlas HTTPS',
          url: config['url'] as String,
          model: 'atlas',
          provider: AiProvider.atlas,
        );
        final client = AiClient(
          FortunePrompt(
            await rootBundle.loadString('assets/fortune-prompt-v1.json'),
          ),
          allowLan: false,
        );
        final models = await client.models(profile, config['token'] as String);
        if (!models.contains('atlas')) {
          return {'failure': 'Model alias missing'};
        }
        final input = contextData();
        input['photos'][0]['userObservations'] = [
          {
            'origin': 'userObservation',
            'symbolName': 'Kuş',
            'box': {'x': .3, 'y': .2, 'width': .15, 'height': .15},
          },
        ];
        return await client.generate(
          profile,
          config['token'] as String,
          input,
          cancellation: AiCancellation(),
          onStatus: (_) {},
        );
      } catch (error) {
        // Do not serialize arbitrary network exceptions which might contain URLs.
        return {
          'failure': error is AiFailure
              ? error.message
              : 'Remote diagnostic failed',
        };
      } finally {
        if (await file.exists()) await file.delete();
      }
    });
    expect(outcome, isNotNull);
    expect(outcome!['failure'], isNull);
    expect(outcome['text'], isA<String>());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(outcome['text'] as String),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
