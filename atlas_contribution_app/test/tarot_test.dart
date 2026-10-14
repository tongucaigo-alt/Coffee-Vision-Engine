import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_transport.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_ai.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';

List<TarotCard> catalog() =>
    loadTarotCatalog(File('assets/tarot/catalog-v1.json').readAsStringSync());
TarotDraw fixture({
  TarotSpread spread = TarotSpread.three,
  String id = 'fixture',
}) => TarotDraw(
  id: id,
  spread: spread,
  createdAt: '2026-10-11T09:00:00Z',
  deck: catalog().indexed.map((c) => TarotDeckCard(c.$2, c.$1.isOdd)).toList(),
  selected: spread == TarotSpread.three ? [0, 1, 2] : [1],
  revealed: spread == TarotSpread.three ? 3 : 1,
  day: spread == TarotSpread.daily ? '2026-10-11' : null,
);

void main() {
  late Directory temp;
  late TarotStore store;
  late DateTime clock;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('atlas-tarot-test-');
    clock = DateTime(2026, 10, 11, 14);
    store = TarotStore(Directory('${temp.path}/tarot'), now: () => clock);
    await store.initialize();
  });
  tearDown(() async => temp.delete(recursive: true));

  test('78 catalog identities and all 79 images are bundled', () {
    final cards = catalog();
    expect(cards.length, 78);
    expect(cards.map((c) => c.id).toSet().length, 78);
    for (final card in cards) {
      expect(File('assets/tarot/${card.image}').existsSync(), true);
    }
    expect(File('assets/tarot/KART_ARKASI.webp').existsSync(), true);
    expect(() => loadTarotCatalog('[]'), throwsFormatException);
  });

  test(
    'shuffle preserves every identity and independently supports both orientations',
    () {
      final cards = catalog();
      final deck = shuffleTarot(cards, random: Random(91));
      expect(
        deck.map((c) => c.card.id).toSet(),
        cards.map((c) => c.id).toSet(),
      );
      expect(deck.any((c) => c.reversed), true);
      expect(deck.any((c) => !c.reversed), true);
      expect(
        deck.map((c) => c.card.id).toList(),
        isNot(cards.map((c) => c.id).toList()),
      );
      expect(cards.first.id, 'deli');
    },
  );

  test(
    'selected index, orientation, deck and themes survive cold reopen',
    () async {
      var draw = await store.start(TarotSpread.three, catalog());
      final expected = draw.deck[47].toJson();
      final savedDeck = jsonEncode(draw.deck.map((c) => c.toJson()).toList());
      draw = await store.select(draw.id, 47);
      expect(draw.chosen.single.toJson(), expected);
      final reopened = TarotStore(store.directory, now: () => clock);
      await reopened.initialize();
      draw = (await reopened.get(draw.id))!;
      expect(draw.chosen.single.toJson(), expected);
      expect(jsonEncode(draw.deck.map((c) => c.toJson()).toList()), savedDeck);
      await expectLater(reopened.select(draw.id, 47), throwsStateError);
      await expectLater(
        reopened.reshuffle(draw.id, catalog()),
        throwsStateError,
      );
      await expectLater(reopened.reveal(draw.id, 0), throwsStateError);
      await reopened.select(draw.id, 10);
      await reopened.select(draw.id, 25);
      await expectLater(reopened.select(draw.id, 11), throwsStateError);
      await expectLater(reopened.reveal(draw.id, 1), throwsStateError);
      await reopened.reveal(draw.id, 0);
      await reopened.reveal(draw.id, 1);
      draw = await reopened.reveal(draw.id, 2);
      expect(draw.ready, true);
      expect(draw.chosen.first.toJson(), expected);
    },
  );

  test('AI context is text only and uses the selected orientation themes', () {
    final draw = fixture();
    final context = draw.context();
    expect(context.keys.toSet(), {'version', 'language', 'spread', 'cards'});
    final cards = context['cards'] as List;
    expect(cards[0]['themes'], draw.chosen[0].card.upright);
    expect(cards[1]['themes'], draw.chosen[1].card.reversed);
    expect(cards[1]['orientation'], 'reversed');
    expect(cards.map((c) => c['position']).toList(), [
      'Geçmiş',
      'Şimdi',
      'Olası Yön',
    ]);
    expect(jsonEncode(context), isNot(contains('.webp')));
    expect(jsonEncode(context), isNot(contains('photos')));
    expect(jsonEncode(context), isNot(contains('gorsel')));
    expect(
      () => TarotDraw(
        id: 'broken',
        spread: TarotSpread.three,
        createdAt: draw.createdAt,
        deck: draw.deck,
        selected: [0, 0],
      ),
      throwsFormatException,
    );
  });

  test(
    'daily draw locks at selection day, repeats unchanged and renews next day',
    () async {
      final before = await store.start(TarotSpread.daily, catalog());
      clock = DateTime(2026, 10, 12, 0, 1);
      final picked = await store.select(before.id, 5);
      expect(picked.day, '2026-10-12');
      final again = await store.start(TarotSpread.daily, catalog());
      expect(again.id, picked.id);
      expect(again.chosen.single.toJson(), picked.chosen.single.toJson());
      clock = DateTime(2026, 10, 13);
      final tomorrow = await store.start(TarotSpread.daily, catalog());
      expect(tomorrow.id, isNot(picked.id));
      expect(await store.get(picked.id), isNotNull);
    },
  );

  test(
    'daily deletion retains only today tombstone; tomorrow permits selection',
    () async {
      var draw = await store.start(TarotSpread.daily, catalog());
      draw = await store.select(draw.id, 3);
      await store.delete(draw.id);
      expect(await store.draws(), isEmpty);
      await expectLater(
        store.start(TarotSpread.daily, catalog()),
        throwsStateError,
      );
      final disk =
          jsonDecode(
                await File('${store.directory.path}/state.json').readAsString(),
              )
              as Map;
      expect(disk['deletedDailyDays'], ['2026-10-11']);
      expect(jsonEncode(disk), isNot(contains(draw.chosen.single.card.name)));
      clock = DateTime(2026, 10, 12);
      expect(
        (await store.start(TarotSpread.daily, catalog())).selected,
        isEmpty,
      );
    },
  );

  test(
    '20 tarot stars are independent; manual delete and unstar free a slot',
    () async {
      final rows = List.generate(
        21,
        (i) => fixture(id: 'row-$i').copy(
          result: const TarotResult(
            state: TarotResultState.completed,
            text: 'Saved reading',
          ),
        ),
      );
      await File('${store.directory.path}/state.json').writeAsString(
        jsonEncode({
          'version': 1,
          'draws': rows.map((d) => d.toJson()).toList(),
          'deletedDailyDays': [],
        }),
      );
      final coffee = File('${temp.path}/coffee.json');
      await coffee.writeAsString('unchanged coffee history and stars');
      for (var i = 0; i < 20; i++) {
        await store.star('row-$i', true);
      }
      await expectLater(store.star('row-20', true), throwsStateError);
      await store.star('row-0', false);
      await store.star('row-20', true);
      await store.delete('row-1');
      expect((await store.draws()).where((d) => d.starred).length, 19);
      expect(await coffee.readAsString(), 'unchanged coffee history and stars');
    },
  );

  test(
    'startup recovers running to interrupted without a new request',
    () async {
      await File('${store.directory.path}/state.json').writeAsString(
        jsonEncode({
          'version': 1,
          'draws': [
            fixture()
                .copy(
                  result: const TarotResult(
                    state: TarotResultState.running,
                    attemptId: 'old',
                    promptVersion: 'v1',
                  ),
                )
                .toJson(),
          ],
          'deletedDailyDays': [],
        }),
      );
      await store.initialize();
      final draw = (await store.get('fixture'))!;
      expect(draw.result.state, TarotResultState.interrupted);
      expect(draw.context(), fixture().context());
    },
  );

  test('corrupt storage fails closed without reset', () async {
    final file = File('${store.directory.path}/state.json');
    await file.writeAsString('original-invalid-data');
    await expectLater(store.initialize(), throwsFormatException);
    expect(await file.readAsString(), 'original-invalid-data');
  });

  Future<void> putReady() async =>
      File('${store.directory.path}/state.json').writeAsString(
        jsonEncode({
          'version': 1,
          'draws': [fixture().toJson()],
          'deletedDailyDays': [],
        }),
      );

  test('mood is optional, removable and absent from AI context', () {
    final old = fixture().toJson()..remove('mood');
    expect(TarotDraw.fromJson(old).mood, isNull);
    final calm = fixture().copy(mood: TarotMood.calm);
    expect(TarotDraw.fromJson(calm.toJson()).mood, TarotMood.calm);
    expect(calm.copy(starred: true).mood, TarotMood.calm);
    expect(calm.copy(clearMood: true).mood, isNull);
    expect(calm.context(), fixture().context());
  });

  test(
    'queued mood updates preserve concurrent selection and reveal',
    () async {
      final draw = await store.start(TarotSpread.three, catalog());
      await Future.wait([
        store.setMood(draw.id, TarotMood.happy),
        store.select(draw.id, 47),
        store.select(draw.id, 8),
        store.select(draw.id, 19),
      ]);
      await Future.wait([
        store.reveal(draw.id, 0),
        store.setMood(draw.id, TarotMood.calm),
        store.reveal(draw.id, 1),
      ]);
      final reopened = TarotStore(store.directory);
      await reopened.initialize();
      final saved = (await reopened.get(draw.id))!;
      expect(saved.selected, [47, 8, 19]);
      expect(saved.revealed, 2);
      expect(saved.mood, TarotMood.calm);
      expect(
        saved.deck.map((c) => c.toJson()),
        draw.deck.map((c) => c.toJson()),
      );
    },
  );

  test(
    'mood survives result and star updates; clearing keeps the reading',
    () async {
      await putReady();
      await store.setMood('fixture', TarotMood.tired);
      await store.begin('fixture', 'attempt', 'v1', 'hash');
      await store.finish(
        'fixture',
        'attempt',
        TarotResultState.completed,
        text: 'Saved reading',
      );
      await store.star('fixture', true);
      expect((await store.get('fixture'))!.mood, TarotMood.tired);
      final cleared = await store.setMood('fixture', null);
      expect(cleared.mood, isNull);
      expect(cleared.result.text, 'Saved reading');
      expect(cleared.starred, true);
    },
  );

  test('deleting a daily mood note preserves its same-day lock', () async {
    final draw = await store.start(TarotSpread.daily, catalog());
    await store.select(draw.id, 4);
    await store.setMood(draw.id, TarotMood.unsure);
    await store.delete(draw.id);
    expect(await store.get(draw.id), isNull);
    await expectLater(
      store.start(TarotSpread.daily, catalog()),
      throwsStateError,
    );
  });

  test(
    'double generation invokes once; persisted completion never generates again',
    () async {
      await putReady();
      var calls = 0;
      final started = Completer<void>(), reply = Completer<String>();
      final runtime = TarotRuntime(
        store: store,
        catalog: catalog(),
        promptVersion: 'v1',
        promptHash: 'hash',
        generateReading: (draw, token) {
          calls++;
          started.complete();
          return reply.future;
        },
      );
      addTearDown(runtime.dispose);
      final first = runtime.generate('fixture');
      final second = runtime.generate('fixture');
      await started.future;
      expect(
        (await store.get('fixture'))!.result.state,
        TarotResultState.running,
      );
      reply.complete('Successful test reading');
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(
        (await store.get('fixture'))!.result.state,
        TarotResultState.completed,
      );
      await expectLater(runtime.generate('fixture'), throwsStateError);
      expect(calls, 1);
    },
  );

  test(
    'failure waits for explicit retry and preserves exact textual context',
    () async {
      await putReady();
      final contexts = <String>[];
      final runtime = TarotRuntime(
        store: store,
        catalog: catalog(),
        promptVersion: 'v1',
        promptHash: 'hash',
        generateReading: (draw, token) async {
          contexts.add(jsonEncode(draw.context()));
          if (contexts.length == 1) throw const AiFailure('Network failure');
          return 'Retry reading';
        },
      );
      addTearDown(runtime.dispose);
      await runtime.generate('fixture');
      expect(contexts.length, 1);
      expect(
        (await store.get('fixture'))!.result.state,
        TarotResultState.failed,
      );
      await store.initialize();
      expect(contexts.length, 1);
      await runtime.generate('fixture');
      expect(contexts.length, 2);
      expect(contexts.first, contexts.last);
    },
  );

  test('cancellation rejects late replies and retains draw', () async {
    await putReady();
    final started = Completer<void>(), reply = Completer<String>();
    final runtime = TarotRuntime(
      store: store,
      catalog: catalog(),
      promptVersion: 'v1',
      promptHash: 'hash',
      generateReading: (draw, token) {
        started.complete();
        return reply.future;
      },
    );
    addTearDown(runtime.dispose);
    final running = runtime.generate('fixture');
    await started.future;
    await runtime.cancel('fixture');
    reply.complete('This late result must never appear');
    await running;
    final draw = (await store.get('fixture'))!;
    expect(draw.result.state, TarotResultState.cancelled);
    expect(draw.result.text, isNull);
    expect(draw.context(), fixture().context());
  });

  test(
    'late attempt cannot overwrite a newer attempt or resurrect deleted data',
    () async {
      await putReady();
      await store.begin('fixture', 'old', 'v1', 'hash');
      await store.finish('fixture', 'old', TarotResultState.cancelled);
      await store.begin('fixture', 'new', 'v1', 'hash');
      await store.finish(
        'fixture',
        'old',
        TarotResultState.completed,
        text: 'stale',
      );
      expect((await store.get('fixture'))!.result.attemptId, 'new');
      await store.finish('fixture', 'new', TarotResultState.cancelled);
      await store.delete('fixture');
      await store.finish(
        'fixture',
        'new',
        TarotResultState.completed,
        text: 'stale',
      );
      expect(await store.get('fixture'), isNull);
    },
  );

  test(
    'failed durable begin never sends a request and releases the guard',
    () async {
      await File(
        '${store.directory.path}/state.json',
      ).writeAsString('corrupt-original');
      var calls = 0;
      final runtime = TarotRuntime(
        store: store,
        catalog: catalog(),
        promptVersion: 'v1',
        promptHash: 'hash',
        generateReading: (draw, token) async {
          calls++;
          return 'must not run';
        },
      );
      addTearDown(runtime.dispose);
      await expectLater(runtime.generate('fixture'), throwsFormatException);
      expect(calls, 0);
      expect(runtime.busy('fixture'), false);
      expect(
        await File('${store.directory.path}/state.json').readAsString(),
        'corrupt-original',
      );
    },
  );

  test(
    'a delayed cancellation from an old attempt cannot cancel the explicit retry',
    () async {
      await putReady();
      final startedFirst = Completer<void>(), startedSecond = Completer<void>();
      final firstReply = Completer<String>(), secondReply = Completer<String>();
      final cancelFinished = Completer<void>();
      var calls = 0;
      final runtime = TarotRuntime(
        store: store,
        catalog: catalog(),
        promptVersion: 'v1',
        promptHash: 'hash',
        generateReading: (draw, token) {
          calls++;
          if (calls == 1) {
            token.remoteCancel = () => cancelFinished.future;
            startedFirst.complete();
            return firstReply.future;
          }
          startedSecond.complete();
          return secondReply.future;
        },
      );
      addTearDown(runtime.dispose);
      final first = runtime.generate('fixture');
      await startedFirst.future;
      final oldCancel = runtime.cancel('fixture');
      firstReply.complete('late first reply');
      await first;
      final second = runtime.generate('fixture');
      await startedSecond.future;
      cancelFinished.complete();
      await oldCancel;
      expect(
        (await store.get('fixture'))!.result.state,
        TarotResultState.running,
      );
      secondReply.complete('explicit retry result');
      await second;
      expect(
        (await store.get('fixture'))!.result.text,
        'explicit retry result',
      );
      expect(calls, 2);
    },
  );

  group('text-only HTTP boundary', () {
    late HttpServer server;
    late TarotAiClient client;
    const profile = AiProfile(
      id: 'test',
      name: 'test',
      url: 'http://192.168.10.1:80/v1',
      model: 'test',
      provider: AiProvider.direct,
    );
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      client = TarotAiClient(
        File('assets/tarot-prompt-v1.json').readAsStringSync(),
        transport: AiTransport(
          allowLan: true,
          createHttpClient: () => HttpClient()
            ..connectionFactory = (_, _, _) =>
                Socket.startConnect(InternetAddress.loopbackIPv4, server.port),
        ),
      );
    });
    tearDown(() => server.close(force: true));
    test('only selected card text is sent, exactly one request', () async {
      var calls = 0;
      Map? body;
      final text = List.filled(
        45,
        'Çağrışımlar üzerine düşünebilirsin.',
      ).join(' ');
      server.listen((request) async {
        calls++;
        body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': text},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });
      expect(
        await client.generate(
          fixture().copy(mood: TarotMood.tense),
          profile,
          'fake-test-key',
          AiCancellation(),
        ),
        text,
      );
      expect(calls, 1);
      final wire = jsonEncode(body);
      expect(wire, contains('atlas-tarot-context-v1'));
      expect(wire, contains('Geçmiş'));
      expect(wire, isNot(contains('image_url')));
      expect(wire, isNot(contains('.webp')));
      expect(wire, isNot(contains('fake-test-key')));
      expect(wire, isNot(contains('mood')));
      expect(wire, isNot(contains('tense')));
    });
    for (final entry in {
      'empty': {'choices': []},
      'blank': {
        'choices': [
          {
            'message': {'content': '  '},
            'finish_reason': 'stop',
          },
        ],
      },
      'truncated': {
        'choices': [
          {
            'message': {'content': 'cut short'},
            'finish_reason': 'length',
          },
        ],
      },
    }.entries) {
      test('${entry.key} fails once without automatic retry', () async {
        var calls = 0;
        server.listen((request) async {
          calls++;
          request.response.write(jsonEncode(entry.value));
          await request.response.close();
        });
        await expectLater(
          client.generate(fixture(), profile, 'fake', AiCancellation()),
          throwsA(isA<AiFailure>()),
        );
        expect(calls, 1);
      });
    }
    test('gateway profiles fail before sending a coffee job', () async {
      var calls = 0;
      server.listen((_) {
        calls++;
      });
      await expectLater(
        client.generate(
          fixture(),
          const AiProfile(
            id: 'gateway',
            name: 'gateway',
            url: 'https://example.invalid',
            model: 'kimi',
            provider: AiProvider.atlas,
          ),
          'fake',
          AiCancellation(),
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 0);
    });
    test('timeout sends once and preserves failure for manual retry', () async {
      var calls = 0;
      server.listen((_) {
        calls++;
      });
      await expectLater(
        client.generate(
          fixture(),
          profile,
          'fake',
          AiCancellation(),
          timeout: const Duration(milliseconds: 150),
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(calls, 1);
    });
    test(
      'cancellation aborts transport and does not send another request',
      () async {
        var calls = 0;
        final received = Completer<void>();
        server.listen((_) {
          calls++;
          received.complete();
        });
        final token = AiCancellation();
        final future = client.generate(fixture(), profile, 'fake', token);
        final assertion = expectLater(future, throwsA(isA<AiFailure>()));
        await received.future;
        await token.cancel();
        await assertion;
        expect(calls, 1);
      },
    );
  });
}
