import 'dart:convert';
import 'package:flutter_test/flutter_test.dart' hide completion;
import 'package:atlas_contribution_app/src/ai/reading_identity.dart';
import 'package:atlas_contribution_app/src/ai/fortune_memory.dart';
import 'fortune_memory_test.dart'
    show FixedIntervalRandom, memoryContext, memoryData, completion;

void main() {
  test(
    'topic belongs to request identity while legacy missing topic means general',
    () {
      final general = readingRequestKey('s', 'fp', 'general');
      expect(readingRequestKey('s', 'fp', 'money'), isNot(general));
      expect(physicalReadingKey(general), 's|fp');
      expect(
        resultReadingRequestKey({'sessionId': 's', 'sourceFingerprint': 'fp'}),
        general,
      );
    },
  );
  test(
    'legacy memory slots, intervals and excerpt history survive topic-aware completions',
    () {
      final e = FortuneMemoryEngine(random: FixedIntervalRandom(0));
      final old = {
        ...completion('legacy'),
        'sessionId': 's',
        'sourceFingerprint': 'fp',
        'context': {...memoryContext(), 'readingFocus': 'general'},
      };
      final data = <String, dynamic>{
        'results': [old],
        'starredResultIds': [],
        'fortuneMemoryV1': {
          'completedKeys': ['s|fp'],
          'nextAt': 5,
          'usedParts': [
            {'sourceId': 'kept', 'partHash': 'kept-hash', 'at': 1},
          ],
          'pending': {
            'kept-pending': {'sourceId': 'kept', 'partHash': 'pending-hash'},
          },
        },
      };
      final beforeHistory = jsonEncode(data['fortuneMemoryV1']['usedParts']);
      Map<String, dynamic> result(String topic, {String state = 'completed'}) =>
          {
            ...old,
            'id': 'new-$topic',
            'state': state,
            'readingRequestKey': readingRequestKey('s', 'fp', topic),
            'context': {...memoryContext(), 'readingFocus': topic},
          };
      e.complete(data, result('general'));
      expect(data['fortuneMemoryV1']['completedKeys'], ['s|fp']);
      final money = result('money');
      e.complete(data, money);
      (data['results'] as List).add(money);
      e.complete(data, money);
      e.complete(data, result('work', state: 'failed'));
      expect(data['fortuneMemoryV1']['completedKeys'], [
        's|fp',
        readingRequestKey('s', 'fp', 'money'),
      ]);
      e.complete(data, result('work'));
      expect(data['fortuneMemoryV1']['completedKeys'].length, 3);
      expect(data['fortuneMemoryV1']['nextAt'], 5);
      expect(jsonEncode(data['fortuneMemoryV1']['usedParts']), beforeHistory);
      expect(
        data['fortuneMemoryV1']['pending'].containsKey('kept-pending'),
        true,
      );
    },
  );
  test('a different topic cannot quote its own physical source', () {
    final data = memoryData();
    final e = FortuneMemoryEngine(random: FixedIntervalRandom(0));
    expect(
      e.prepare(
        data,
        readingKey: readingRequestKey('session-old', 'fingerprint-old', 'love'),
        focus: 'love',
        context: memoryContext(),
      ),
      isNull,
    );
  });
  test(
    'interrupted legacy request keeps its pending memory choice through new identity',
    () {
      final data = memoryData();
      final e = FortuneMemoryEngine(random: FixedIntervalRandom(0));
      const legacy = 'session-new|fingerprint-new';
      final previous = e.prepare(
        data,
        readingKey: legacy,
        focus: 'love',
        context: memoryContext(),
      );
      expect(previous, isNotNull);
      (data['results'] as List).add({
        ...completion('new', state: 'interrupted'),
        'context': {...memoryContext(), 'readingFocus': 'love'},
      });
      final key = readingRequestKey('session-new', 'fingerprint-new', 'love');
      final current = e.prepare(
        data,
        readingKey: key,
        focus: 'love',
        context: memoryContext(),
      );
      expect(current?.receipt, previous!.receipt);
      expect(e.isCurrent(data, key, current!), true);
    },
  );
}
