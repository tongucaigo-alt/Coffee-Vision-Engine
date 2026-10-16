import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/fortune_personalization.dart';
import 'package:atlas_contribution_app/src/ai/narrative.dart'
    show narrativeRepetition;
import 'fortune_personalization_test.dart' show personalizedTestContext;

DateTime? _lastRequest;

// These wrappers observe only synthetic response bodies. Requests and headers
// go straight to dart:io and are never retained or printed.
class _ObservedHttpClient implements HttpClient {
  _ObservedHttpClient(this.onResponse);
  final HttpClient _inner = HttpClient();
  final void Function(List<int>) onResponse;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final elapsed = _lastRequest == null
        ? 26000
        : DateTime.now().difference(_lastRequest!).inMilliseconds;
    if (elapsed < 26000) {
      await Future<void>.delayed(Duration(milliseconds: 26000 - elapsed));
    }
    _lastRequest = DateTime.now();
    return _ObservedRequest(await _inner.openUrl(method, url), onResponse);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedRequest implements HttpClientRequest {
  _ObservedRequest(this._inner, this.onResponse);
  final HttpClientRequest _inner;
  final void Function(List<int>) onResponse;
  @override
  HttpHeaders get headers => _inner.headers;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;
  @override
  void write(Object? value) => _inner.write(value);
  @override
  Future<HttpClientResponse> close() async =>
      _ObservedResponse(await _inner.close(), onResponse);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ObservedResponse(this._inner, this.onResponse);
  final HttpClientResponse _inner;
  final void Function(List<int>) onResponse;
  @override
  int get statusCode => _inner.statusCode;

  Stream<List<int>> _observe() async* {
    final bytes = <int>[];
    await for (final chunk in _inner) {
      bytes.addAll(chunk);
      yield chunk;
    }
    if (statusCode >= 200 && statusCode < 300) onResponse(bytes);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _observe().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Seven synthetic cases adapted to the shipping v3 schema. Original physical-only
// control now receives one stable creative motif, as required by that schema.
List<Map<String, dynamic>> scenarios() {
  final cases = <Map<String, dynamic>>[];
  for (final spec in [
    ['01-default-motif', null, null, 'bird'],
    ['02-same-cup-key', null, null, 'key'],
    ['03-same-cup-key-libra', null, 'libra', 'key'],
    ['04-user-bird-libra', 'Kuş', 'libra', null],
    ['05-fish-leo', null, 'leo', 'fish'],
    ['06-road-no-zodiac', null, null, 'road'],
    ['07-user-heart-capricorn-saucer', 'Kalp', 'capricorn', null],
    ['08-same-key-bottom-distribution', null, null, 'key'],
  ]) {
    final context =
        jsonDecode(
              jsonEncode(
                personalizedTestContext(symbol: spec[1], zodiac: spec[2]),
              ),
            )
            as Map<String, dynamic>;
    if (spec[3] != null) {
      context['creativeSymbol']['symbolId'] = spec[3];
      context['creativeSymbol']['symbolName'] = {
        'bird': 'Kuş',
        'key': 'Anahtar',
        'fish': 'Balık',
        'road': 'Yol',
      }[spec[3]];
    }
    // Cases 1-4 share one physical distribution; 5 shares the key fixture's
    // bottom-heavy distribution; 6 and 7 vary the position and the surface.
    if (cases.length < 4) {
      context['photos'][0]['regionalSummary']['bands'] = [
        {'position': 'top', 'density': .6},
        {'position': 'middle', 'density': .2},
        {'position': 'bottom', 'density': .1},
        {'position': 'left', 'density': .1},
        {'position': 'center', 'density': .2},
        {'position': 'right', 'density': .6},
      ];
    }
    if (cases.length == 5) {
      context['photos'][0]['regionalSummary']['bands'] = [
        {'position': 'top', 'density': .1},
        {'position': 'middle', 'density': .6},
        {'position': 'bottom', 'density': .2},
        {'position': 'left', 'density': .6},
        {'position': 'center', 'density': .2},
        {'position': 'right', 'density': .1},
      ];
    }
    if (cases.length == 6) {
      final saucer =
          jsonDecode(jsonEncode(context['photos'][0])) as Map<String, dynamic>;
      saucer['photoNumber'] = 2;
      saucer['surface'] = 'saucer';
      saucer['declaredRole'] = null;
      saucer['userObservations'] = [];
      context['photos'].add(saucer);
    }
    cases.add({'id': spec[0], 'context': validateAiContext(context)});
  }
  if (const bool.fromEnvironment('ATLAS_PERSONALIZED_REPEAT_KEY')) {
    final original = cases.firstWhere((row) => row['id'] == '02-same-cup-key');
    cases.add({'id': '09-repeated-key-top', 'context': original['context']});
  }
  return cases;
}

// Lab-only representation experiment: the validated v3 context and all
// application output checks stay unchanged. Production message formatting is
// used unless the explicit test define selects this derived brief.
class CompactLabPrompt extends FortunePrompt {
  CompactLabPrompt(super.raw);

  @override
  List<Map<String, String>> messages(
    Map<String, dynamic> context, {
    required bool noThink,
    bool repair = false,
    String? repairReason,
    String? previousReply,
  }) {
    final standard = super.messages(
      context,
      noThink: noThink,
      repair: repair,
      repairReason: repairReason,
      previousReply: previousReply,
    );
    final brief = [
      'Anlatı konusu: ${context['narrative']?['topic'] ?? 'gündelik ihtimaller'}.',
      personalizedBrief(context),
      'İzinli fiziksel cümleler: ${jsonEncode(physicalCues(context))}.',
      'Sembolün anlamını kullan. Fiziksel cümleyi ayrı bir cümlede aynen kullan; sembolün bulunduğu yer diye anlatma.',
    ].join('\n');
    final original = standard.last['content']!;
    const repairMarker = 'Önceki adayın kelime sayısı:';
    final repairAt = original.indexOf(repairMarker);
    return [
      standard.first,
      if (repair && previousReply != null)
        {'role': 'assistant', 'content': previousReply},
      {
        'role': 'user',
        'content':
            '${data['personalizedUserPrefix']}$brief${repairAt < 0 ? '' : '\n${original.substring(repairAt)}'}',
      },
    ];
  }
}

class ExampleLabPrompt extends CompactLabPrompt {
  ExampleLabPrompt(super.raw);

  @override
  List<Map<String, String>> messages(
    Map<String, dynamic> context, {
    required bool noThink,
    bool repair = false,
    String? repairReason,
    String? previousReply,
  }) {
    final turns = super.messages(
      context,
      noThink: noThink,
      repair: repair,
      repairReason: repairReason,
      previousReply: previousReply,
    );
    final example = data['labStyleExample'] as Map;
    return [
      turns.first,
      {'role': 'user', 'content': example['user'] as String},
      {'role': 'assistant', 'content': example['assistant'] as String},
      if (repair && previousReply != null)
        super.messages(context, noThink: noThink).last,
      ...turns.skip(1),
    ];
  }
}

void main() {
  test(
    'compact lab brief preserves sources and leaves production input unchanged',
    () async {
      final prompt = CompactLabPrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final context = personalizedTestContext(zodiac: 'libra');
      final before = jsonEncode(context);
      final brief = prompt.messages(context, noThink: false).last['content']!;
      expect(brief, contains('Yaratıcı anlatı sembolü: Anahtar'));
      expect(brief, contains('izin verdiği burç: Terazi'));
      expect(brief, contains(physicalCues(context).first));
      for (final internal in [
        'residuePixelCount',
        'photoNumber',
        'globalPhysicalMeasurements',
        'box',
      ]) {
        expect(brief, isNot(contains(internal)));
      }
      expect(jsonEncode(context), before);
      final repair = prompt.messages(
        context,
        noThink: false,
        repair: true,
        previousReply: 'Yalnız bir kısa taslak.',
        repairReason: 'length',
      );
      expect(repair[1]['role'], 'assistant');
      expect(
        repair.last['content'],
        contains('Önceki adayın kelime sayısı: 4'),
      );
      expect(repair.last['content'], contains('250–400'));
    },
  );
  test(
    'style example and repair have distinct, ordered conversation turns',
    () async {
      final data =
          jsonDecode(await File('assets/fortune-prompt-v1.json').readAsString())
              as Map<String, dynamic>;
      data['labStyleExample'] = {
        'user': 'Örnek girdi',
        'assistant': 'Örnek üslup',
      };
      final prompt = ExampleLabPrompt(jsonEncode(data));
      final context = personalizedTestContext(symbol: 'Kuş');
      final initial = prompt.messages(context, noThink: false);
      expect(initial.map((m) => m['role']), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      expect(initial[2]['content'], 'Örnek üslup');
      expect(initial.last['content'], contains('bildirdiği semboller: Kuş'));
      final repair = prompt.messages(
        context,
        noThink: false,
        repair: true,
        previousReply: 'Gerçek aday',
        repairReason: 'length',
      );
      expect(repair.map((m) => m['role']), [
        'system',
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      expect(repair[4]['content'], 'Gerçek aday');
    },
  );

  test(
    'synthetic v3 Kimi validation with actual application prompt and bounded repair',
    () async {
      final rawPrompt = await File(
        const String.fromEnvironment(
          'ATLAS_PERSONALIZED_PROMPT',
          defaultValue: 'assets/fortune-prompt-v1.json',
        ),
      ).readAsString();
      const compact = bool.fromEnvironment('ATLAS_PERSONALIZED_COMPACT');
      final prompt = compact
          ? (jsonDecode(rawPrompt)['labStyleExample'] != null
                ? ExampleLabPrompt(rawPrompt)
                : CompactLabPrompt(rawPrompt))
          : FortunePrompt(rawPrompt);
      final cases = <Map<String, dynamic>>[];
      await Directory('build').create(recursive: true);
      final report = File(
        const String.fromEnvironment(
          'ATLAS_PERSONALIZED_REPORT',
          defaultValue: 'build/personalized-live-validation.json',
        ),
      );
      Future<void> save() => report.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'synthetic': true,
          'containsRealUserData': false,
          'inputMode': compact
              ? (prompt is ExampleLabPrompt
                    ? 'derivedBriefWithStyleExampleLabOnly'
                    : 'derivedBriefLabOnly')
              : 'applicationMessages',
          'qualityRevision': const String.fromEnvironment(
            'ATLAS_PERSONALIZED_QUALITY_REVISION',
            defaultValue: 'current-v3-checks',
          ),
          'checksExampleCopy':
              prompt.data['personalizedFormat'] == 'source-brief-example-v1' ||
              const bool.fromEnvironment(
                'ATLAS_PERSONALIZED_CHECK_EXAMPLE_COPY',
              ),
          'promptVersion': prompt.version,
          'promptHash': prompt.hash,
          'cases': cases,
        }),
      );
      for (final row in scenarios()) {
        const selected = String.fromEnvironment('ATLAS_PERSONALIZED_CASE');
        if (selected.isNotEmpty && !selected.split(',').contains(row['id'])) {
          continue;
        }
        final context =
            jsonDecode(jsonEncode(row['context'])) as Map<String, dynamic>;
        final topics = {
          for (final pair in const String.fromEnvironment(
            'ATLAS_PERSONALIZED_TOPICS',
          ).split(','))
            if (pair.contains('=')) pair.split('=').first: pair.split('=').last,
        };
        final topic =
            topics[row['id']] ??
            const String.fromEnvironment('ATLAS_PERSONALIZED_TOPIC');
        if (topic.isNotEmpty) {
          context['narrative'] = {
            ...context['narrative'] as Map,
            'topic': topic,
          };
          validateAiContext(context);
        }
        final attempts = <Map<String, dynamic>>[];
        final record = <String, dynamic>{
          'id': row['id'],
          'context': context,
          'messages': prompt.messages(context, noThink: false),
          'responseAttempts': attempts,
        };
        final client = AiClient(
          prompt,
          createHttpClient: () => _ObservedHttpClient((bytes) {
            final response = jsonDecode(utf8.decode(bytes)) as Map;
            final choice = response['choices'][0] as Map;
            final text = choice['message']['content'] as String?;
            attempts.add({
              'text': text,
              'finishReason': choice['finish_reason'],
              'responseModel': response['model'],
              'usage': response['usage'],
              'qualityError':
                  fortuneQualityError(
                    text,
                    choice['finish_reason'],
                    context: context,
                  ) ??
                  (text == null
                      ? null
                      : narrativeRepetition(
                          text,
                          prompt.repetitionReferences(context, const []),
                        )),
            });
          }),
        );
        final watch = Stopwatch()..start();
        try {
          final result = await client.generate(
            bundledKimiProfile,
            bundledCredential(bundledKimiProfile),
            context,
            cancellation: AiCancellation(),
            onStatus: (_) {},
            previousTexts:
                const bool.fromEnvironment(
                      'ATLAS_PERSONALIZED_CHECK_EXAMPLE_COPY',
                    ) &&
                    prompt.data['labStyleExample'] is Map
                ? [
                    (prompt.data['labStyleExample'] as Map)['assistant']
                        as String,
                  ]
                : const [],
          );
          record.addAll({
            'passed': true,
            'text': result['text'],
            'attempts': result['attempts'],
            'model': result['model'],
            'temperature': result['temperature'],
            'wordCount': (result['text'] as String)
                .trim()
                .split(RegExp(r'\s+'))
                .length,
          });
        } on AiFailure catch (error) {
          record.addAll({'passed': false, 'error': error.message});
        } finally {
          record['elapsedMs'] = watch.elapsedMilliseconds;
          cases.add(record);
          await save();
          debugPrint(
            'Synthetic ${row['id']}: ${record['passed'] == true ? 'passed' : 'failed'} (${attempts.length} responses)',
          );
        }
      }
      expect(cases, isNotEmpty);
      expect(
        cases.where((c) => c['passed'] != true).map((c) => c['id']),
        isEmpty,
        reason:
            'Inspect ${report.path}; never treat rejected stories as ready.',
      );
    },
    skip: !const bool.fromEnvironment('ATLAS_PERSONALIZED_LIVE'),
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
