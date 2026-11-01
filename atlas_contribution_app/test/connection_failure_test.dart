import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'ai_test.dart' show contextData;

void main() {
  test(
    'a closed upstream connection is classified without automatically replaying a paid request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      server.listen((request) async {
        calls++;
        await request.drain<void>();
        final socket = await request.response.detachSocket();
        socket.destroy();
      });
      final client = AiClient(
        FortunePrompt(
          await File('assets/fortune-prompt-v1.json').readAsString(),
        ),
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      await expectLater(
        client.generate(
          AiProfile(
            id: 'fixture',
            name: 'fixture',
            url: 'http://192.168.10.1:${server.port}/v1',
            model: 'fixture',
            provider: AiProvider.direct,
          ),
          'fake',
          contextData(),
          cancellation: AiCancellation(),
          onStatus: (_) {},
        ),
        throwsA(
          isA<AiFailure>().having((e) => e.code, 'safe code', 'connection'),
        ),
      );
      expect(calls, 1);
    },
  );
}
