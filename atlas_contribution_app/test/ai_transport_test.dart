import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'ai_test.dart' show contextData;

void main() {
  test(
    'quota rejection is actionable and does not expose remote details',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = 429;
        request.response.write(
          jsonEncode({
            'error': {
              'type': 'exceeded_current_quota_error',
              'message': 'private-key-and-account-details',
            },
          }),
        );
        await request.response.close();
      });
      final client = AiClient(
        FortunePrompt(
          await File('assets/fortune-prompt-v1.json').readAsString(),
        ),
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, proxyHost, proxyPort) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'quota-test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'test',
        provider: AiProvider.direct,
      );
      await expectLater(
        client.models(profile, 'fake-key'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('bakiyesi'),
              isNot(contains('private-key-and-account-details')),
            ),
          ),
        ),
      );
    },
  );

  test(
    'direct request has only safe payload; redirects never forward credentials',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var redirect = false, calls = 0;
      Map<String, dynamic>? wire;
      final good = List.filled(
        30,
        'Belki bu dağılım sana sakinlik için bir alan çağrıştırıyor.',
      ).join(' ');
      server.listen((request) async {
        calls++;
        expect(request.headers.value('authorization'), 'Bearer local-test-key');
        if (redirect) {
          request.response.statusCode = 302;
          request.response.headers.set('location', 'http://192.168.10.2/steal');
          await request.response.close();
          return;
        }
        wire = Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': good},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final client = AiClient(
        prompt,
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, proxyHost, proxyPort) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'qwen3-14b',
        provider: AiProvider.direct,
      );
      final result = await client.generate(
        profile,
        'local-test-key',
        contextData(),
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(result['text'], good);
      expect(wire!.keys.toSet(), {
        'model',
        'messages',
        'stream',
        'temperature',
        'max_tokens',
      });
      expect(jsonEncode(wire), isNot(contains('local-test-key')));
      expect(jsonEncode(wire), isNot(contains('sourceFingerprint')));
      redirect = true;
      await expectLater(
        client.generate(
          profile,
          'local-test-key',
          contextData(),
          cancellation: AiCancellation(),
          onStatus: (_) {},
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 2);
    },
  );
  test(
    'direct model repairs once; cancellation never publishes a response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      final cancel = AiCancellation();
      final good = List.filled(
        30,
        'Belki bu dağılım sana sakinlik için bir alan çağrıştırıyor.',
      ).join(' ');
      server.listen((r) async {
        await r.drain<void>();
        calls++;
        if (calls == 3) await cancel.cancel();
        r.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': calls == 1 ? '<think>private</think>' : good,
                },
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
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final p = AiProfile(
        id: 'test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'qwen3-14b',
        provider: AiProvider.direct,
      );
      final result = await client.generate(
        p,
        '',
        contextData(),
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(result['attempts'], 2);
      await expectLater(
        client.generate(
          p,
          '',
          contextData(),
          cancellation: cancel,
          onStatus: (_) {},
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 3);
    },
  );
  for (final id in [
    'unreported-bird-symbol',
    'no-symbols-in-cup',
    'measurements-and-spelled-percentage',
  ]) {
    test('direct model repairs $id using the same context', () async {
      final fixtures =
          jsonDecode(
                await File(
                  '../atlas_ai_gateway/test/fixtures/fortune-quality-cases.json',
                ).readAsString(),
              )
              as Map;
      final c =
          (fixtures['cases'] as List).firstWhere((c) => c['id'] == id) as Map;
      final good = List.filled(
        fixtures['paddingRepeat'] as int,
        fixtures['paddingSentence'] as String,
      ).join();
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final input = contextData();
      var calls = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final wire = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        calls++;
        final message = (wire['messages'] as List).last['content'] as String;
        expect(message, contains(jsonEncode(input)));
        if (calls == 2) {
          expect(
            message,
            contains(prompt.data['repairHints'][c['error']] as String),
          );
        }
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': calls == 1 ? '$good${c['text']}' : good},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });
      final client = AiClient(
        prompt,
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'language-test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'test',
        provider: AiProvider.direct,
      );
      final result = await client.generate(
        profile,
        '',
        input,
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(result['text'], good.trim());
      expect(result['attempts'], 2);
      expect(calls, 2);
      expect(result['promptVersion'], prompt.version);
      expect(result['promptHash'], prompt.hash);
    });
  }
  test(
    'direct model rejects unreported symbols twice and accepts a reported symbol',
    () async {
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final good = List.filled(
        25,
        'Belki günlük seçimlerin sana yeni bir yol çağrıştırabilir. ',
      ).join();
      final story =
          '${good}Paylaştığın Kuş sembolü haberleşmeyi çağrıştırabilir.';
      var calls = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        calls++;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': story},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });
      final client = AiClient(
        prompt,
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'symbols-test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'test',
        provider: AiProvider.direct,
      );
      await expectLater(
        client.generate(
          profile,
          '',
          contextData(),
          cancellation: AiCancellation(),
          onStatus: (_) {},
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 2);
      final input = contextData();
      input['photos'][0]['userObservations'] = [
        {
          'origin': 'userObservation',
          'symbolName': 'Kuş',
          'box': {'x': 0.1, 'y': 0.1, 'width': 0.2, 'height': 0.2},
        },
      ];
      final result = await client.generate(
        profile,
        '',
        input,
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(result['text'], story);
      expect(result['attempts'], 1);
      expect(calls, 3);
    },
  );
  test(
    'completed gateway answers require current identity and context grounding',
    () async {
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final good = List.filled(
        25,
        'Belki günlük seçimlerin sana yeni bir yol çağrıştırabilir. ',
      ).join();
      var version = prompt.version, hash = prompt.hash, answer = good;
      var starts = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        final Object body;
        if (request.uri.path.endsWith('/capabilities')) {
          body = {
            'promptVersion': prompt.version,
            'promptHash': prompt.hash,
            'available': true,
            'models': ['test'],
          };
        } else if (request.method == 'POST') {
          starts++;
          body = {'jobId': 'fake-job', 'serverInstanceId': 'test-instance'};
        } else {
          body = {
            'state': 'completed',
            'serverInstanceId': 'test-instance',
            'result': {
              'text': answer.trim(),
              'promptVersion': version,
              'promptHash': hash,
            },
          };
        }
        request.response.write(jsonEncode(body));
        await request.response.close();
      });
      final client = AiClient(
        prompt,
        allowLan: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'gateway-result-test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}',
        model: 'test',
        provider: AiProvider.atlas,
      );
      Future<Map<String, dynamic>> generate() => client.generate(
        profile,
        '',
        contextData(),
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect((await generate())['text'], good.trim());
      version = 'atlas-fortune-prompt-v1';
      await expectLater(generate(), throwsA(isA<AiFailure>()));
      version = prompt.version;
      hash = 'stale-hash';
      await expectLater(generate(), throwsA(isA<AiFailure>()));
      hash = prompt.hash;
      answer = '${good}Paylaştığın Kuş sembolü haberleşmeyi çağrıştırabilir.';
      await expectLater(generate(), throwsA(isA<AiFailure>()));
      expect(
        starts,
        4,
      ); // The client does not start another job to repair a gateway result.
    },
  );
}
