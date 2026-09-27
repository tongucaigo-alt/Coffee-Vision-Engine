import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import '../test/ai_widget_test.dart' as widgets;
import '../test/ai_test.dart' show contextData;
import '../test/contribution_capture_flow_test.dart' as capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  capture.main();
  widgets.main();
  testWidgets(
    'diagnostic phone to real LM Studio over temporary USB forwarding',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Atlas AI · yapay veri bağlantı testi')),
        ),
      );
      final prompt = FortunePrompt(
        await rootBundle.loadString('assets/fortune-prompt-v1.json'),
      );
      // Diagnostic-only socket redirection, explicitly outside production boot.
      // adb reverse tcp:1234 tcp:1234 connects to PC loopback without publishing it.
      final client = AiClient(
        prompt,
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, 1234),
      );
      const profile = AiProfile(
        id: 'diagnostic',
        name: 'USB diagnostic',
        url: 'http://192.168.254.254:1234/v1',
        model: 'qwen3-14b',
        provider: AiProvider.direct,
      );
      final answer = await tester.runAsync(
        () => client.generate(
          profile,
          '',
          contextData(),
          cancellation: AiCancellation(),
          onStatus: (_) {},
        ),
      );
      expect(answer, isNotNull, reason: 'Real model generation must succeed.');
      if (answer == null) return;
      expect(answer['model'], 'qwen3-14b');
      expect(fortuneQualityError(answer['text'] as String, 'stop'), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(answer['text'] as String),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
    skip: !const bool.fromEnvironment('ATLAS_REAL_AI_TEST'),
  );
}
