import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'ai_test.dart' show contextData;
import 'rich_fortune_test.dart' show richContext;

// These wrappers observe only synthetic response bodies. Requests and headers
// go straight to dart:io and are never retained or printed.
class _ObservedHttpClient implements HttpClient {
  _ObservedHttpClient(this.onResponse);
  final HttpClient _inner = HttpClient();
  final void Function(List<int>) onResponse;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ObservedRequest(await _inner.openUrl(method, url), onResponse);
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

void main() {
  test(
    'live Kimi handles absent and user-reported symbols with real app checks',
    () async {
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final key = bundledCredential(bundledKimiProfile);
      final cases = <Map<String, dynamic>>[];
      await Directory('build').create(recursive: true);
      final report = File('build/kimi-live-validation.json');
      Future<void> saveReport() => report.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'runAt': DateTime.now().toUtc().toIso8601String(),
          'synthetic': true,
          'promptVersion': prompt.version,
          'promptHash': prompt.hash,
          'cases': cases,
        }),
      );
      await saveReport();
      for (final hasSymbol in [false, true]) {
        const selectedCase = String.fromEnvironment('ATLAS_KIMI_LIVE_CASE');
        final caseId = hasSymbol ? 'user-reported-bird' : 'no-user-annotations';
        if (selectedCase.isNotEmpty && selectedCase != caseId) continue;
        final input = const bool.fromEnvironment('ATLAS_RICH_CONTEXT') ? richContext() : contextData();
        const cupCount = int.fromEnvironment(
          'ATLAS_KIMI_LIVE_CUPS',
          defaultValue: 3,
        );
        input['photos'] = (input['photos'] as List).take(cupCount).toList();
        if (hasSymbol) {
          input['photos'][0]['userObservations'] = [
            {
              'origin': 'userObservation',
              'symbolName': 'Kuş',
              'box': {'x': 0.25, 'y': 0.3, 'width': 0.15, 'height': 0.15},
            },
          ];
        }
        final context = validateAiContext(input);
        final responseAttempts = <Map<String, dynamic>>[];
        final client = AiClient(
          prompt,
          createHttpClient: () => _ObservedHttpClient((bytes) {
            final response = jsonDecode(utf8.decode(bytes)) as Map;
            final choice = (response['choices'] as List).first as Map;
            final text = (choice['message'] as Map)['content'] as String?;
            final finishReason = choice['finish_reason'] as String?;
            responseAttempts.add({
              'attempt': responseAttempts.length + 1,
              'finishReason': finishReason,
              'qualityError': fortuneQualityError(
                text,
                finishReason,
                context: context,
              ),
              'text': text,
            });
          }),
        );
        final record = <String, dynamic>{
          'id': caseId,
          'symbols': hasSymbol ? ['Kuş'] : <String>[],
          'responseAttempts': responseAttempts,
        };
        final watch = Stopwatch()..start();
        try {
          final result = await client.generate(
            bundledKimiProfile,
            key,
            context,
            cancellation: AiCancellation(),
            onStatus: (_) {},
          );
          final story = result['text'] as String;
          final qualityError = fortuneQualityError(
            story,
            'stop',
            context: context,
          );
          record.addAll({
            'model': result['model'],
            'durationMs': result['durationMs'],
            'attempts': result['attempts'],
            'temperature': result['temperature'],
            'promptVersion': result['promptVersion'],
            'promptHash': result['promptHash'],
            'wordCount': story.trim().split(RegExp(r'\s+')).length,
            'qualityError': qualityError,
            'passed':
                qualityError == null &&
                result['model'] == 'kimi-k2.6' &&
                result['temperature'] == 0.6 &&
                result['promptVersion'] == prompt.version &&
                result['promptHash'] == prompt.hash &&
                (result['attempts'] as int) <= 2,
            // Synthetic story is intentionally retained for human evaluation.
            'text': story,
          });
        } on AiFailure catch (error) {
          // The application supplies safe local messages, not remote bodies.
          record.addAll({'passed': false, 'error': error.message});
        } finally {
          record['elapsedMs'] = watch.elapsedMilliseconds;
          cases.add(record);
          // Select fields explicitly: no key, profile or HTTP headers are saved.
          await saveReport();
        }
      }
      expect(cases, isNotEmpty);
      expect(
        cases.where((record) => record['passed'] != true).map((r) => r['id']),
        isEmpty,
        reason: 'Inspect build/kimi-live-validation.json for safe results.',
      );
    },
    skip: !const bool.fromEnvironment('ATLAS_KIMI_LIVE_TEST'),
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
