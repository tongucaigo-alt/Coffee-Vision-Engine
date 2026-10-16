import 'dart:convert';
import 'dart:io';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/ai/fortune_personalization.dart';
import 'package:atlas_contribution_app/src/user_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'rich_fortune_test.dart' show richContext;

Map<String, dynamic> personalizedTestContext({String? symbol, String? zodiac}) {
  final base = richContext();
  base['photos'] = (base['photos'] as List).take(1).toList();
  if (symbol != null) {
    base['photos'][0]['userObservations'] = [
      {
        'origin': 'userObservation',
        'symbolName': symbol,
        'box': {'x': .2, 'y': .2, 'width': .15, 'height': .15},
      },
    ];
  }
  final data =
      jsonDecode(
            jsonEncode(
              personalizeFortuneContext(base, readingIdentity: 'test-reading'),
            ),
          )
          as Map<String, dynamic>;
  data['creativeSymbol'] = symbol == null
      ? {
          'catalogVersion': creativeCatalogVersion,
          'origin': 'creativeSelectionNotVisualDetection',
          'symbolId': 'key',
          'symbolName': 'Anahtar',
        }
      : null;
  if (zodiac != null) data['personalization'] = {'zodiac': zodiac};
  return validateAiContext(data);
}

Future<Map<String, dynamic>> personalizedQualityFixtures() async =>
    jsonDecode(
          await File(
            '../atlas_ai_gateway/test/fixtures/personalized-quality-cases.json',
          ).readAsString(),
        )
        as Map<String, dynamic>;

void main() {
  test(
    'stable motif is separate from observations and does not mutate research input',
    () {
      final base = richContext();
      final original = jsonEncode(base);
      final a = personalizeFortuneContext(
        base,
        readingIdentity: 'same-reading',
      );
      final b = personalizeFortuneContext(
        base,
        readingIdentity: 'same-reading',
      );
      expect(validateAiContext(a), a);
      expect(a['creativeSymbol'], b['creativeSymbol']);
      expect(jsonEncode(base), original);
      expect(jsonEncode(a['photos']), jsonEncode(base['photos']));
      expect(a.containsKey('personalization'), false);
      final forcedPrevious = personalizedTestContext();
      expect(
        personalizeFortuneContext(
          base,
          readingIdentity: 'other',
          previousContext: forcedPrevious,
        )['creativeSymbol'],
        forcedPrevious['creativeSymbol'],
      );
    },
  );

  test(
    'user symbols have priority; optional profile is allowlisted and fail closed',
    () {
      final base = richContext();
      final profile = UserProfile(
        addressName: 'PRIVATE_NAME_SENTINEL',
        zodiac: ZodiacSign.libra,
      );
      final withoutPermission = personalizeFortuneContext(
        base,
        readingIdentity: 'r',
        profile: profile,
      );
      expect(withoutPermission.containsKey('personalization'), false);
      expect(
        personalizeFortuneContext({
          ...base,
          'personalization': {'zodiac': 'libra'},
        }, readingIdentity: 'r').containsKey('personalization'),
        false,
      );
      final permitted = personalizeFortuneContext(
        base,
        readingIdentity: 'r',
        profile: const UserProfile(
          addressName: 'PRIVATE_NAME_SENTINEL',
          zodiac: ZodiacSign.libra,
          useZodiacInReading: true,
        ),
      );
      expect(permitted['personalization'], {'zodiac': 'libra'});
      expect(jsonEncode(permitted), isNot(contains('PRIVATE_NAME_SENTINEL')));
      expect(personalizedTestContext(symbol: 'Kuş')['creativeSymbol'], isNull);
      expect(
        validateAiContext(
          storedFortuneContext(permitted),
        ).containsKey('personalization'),
        false,
      );
    },
  );

  test(
    'v3 cannot hide invalid sources, extra profile fields or missing physical input',
    () {
      Map<String, dynamic> copy() =>
          jsonDecode(jsonEncode(personalizedTestContext()))
              as Map<String, dynamic>;
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (c) => c['personalization'] = {
          'zodiac': 'libra',
          'addressName': 'private',
        },
        (c) => c['personalization'] = {'zodiac': 'untrusted instruction'},
        (c) => c['creativeSymbol']['origin'] = 'userObservation',
        (c) => c['creativeSymbol']['symbolName'] = 'Kuş',
        (c) => c['creativeSymbol'] = null,
        (c) => c['photos'][0]['userObservations'] = [
          {
            'origin': 'userObservation',
            'symbolName': 'Kuş',
            'box': {'x': .2, 'y': .2, 'width': .1, 'height': .1},
          },
        ],
        (c) => c['photos'][0]['globalPhysicalMeasurements'] = {
          'residuePixelCount': 0,
          'contentResidueRatio': 0.0,
          'componentCount': 0,
          'candidateRelationCount': 0,
          'selectedRelationCount': 0,
        },
      ]) {
        final c = copy();
        mutate(c);
        expect(() => validateAiContext(c), throwsFormatException);
      }
    },
  );

  test(
    'Dart and gateway share source, zodiac and visual-claim cases',
    () async {
      final fixture = await personalizedQualityFixtures();
      for (final row in fixture['cases'] as List) {
        final symbol = row['userSymbol'] as String?;
        final context = personalizedTestContext(
          symbol: symbol,
          zodiac: row['zodiac'] as String?,
        );
        final story = (fixture['validStory'] as String).replaceAll(
          'Anahtarın',
          symbol == null ? 'Anahtarın' : 'Paylaştığın kuşun',
        );
        expect(
          fortuneQualityError(
            '$story ${row['suffix']}',
            'stop',
            context: context,
          ),
          row['error'],
          reason: row['id'] as String,
        );
      }
      final context = personalizedTestContext();
      expect(
        fortuneQualityError(
          'Anahtar bir ihtimal olabilir.',
          'stop',
          context: context,
          editorial: false,
        ),
        'length',
      );
    },
  );

  test(
    'profile is ephemeral, saved motif survives restart, deletion never regenerates',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'atlas-personalization-store-',
      );
      addTearDown(() => root.delete(recursive: true));
      final profile = UserProfileStore(Directory('${root.path}/user-profile'));
      final ai = AiStore(Directory('${root.path}/ai-local'));
      await profile.save(
        const UserProfile(
          addressName: 'PRIVATE_NAME_SENTINEL',
          zodiac: ZodiacSign.libra,
          useZodiacInReading: true,
        ),
      );
      final input = personalizeFortuneContext(
        richContext(),
        readingIdentity: 'stable',
        profile: await profile.read(),
      );
      await ai.saveResult({
        'id': 'result',
        'sessionId': 'session',
        'groupId': 'g',
        'state': 'running',
        'context': input,
        'answers': [],
      });
      final reopened = AiStore(ai.directory);
      await reopened.recoverInterruptedResults();
      final result = (await reopened.results('session')).single;
      expect(result['state'], 'interrupted');
      expect((result['context'] as Map).containsKey('personalization'), false);
      expect(result['context']['creativeSymbol'], input['creativeSymbol']);
      expect(
        await File('${ai.directory.path}/state.json').readAsString(),
        isNot(contains('libra')),
      );
      await profile.delete();
      final retry = personalizeFortuneContext(
        richContext(),
        readingIdentity: 'stable',
        profile: await profile.read(),
        previousContext: Map<String, dynamic>.from(result['context'] as Map),
      );
      expect(retry.containsKey('personalization'), false);
      expect(retry['creativeSymbol'], input['creativeSymbol']);
      expect(jsonEncode(await ai.researchAudit('g')), isNot(contains('libra')));
    },
  );

  test(
    'unreadable optional profile fails closed without a network request',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'atlas-profile-runtime-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = DraftStore(Directory('${root.path}/source'));
      await source.initialize();
      final client = AiClient(
        FortunePrompt(
          await File('assets/fortune-prompt-v1.json').readAsString(),
        ),
        createHttpClient: () => throw StateError('Unexpected AI request'),
      );
      final runtime = await AiRuntime.create(source, client: client);
      final folder = await Directory('${root.path}/user-profile').create();
      await File('${folder.path}/profile.json').writeAsString('{broken');
      final profile = await runtime.readingProfile();
      expect(profile.useZodiacInReading, false);
      expect(profile.zodiac, isNull);
      expect(profile.addressName, isEmpty);
    },
  );

  test(
    'v3 gateway repetition cannot bypass the two-attempt limit in lab',
    () async {
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final good =
          (await personalizedQualityFixtures())['transportStory'] as String;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var repairs = 0, polls = 0;
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        final path = request.uri.path;
        if (path.endsWith('/capabilities')) {
          request.response.write(
            jsonEncode({
              'apiVersion': 1,
              'serverInstanceId': 'synthetic',
              'contextVersions': [personalizedContextVersion],
              'clientRepetitionRepair': true,
              'available': true,
              'promptVersion': prompt.version,
              'promptHash': prompt.hash,
              'models': ['atlas'],
            }),
          );
        } else if (path.endsWith('/jobs') && request.method == 'POST') {
          request.response.write(
            jsonEncode({'jobId': 'job', 'serverInstanceId': 'synthetic'}),
          );
        } else if (request.method == 'POST') {
          repairs++;
          request.response.write('{}');
        } else if (request.method == 'DELETE') {
          request.response.write('{}');
        } else {
          polls++;
          request.response.write(
            jsonEncode({
              'state': 'completed',
              'serverInstanceId': 'synthetic',
              'result': {
                'text': good,
                'promptVersion': prompt.version,
                'promptHash': prompt.hash,
                'attempts': repairs + 1,
              },
            }),
          );
        }
        await request.response.close();
      });
      final client = AiClient(
        prompt,
        allowLan: true,
        bestEffort: true,
        createHttpClient: () => HttpClient()
          ..connectionFactory = (uri, _, _) =>
              Socket.startConnect(InternetAddress.loopbackIPv4, server.port),
      );
      final profile = AiProfile(
        id: 'gateway',
        name: 'gateway',
        url: 'http://192.168.1.10:${server.port}',
        model: 'atlas',
        provider: AiProvider.atlas,
      );
      await expectLater(
        client.generate(
          profile,
          '',
          personalizedTestContext(),
          cancellation: AiCancellation(),
          onStatus: (_) {},
          previousTexts: [good],
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(repairs, 1);
      expect(polls, 2);
    },
  );

  test(
    'v3 transport keeps source checks even in lab and allows at most two calls',
    () async {
      final fixture = await personalizedQualityFixtures();
      final good = fixture['transportStory'] as String;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0, alwaysBad = false, copyExample = false;
      final wires = <Map>[];
      server.listen((request) async {
        calls++;
        wires.add(jsonDecode(await utf8.decoder.bind(request).join()) as Map);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': copyExample
                      ? (alwaysBad || calls.isOdd
                            ? fixture['validStory']
                            : good)
                      : (alwaysBad || calls == 1
                            ? '$good Paylaştığın anahtar bir ihtimal olabilir.'
                            : good),
                },
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
        bestEffort: true,
        createHttpClient: () =>
            HttpClient()
              ..connectionFactory = (uri, _, _) =>
                  Socket.startConnect(InternetAddress.loopbackIPv4, uri.port),
      );
      final profile = AiProfile(
        id: 'test',
        name: 'test',
        url: 'http://192.168.10.1:${server.port}/v1',
        model: 'test',
        provider: AiProvider.direct,
      );
      final input = personalizedTestContext(zodiac: 'libra');
      final result = await client.generate(
        profile,
        'fake-local-key',
        input,
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(calls, 2);
      expect(result['attempts'], 2);
      final userMessage =
          (wires.first['messages'] as List).last['content'] as String;
      expect(userMessage, contains('Terazi'));
      expect(userMessage, contains('Yaratıcı anlatı sembolü: Anahtar'));
      expect(userMessage, isNot(contains('PRIVATE_NAME_SENTINEL')));
      alwaysBad = true;
      await expectLater(
        client.generate(
          profile,
          '',
          input,
          cancellation: AiCancellation(),
          onStatus: (_) {},
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 4);
      copyExample = true;
      alwaysBad = false;
      final recovered = await client.generate(
        profile,
        '',
        input,
        cancellation: AiCancellation(),
        onStatus: (_) {},
      );
      expect(recovered['attempts'], 2);
      expect(calls, 6);
      alwaysBad = true;
      await expectLater(
        client.generate(
          profile,
          '',
          input,
          cancellation: AiCancellation(),
          onStatus: (_) {},
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 8);
    },
  );
}
