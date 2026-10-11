import 'dart:convert';
import 'dart:io';
import 'ai_contract.dart';

/// Shared HTTP boundary; feature-specific contexts and prompts stay separate.
class AiTransport {
  AiTransport({this.allowLan = aiLabEnabled, this.createHttpClient});
  final bool allowLan;
  final HttpClient Function()? createHttpClient;
  Future<Map<String, dynamic>> request(
    AiProfile profile,
    String method,
    String suffix,
    String key, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 10),
    void Function(HttpClient)? onClient,
  }) async {
    final base = validateAiUrl(profile.url, allowLan: allowLan);
    final uri = Uri.parse(
      '${base.toString().replaceFirst(RegExp(r'/$'), '')}$suffix',
    );
    final client = (createHttpClient?.call() ?? HttpClient())
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      onClient?.call(client);
      return await (() async {
        final request = await client.openUrl(method, uri);
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        if (key.isNotEmpty) request.headers.set('Authorization', 'Bearer $key');
        headers.forEach(request.headers.set);
        if (body != null) request.write(jsonEncode(body));
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 256000) {
            throw const AiFailure('Sunucu yanıtı çok büyük.');
          }
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          // Inspect only the error type; never surface remote text or headers.
          if (response.statusCode == 429) {
            String? errorType;
            try {
              final error = jsonDecode(utf8.decode(bytes));
              errorType = error['error']['type'] as String?;
            } catch (_) {}
            if (errorType == 'exceeded_current_quota_error' ||
                errorType == 'insufficient_quota') {
              throw const AiFailure(
                'AI hesabının bakiyesi veya kullanım kotası yetersiz. Test yöneticisine haber ver. Kayıtların telefonda korunuyor.',
              );
            }
          }
          throw AiFailure(switch (response.statusCode) {
            401 || 403 => 'Erişim anahtarını kontrol et.',
            429 => 'Sunucu meşgul. Biraz sonra tekrar dene.',
            404 => 'İş veya adres bulunamadı. Sunucu yeniden açılmış olabilir.',
            409 => 'İstek sürümü çakıştı.',
            503 =>
              'Fal hizmeti şu anda kullanılamıyor. Kayıtların korunuyor; test saatlerinde yeniden deneyebilirsin.',
            _ => 'AI servisi yanıt veremedi (${response.statusCode}).',
          });
        }
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      })().timeout(timeout);
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure(
        playTestEnabled
            ? 'Fal hizmetine şu anda ulaşılamıyor. Kayıtların telefonda korunuyor; test saatlerinde yeniden deneyebilirsin.'
            : 'AI bağlantısı kurulamadı veya zaman aşımına uğradı. Kayıtların telefonda korunuyor.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
