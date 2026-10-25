import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../ai/ai_bundled.dart';
import '../ai/ai_client.dart' show AiCancellation;
import '../ai/ai_contract.dart';
import '../ai/ai_transport.dart';
import 'tarot_models.dart';

class TarotAiClient {
  TarotAiClient(
    String raw, {
    AiTransport? transport,
    this.pollInterval = const Duration(seconds: 3),
  }) : prompt = Map<String, dynamic>.from(jsonDecode(raw) as Map),
       hash = sha256.convert(utf8.encode(raw)).toString(),
       transport = transport ?? AiTransport() {
    if (version != 'atlas-tarot-prompt-v1') {
      throw const FormatException('Tarot yorum sürümü desteklenmiyor.');
    }
  }
  final Map<String, dynamic> prompt;
  final String hash;
  final AiTransport transport;
  final Duration pollInterval;
  String get version => prompt['version'] as String;
  Future<String> generate(
    TarotDraw draw,
    AiProfile profile,
    String key,
    AiCancellation cancellation, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    cancellation.check();
    if (profile.provider == AiProvider.atlas) {
      return _gateway(draw, profile, key, cancellation, timeout);
    }
    final context = draw.context();
    if (key.isEmpty) {
      throw const AiFailure(
        'Tarot yorum bağlantısı henüz hazır değil. Kartların telefonda korunuyor.',
      );
    }
    final instant = usesKimiInstant(profile);
    try {
      // One request per explicit action. No automatic content repair/retry.
      final response = await transport.request(
        profile,
        'POST',
        '/chat/completions',
        key,
        timeout: timeout,
        onClient: (client) {
          cancellation.remoteCancel = () async => client.close(force: true);
          if (cancellation.cancelled) client.close(force: true);
        },
        body: {
          'model': profile.model,
          'stream': false,
          if (instant) 'thinking': {'type': 'disabled'},
          'temperature': prompt['temperature'],
          'max_tokens': prompt['maxTokens'],
          'messages': [
            {'role': 'system', 'content': prompt['system']},
            {
              'role': 'user',
              'content':
                  '${prompt[draw.spread.name]}\n${jsonEncode(context)}${profile.noThink && !instant ? '\n/no_think' : ''}',
            },
          ],
        },
      );
      cancellation.check();
      final choices = response['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const AiFailure(
          'Tarot yanıtı okunamadı. Aynı kartlarla yeniden deneyebilirsin.',
        );
      }
      final choice = choices.first as Map;
      final message = choice['message'];
      final content = message is Map ? message['content'] : null;
      if (content is! String || choice['finish_reason'] != 'stop') {
        throw const AiFailure(
          'Tarot yorumu tamamlanmadı. Aynı kartlarla yeniden deneyebilirsin.',
        );
      }
      final text = content.trim();
      final count = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
      if (count < (draw.spread == TarotSpread.three ? 40 : 20) ||
          count > 900 ||
          RegExp(
            r'<\/?think|analysis:|reasoning:|```|\b(system|assistant)\s*:',
            caseSensitive: false,
          ).hasMatch(text)) {
        throw const AiFailure(
          'Tarot yanıtı sunulabilecek biçimde değil. Kartların korunuyor.',
        );
      }
      return text;
    } finally {
      cancellation.remoteCancel = null;
    }
  }

  Future<String> _gateway(
    TarotDraw draw,
    AiProfile profile,
    String key,
    AiCancellation cancellation,
    Duration timeout,
  ) async {
    if (key.isEmpty) {
      throw const AiFailure('Atlas test bağlantısını ayarlamalısın.');
    }
    final watch = Stopwatch()..start();
    HttpClient? active;
    String? jobId;
    Future<void> cancelRemote() async {
      active?.close(force: true);
      if (jobId != null) {
        try {
          await transport.request(
            profile,
            'DELETE',
            '/api/ai/v1/jobs/$jobId',
            key,
          );
        } catch (_) {
          /* A failed cancellation is never a generation retry. */
        }
      }
    }

    cancellation.remoteCancel = cancelRemote;
    Future<Map<String, dynamic>> request(
      String method,
      String suffix, {
      Map<String, dynamic>? body,
      Map<String, String> headers = const {},
    }) {
      cancellation.check();
      final remaining = timeout.inMilliseconds - watch.elapsedMilliseconds;
      if (remaining <= 0) throw const AiFailure('Tarot yorum süresi doldu.');
      return transport.request(
        profile,
        method,
        suffix,
        key,
        body: body,
        headers: headers,
        timeout: Duration(milliseconds: remaining.clamp(1, 10000)),
        onClient: (client) {
          active = client;
          if (cancellation.cancelled) client.close(force: true);
        },
      );
    }

    try {
      final capabilities = await request('GET', '/api/ai/v1/capabilities');
      cancellation.check();
      final tarot = capabilities['tarot'];
      if (capabilities['available'] != true ||
          tarot is! Map ||
          tarot['promptVersion'] != version ||
          tarot['promptHash'] != hash ||
          !(capabilities['contextVersions'] is List &&
              (capabilities['contextVersions'] as List).contains(
                'atlas-tarot-context-v1',
              ))) {
        throw const AiFailure(
          'Atlas sunucusu bu Tarot sürümünü desteklemiyor. Bağlantıyı güncelle.',
        );
      }
      final job = await request(
        'POST',
        '/api/ai/v1/jobs',
        body: {
          'context': draw.context(),
          'modelAlias': profile.model,
          'promptVersion': version,
          'generationLimits': {
            'maxAttempts': 1,
            'maxDurationMs':
                (timeout.inMilliseconds - watch.elapsedMilliseconds).clamp(
                  1,
                  180000,
                ),
          },
        },
        headers: {'Idempotency-Key': const Uuid().v4()},
      );
      final id = job['jobId'];
      if (id is! String ||
          !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
          job['serverInstanceId'] is! String) {
        throw const AiFailure('Tarot iş bilgisi okunamadı.');
      }
      jobId = id;
      if (cancellation.cancelled) await cancelRemote();
      cancellation.check();
      while (watch.elapsed < timeout) {
        final status = await request('GET', '/api/ai/v1/jobs/$jobId');
        cancellation.check();
        if (status['serverInstanceId'] != job['serverInstanceId']) {
          throw const AiFailure(
            'Atlas sunucusu yeniden başladı. Kartların korunuyor.',
          );
        }
        if (status['state'] == 'completed') {
          final result = status['result'];
          if (result is! Map ||
              result['promptVersion'] != version ||
              result['promptHash'] != hash ||
              result['attempts'] != 1) {
            throw const AiFailure('Tarot yanıt sürümü doğrulanamadı.');
          }
          final text = result['text'];
          final words = text is String && text.trim().isNotEmpty
              ? text.trim().split(RegExp(r'\s+')).length
              : 0;
          if (words < (draw.spread == TarotSpread.three ? 40 : 20) ||
              words > 900 ||
              RegExp(
                r'<\/?think|analysis:|reasoning:|```|\b(system|assistant)\s*:',
                caseSensitive: false,
              ).hasMatch(text as String? ?? '')) {
            throw const AiFailure(
              'Tarot yanıtı sunulabilecek biçimde değil. Kartların korunuyor.',
            );
          }
          return (text as String).trim();
        }
        if (!['queued', 'running'].contains(status['state'])) {
          throw const AiFailure(
            'Tarot yorumu tamamlanamadı. Aynı kartlarla yeniden deneyebilirsin.',
          );
        }
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) break;
        await Future<void>.delayed(
          remaining < pollInterval ? remaining : pollInterval,
        );
      }
      throw const AiFailure('Tarot yorum süresi doldu. Kartların korunuyor.');
    } catch (_) {
      await cancelRemote();
      rethrow;
    } finally {
      if (identical(cancellation.remoteCancel, cancelRemote)) {
        cancellation.remoteCancel = null;
      }
    }
  }
}
