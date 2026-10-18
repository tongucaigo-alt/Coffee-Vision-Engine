import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/fortune_personalization.dart';
import 'package:atlas_contribution_app/src/ai/narrative.dart'
    show narrativeRepetition;
import 'package:atlas_contribution_app/src/user_profile_store.dart';

import 'rich_fortune_test.dart' show richContext;

const _liveRequested = bool.fromEnvironment('ATLAS_V82_LIVE');
const _minimumPostInterval = Duration(seconds: 26);
DateTime? _lastPost;

/// Only response fields from these synthetic cases are observed. Request bodies,
/// request/response headers and credentials are never retained or printed.
class _ObservedHttpClient implements HttpClient {
  _ObservedHttpClient(this.onPost, this.onResponse);
  final HttpClient _inner = HttpClient();
  final void Function() onPost;
  final void Function(int, List<int>) onResponse;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (method == 'POST') {
      final since = _lastPost == null
          ? _minimumPostInterval
          : DateTime.now().difference(_lastPost!);
      if (since < _minimumPostInterval) {
        await Future<void>.delayed(_minimumPostInterval - since);
      }
      _lastPost = DateTime.now();
      onPost();
    }
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
  final void Function(int, List<int>) onResponse;

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
  final void Function(int, List<int>) onResponse;

  @override
  int get statusCode => _inner.statusCode;

  Stream<List<int>> _observe() async* {
    final bytes = <int>[];
    await for (final chunk in _inner) {
      bytes.addAll(chunk);
      yield chunk;
    }
    // Error bodies are neither decoded nor retained by the observer.
    onResponse(statusCode, statusCode >= 200 && statusCode < 300 ? bytes : []);
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

class _Scenario {
  const _Scenario(
    this.id,
    this.focus,
    this.age,
    this.symbols, {
    this.motif,
    this.pastExcerpt,
  });
  final String id, focus;
  final int? age;
  final List<String> symbols;
  final String? motif, pastExcerpt;

  Map<String, dynamic> context(int index) {
    final base = richContext();
    final photo = (base['photos'] as List).first as Map;
    photo['userObservations'] = [
      for (var i = 0; i < symbols.length; i++)
        {
          'origin': 'userObservation',
          'symbolName': symbols[i],
          'box': {'x': .18 + i * .3, 'y': .3, 'width': .18, 'height': .2},
        },
    ];
    // Keep the schema and physical summary intact while rotating the synthetic
    // distribution, rather than reusing one physical scene for every story.
    for (final item in base['photos'] as List) {
      item['regionalSummary']['bands'] = [
        {'position': 'top', 'density': index % 3 == 0 ? .6 : .1},
        {'position': 'middle', 'density': index % 3 == 1 ? .6 : .2},
        {'position': 'bottom', 'density': index % 3 == 2 ? .6 : .1},
        {'position': 'left', 'density': index.isEven ? .6 : .1},
        {'position': 'center', 'density': .2},
        {'position': 'right', 'density': index.isOdd ? .6 : .1},
      ];
    }
    final previous = motif == null
        ? null
        : <String, dynamic>{
            'creativeSymbol': {
              'catalogVersion': creativeCatalogVersion,
              'origin': 'creativeSelectionNotVisualDetection',
              'symbolId': motif,
              'symbolName': {'bird': 'Kuş', 'heart': 'Kalp'}[motif],
            },
          };
    return validateAiContext(
      personalizeFortuneContext(
        base,
        readingIdentity: 'synthetic-v82-$id',
        readingFocus: focus,
        profile: UserProfile(age: age),
        previousContext: previous,
        pastReadingExcerpt: pastExcerpt,
      ),
    );
  }
}

const _scenarios = [
  _Scenario('01-general-no-age-road-key', 'general', null, ['Yol', 'Anahtar']),
  _Scenario('02-general-age25-creative-bird', 'general', 25, [], motif: 'bird'),
  _Scenario(
    '03-general-age45-road-key-memory',
    'general',
    45,
    ['Yol', 'Anahtar'],
    pastExcerpt:
        'Kısa bir yolculuk için iki seçenek arasında karar vereceksin. '
        'Bir ziyaret planı bu seçimi yeniden düşünmene neden olacak.',
  ),
  _Scenario('04-general-age65-tree-road', 'general', 65, ['Ağaç', 'Yol']),
  _Scenario(
    '05-love-age25-heart-bird-memory',
    'love',
    25,
    ['Kalp', 'Kuş'],
    pastExcerpt:
        'Aşk tarafında yarım kalan bir konuşma yeniden açılacak. '
        'Bir mesaj, geçmişteki duygusal bağa başka bir yerden bakmanı sağlayacak.',
  ),
  _Scenario('06-love-age65-creative-heart', 'love', 65, [], motif: 'heart'),
  _Scenario('07-work-age45-key-ladder', 'work', 45, ['Anahtar', 'Merdiven']),
  _Scenario('08-money-age65-fish', 'money', 65, ['Balık']),
];

Map<String, int> _usage(Object? value) => value is Map
    ? {
        for (final key in [
          'prompt_tokens',
          'completion_tokens',
          'total_tokens',
        ])
          if (value[key] is int) key: value[key] as int,
      }
    : {};

void main() {
  test(
    'v82 live matrix is synthetic, v4-valid and bounded before any network',
    () {
      expect(_scenarios, hasLength(8));
      expect(_scenarios.where((s) => s.focus == 'general'), hasLength(4));
      expect(_scenarios.where((s) => s.focus == 'love'), hasLength(2));
      expect(_scenarios.where((s) => s.focus == 'work'), hasLength(1));
      expect(_scenarios.where((s) => s.focus == 'money'), hasLength(1));
      for (var i = 0; i < _scenarios.length; i++) {
        final spec = _scenarios[i];
        final context = spec.context(i);
        expect(context['version'], currentFortuneContextVersion);
        expect(context['readingFocus'], spec.focus);
        expect((context['personalization'] as Map?)?['age'], spec.age);
        expect(context['pastReadingExcerpt'], spec.pastExcerpt);
        expect(context.containsKey('addressName'), false);
      }
      expect(_scenarios.where((s) => s.pastExcerpt != null), hasLength(2));
    },
  );

  test(
    'eight serial synthetic v82 fortunes use unmodified application generation',
    () async {
      // An explicit gate and a separately provisioned test credential are both
      // required. The credential remains inside the production transport.
      expect(_liveRequested && bundledKimiEnabled, true);
      _lastPost = null;
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final report = File(
        const String.fromEnvironment(
          'ATLAS_V82_REPORT',
          defaultValue: 'build/live-v82.json',
        ),
      );
      await report.parent.create(recursive: true);
      final records = <Map<String, dynamic>>[];
      final previousSyntheticTexts = <String>[];
      final startedAt = DateTime.now().toUtc().toIso8601String();
      Future<void> save() => report.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'synthetic': true,
          'containsRealUserData': false,
          'startedAt': startedAt,
          'inputMode': 'applicationMessages',
          'contextVersion': currentFortuneContextVersion,
          'promptVersion': prompt.version,
          'promptHash': prompt.hash,
          'minimumPostIntervalMs': _minimumPostInterval.inMilliseconds,
          'maximumAttemptsPerScenario': 2,
          'cases': records,
        }),
        flush: true,
      );
      await save();
      for (var i = 0; i < _scenarios.length; i++) {
        final spec = _scenarios[i];
        final context = spec.context(i);
        final prior = [
          ...previousSyntheticTexts,
          if (spec.pastExcerpt != null) spec.pastExcerpt!,
        ];
        final references = prompt.repetitionReferences(context, prior);
        final attempts = <Map<String, dynamic>>[];
        final watch = Stopwatch()..start();
        var posts = 0;
        final client = AiClient(
          prompt,
          createHttpClient: () => _ObservedHttpClient(() => posts++, (
            status,
            bytes,
          ) {
            if (status < 200 || status >= 300) {
              attempts.add({
                'attempt': posts,
                'httpStatus': status,
                'elapsedMs': watch.elapsedMilliseconds,
              });
              return;
            }
            try {
              final body = jsonDecode(utf8.decode(bytes)) as Map;
              final choice = (body['choices'] as List).first as Map;
              final text = (choice['message'] as Map)['content'] as String?;
              final finish = choice['finish_reason'] as String?;
              final quality =
                  fortuneQualityError(text, finish, context: context) ??
                  (text == null ? null : narrativeRepetition(text, references));
              attempts.add({
                'attempt': posts,
                'httpStatus': status,
                'elapsedMs': watch.elapsedMilliseconds,
                'text': text,
                'finishReason': finish,
                'usage': _usage(body['usage']),
                'qualityError': quality,
                if (text != null)
                  'qualityWarnings': fortuneQualityWarnings(text, context),
              });
            } catch (_) {
              // Never turn a malformed remote body into a log message.
              attempts.add({
                'attempt': posts,
                'httpStatus': status,
                'elapsedMs': watch.elapsedMilliseconds,
                'qualityError': 'invalid_response',
              });
            }
          }),
        );
        final record = <String, dynamic>{
          'id': spec.id,
          'responseAttempts': attempts,
        };
        try {
          final result = await client.generate(
            bundledKimiProfile,
            bundledCredential(bundledKimiProfile),
            context,
            cancellation: AiCancellation(),
            onStatus: (_) {},
            previousTexts: prior,
          );
          final text = result['text'] as String;
          final quality =
              fortuneQualityError(text, 'stop', context: context) ??
              narrativeRepetition(text, references);
          record.addAll({
            'passed':
                quality == null &&
                posts <= 2 &&
                result['attempts'] == posts &&
                result['model'] == 'kimi-k2.6' &&
                result['temperature'] == .6 &&
                result['promptHash'] == prompt.hash,
            'firstCallAccepted': result['attempts'] == 1 && quality == null,
            'attempts': result['attempts'],
            'text': text,
            'wordCount': text.trim().split(RegExp(r'\s+')).length,
            'qualityError': quality,
            'qualityWarnings': result['qualityWarnings'],
            'memoryUsed': text.contains('Eski fallarından birinde'),
            'model': result['model'],
            'temperature': result['temperature'],
            'generationDurationMs': result['durationMs'],
          });
          previousSyntheticTexts.add(text);
        } on AiFailure catch (error) {
          record.addAll({
            'passed': false,
            'firstCallAccepted': false,
            'attempts': posts,
            'diagnostics': safeAiDiagnostics(error.diagnostics),
          });
        } catch (_) {
          record.addAll({
            'passed': false,
            'firstCallAccepted': false,
            'attempts': posts,
            'testError': 'unexpected_generation_failure',
          });
        } finally {
          record['elapsedMs'] = watch.elapsedMilliseconds;
          records.add(record);
          await save();
          debugPrint(
            'Synthetic ${spec.id}: ${record['passed'] == true ? 'passed' : 'failed'} '
            '($posts calls, ${record['elapsedMs']} ms)',
          );
        }
      }
      expect(records, hasLength(8));
      expect(records.every((r) => (r['attempts'] as int) <= 2), true);
      expect(
        records.where((r) => r['passed'] != true).map((r) => r['id']),
        isEmpty,
        reason:
            'Inspect synthetic live-v82 report; rejected stories are not ready.',
      );
    },
    skip: !_liveRequested || !bundledKimiEnabled,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
