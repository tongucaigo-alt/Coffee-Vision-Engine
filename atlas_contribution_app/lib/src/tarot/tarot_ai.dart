import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../ai/ai_bundled.dart';
import '../ai/ai_client.dart' show AiCancellation;
import '../ai/ai_contract.dart';
import '../ai/ai_transport.dart';
import 'tarot_models.dart';

class TarotAiClient {
  TarotAiClient(String raw, {AiTransport? transport})
    : prompt = Map<String, dynamic>.from(jsonDecode(raw) as Map),
      hash = sha256.convert(utf8.encode(raw)).toString(),
      transport = transport ?? AiTransport() {
    if (version != 'atlas-tarot-prompt-v1') {
      throw const FormatException('Tarot yorum sürümü desteklenmiyor.');
    }
  }
  final Map<String, dynamic> prompt;
  final String hash;
  final AiTransport transport;
  String get version => prompt['version'] as String;
  Future<String> generate(
    TarotDraw draw,
    AiProfile profile,
    String key,
    AiCancellation cancellation, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    cancellation.check();
    if (profile.provider != AiProvider.direct) {
      throw const AiFailure(
        'Tarot yorum hizmeti bu bağlantıda henüz kullanılamıyor. Kartların telefonda korunuyor.',
      );
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
}
