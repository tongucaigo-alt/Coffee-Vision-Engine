import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'fortune_personalization_test.dart'
    show personalizedTestContext, personalizedQualityFixtures;

void main() {
  test(
    'diagnostic store is bounded and excludes free-form errors and upstream fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'v75-diagnostics-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = AiStore(directory);
      await store.change((d) {
        d['diagnostics'] = List.generate(100, (_) => {'code': 'completed'});
      });
      await store.recordDiagnostic(
        const AiFailure(
          'PRIVATE_MESSAGE',
          code: 'connection',
          stage: 'generating',
          reason: 'PRIVATE_REASON',
          attempts: 1,
          durationMs: 20,
        ),
        {'PRIVATE_PROFILE': 1, 'generating': 20},
      );
      final data = await store.read();
      expect(data['diagnostics'], hasLength(100));
      expect(jsonEncode(data), isNot(contains('PRIVATE')));
      expect(
        safeAiDiagnostics({
          'code': 'PRIVATE_KEY',
          'headers': 'PRIVATE_HEADER',
          'durationMs': -1,
        }),
        isEmpty,
      );
    },
  );
  test(
    'shorter three-paragraph reply is a warning while source errors still block',
    () async {
      final context = personalizedTestContext();
      final fixture = await personalizedQualityFixtures();
      final story = (fixture['transportStory'] as String)
          .split('\n\n')
          .take(3)
          .join('\n\n');
      expect(story.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(150));
      expect(
        fortuneQualityWarnings(story, context),
        containsAll(['length', 'structure']),
      );
      expect(fortuneQualityError(story, 'stop', context: context), null);
      expect(
        fortuneQualityError(
          '$story Fincanında belirgin bir kuş görüyorum.',
          'stop',
          context: context,
        ),
        'unsupported_visual_claim',
      );
      expect(
        fortuneQualityError(story, 'length', context: context),
        'incomplete',
      );
    },
  );
  test(
    'format warning uses one request and transport failure does not retry or disclose content',
    () async {
      final fixture = await personalizedQualityFixtures();
      final story = (fixture['transportStory'] as String)
          .split('\n\n')
          .take(3)
          .join('\n\n');
      var calls = 0;
      var malformed = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((r) async {
        calls++;
        await r.drain<void>();
        r.response.write(
          malformed
              ? 'PRIVATE_REMOTE_BODY'
              : jsonEncode({
                  'choices': [
                    {
                      'finish_reason': 'stop',
                      'message': {'content': story},
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
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, host, port) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'v75-test',
        name: 'private-profile',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'test',
        provider: AiProvider.direct,
      );
      final answer = await client.generate(
        profile,
        'PRIVATE_FAKE_KEY',
        personalizedTestContext(),
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(calls, 1);
      expect(answer['attempts'], 1);
      expect(answer['qualityWarnings'], containsAll(['length', 'structure']));
      malformed = true;
      try {
        await client.generate(
          profile,
          'PRIVATE_FAKE_KEY',
          personalizedTestContext(),
          cancellation: AiCancellation(),
          onStatus: (_) {},
        );
        fail('malformed reply must fail');
      } on AiFailure catch (e) {
        expect(e.code, 'invalid_response');
        expect(e.attempts, 1);
        expect(jsonEncode(e.diagnostics), isNot(contains('PRIVATE')));
        expect(jsonEncode(e.diagnostics), isNot(contains('private-profile')));
      }
      expect(calls, 2);
    },
  );
}
