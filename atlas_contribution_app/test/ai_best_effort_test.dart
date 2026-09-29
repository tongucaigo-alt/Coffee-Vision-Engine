import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'ai_test.dart' show contextData;

void main() {
  test(
    'beta returns readable short story without a second paid request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      final story = List.filled(
        8,
        'Belki bugün kendine yeni bir alan açmayı düşünebilirsin.',
      ).join(' ');
      server.listen((r) async {
        await r.drain<void>();
        calls++;
        r.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': story},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await r.response.close();
      });
      final client = AiClient(
        FortunePrompt(
          await File('assets/fortune-prompt-v1.json').readAsString(),
        ),
        allowLan: true,
        bestEffort: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final result = await client.generate(
        AiProfile(
          id: 'test',
          name: 'test',
          url: 'http://192.168.10.1:${server.port}/v1',
          model: 'test',
          provider: AiProvider.direct,
        ),
        '',
        contextData(),
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(result['text'], story);
      expect(result['qualityWarning'], 'length');
      expect(result['attempts'], 1);
      expect(calls, 1);
    },
  );
  test('empty, truncated or thinking replies are not usable', () {
    final text = List.filled(60, 'kelime').join(' ');
    expect(usableFortuneText('', 'stop'), isFalse);
    expect(usableFortuneText(null, 'stop'), isFalse);
    expect(usableFortuneText(text, 'length'), isFalse);
    expect(usableFortuneText('<think>$text</think>', 'stop'), isFalse);
    expect(usableFortuneText(text, 'stop'), isTrue);
  });
}
