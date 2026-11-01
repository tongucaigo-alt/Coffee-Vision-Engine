import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'ai_test.dart' show contextData;

void main() {
  test(
    'local transport measures first response and repair without changing gates',
    () async {
      final good = List.filled(
        30,
        'Belki bu dağılım sana sakinlik için bir alan çağrıştırıyor.',
      ).join(' ');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0, checks = 0;
      server.listen((request) async {
        await request.drain<void>();
        calls++;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': calls == 1 ? 'Kısa.' : good},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });
      final client = AiClient(
        FortunePrompt(
          await File('assets/fortune-prompt-v1.json').readAsString(),
        ),
        allowLan: true,
        bestEffort: false,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final stages = <String, int>{};
      final answer = await client.generate(
        AiProfile(
          id: 'fixture',
          name: 'fixture',
          url: 'http://192.168.10.1:${server.port}/v1',
          model: 'fixture',
          provider: AiProvider.direct,
        ),
        '',
        contextData(),
        cancellation: AiCancellation(),
        onStatus: (_) {},
        beforeRequest: () async {
          checks++;
        },
        onStage: (stage, elapsed) => stages[stage] = elapsed,
      );
      expect(answer['attempts'], 2);
      expect(calls, 2);
      expect(checks, 2);
      expect(
        stages.keys,
        containsAll([
          'requestValidation1',
          'firstResponse',
          'responseQuality1',
          'requestValidation2',
          'repairResponse',
          'responseQuality2',
        ]),
      );
      expect(stages.values.every((elapsed) => elapsed >= 0), isTrue);
    },
  );
}
