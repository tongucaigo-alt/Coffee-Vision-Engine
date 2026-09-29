import '../fortune_progress.dart';
import 'narrative.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'ai_contract.dart';
import 'ai_bundled.dart';

class AiCancellation {
  bool cancelled = false;
  Future<void> Function()? remoteCancel;
  Future<void> cancel() async {
    cancelled = true;
    await remoteCancel?.call();
  }

  void check() {
    if (cancelled) throw const AiFailure('İşlem iptal edildi.');
  }
}

class AiClient {
  AiClient(
    this.prompt, {
    this.allowLan = aiLabEnabled,
    this.bestEffort = aiLabEnabled,
    this.createHttpClient,
  });
  final HttpClient Function()? createHttpClient;
  final FortunePrompt prompt;
  final bool allowLan;
  final bool bestEffort;
  Future<Map<String, dynamic>> probe(
    AiProfile p,
    String key,
    AiCancellation cancellation,
    void Function(String) onStatus,
  ) => generate(
    p,
    key,
    {
      'version': 'atlas-fortune-context-v1',
      'language': 'tr',
      'status': 'ready',
      'photos': [
        for (var i = 0; i < 3; i++)
          {
            'photoNumber': i + 1,
            'surface': 'cup',
            'declaredRole': ['free', 'handleRight', 'handleLeft'][i],
            'analysisState': 'complete',
            'userObservations': [],
            'physicalMeasurementsStatus': 'available',
            'physicalMeasurementScope': 'wholeImageContentNotUserRegion',
            'globalPhysicalMeasurements': {
              'residuePixelCount': 40,
              'contentResidueRatio': .2,
              'componentCount': 3,
              'candidateRelationCount': 1,
              'selectedRelationCount': 0,
            },
          },
      ],
    },
    cancellation: cancellation,
    onStatus: onStatus,
  );
  Future<Map<String, dynamic>> _request(
    AiProfile profile,
    String method,
    String suffix,
    String key, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final base = validateAiUrl(profile.url, allowLan: allowLan);
    final uri = Uri.parse(
      '${base.toString().replaceFirst(RegExp(r'/$'), '')}$suffix',
    );
    final client = (createHttpClient?.call() ?? HttpClient())
      ..connectionTimeout = const Duration(seconds: 10);
    try {
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
            _ => 'AI servisi yanıt veremedi (${response.statusCode}).',
          });
        }
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      })().timeout(timeout);
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure(
        'AI bağlantısı kurulamadı veya zaman aşımına uğradı. Kayıtların telefonda korunuyor.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<String>> models(
    AiProfile p,
    String key, {
    String? contextVersion,
  }) async {
    final data = await _request(
      p,
      'GET',
      p.provider == AiProvider.atlas ? '/api/ai/v1/capabilities' : '/models',
      key,
    );
    if (p.provider == AiProvider.atlas) {
      if (contextVersion == 'atlas-fortune-context-v2' &&
          (data['contextVersions'] is! List ||
              !(data['contextVersions'] as List).contains(contextVersion) ||
              data['clientRepetitionRepair'] != true)) {
        throw const AiFailure(
          'Sunucu yeni fal bağlamını desteklemiyor. Atlas servisini güncelle.',
        );
      }
      if (data['promptHash'] != prompt.hash ||
          data['promptVersion'] != prompt.version) {
        throw const AiFailure(
          'Uygulama ve sunucu prompt sürümleri eşleşmiyor.',
        );
      }
      if (data['available'] != true) {
        throw const AiFailure(
          'Sunucu üretimi duraklattı. Bilgisayarda LM Studio durumunu kontrol et.',
        );
      }
      return (data['models'] as List).cast<String>();
    }
    return (data['data'] as List).map((m) => m['id'] as String).toList();
  }

  Future<Map<String, dynamic>> generate(
    AiProfile p,
    String key,
    Map<String, dynamic> context, {
    required AiCancellation cancellation,
    required void Function(String) onStatus,
    String? requestId,
    List<String> previousTexts = const [],
    void Function(FortuneProgress)? onProgress,
  }) async {
    final input = validateAiContext(context);
    cancellation.check();
    if (p.provider == AiProvider.atlas) {
      await models(p, key, contextVersion: input['version'] as String);
      cancellation.check();
      final request = {
        'context': input,
        'modelAlias': p.model,
        'promptVersion': prompt.version,
      };
      final id = requestId ?? const Uuid().v4();
      final job = await _request(
        p,
        'POST',
        '/api/ai/v1/jobs',
        key,
        body: request,
        headers: {'Idempotency-Key': id},
      );
      final jobId = job['jobId'] as String;
      cancellation.remoteCancel = () async {
        try {
          await _request(p, 'DELETE', '/api/ai/v1/jobs/$jobId', key);
        } catch (_) {}
      };
      if (cancellation.cancelled) {
        await cancellation.remoteCancel!();
        cancellation.check();
      }
      final deadline = DateTime.now().add(const Duration(minutes: 34));
      var repetitionRepairRequested = false;
      while (DateTime.now().isBefore(deadline)) {
        cancellation.check();
        final status = await _request(p, 'GET', '/api/ai/v1/jobs/$jobId', key);
        cancellation.check();
        if (status['serverInstanceId'] != job['serverInstanceId']) {
          throw const AiFailure(
            'Sunucu yeniden başladı. Yeniden deneyebilirsin.',
          );
        }
        if (status['state'] == 'completed') {
          final result = Map<String, dynamic>.from(status['result'] as Map);
          if (result['promptHash'] != prompt.hash ||
              result['promptVersion'] != prompt.version ||
              fortuneQualityError(
                        result['text'] as String?,
                        'stop',
                        context: input,
                      ) !=
                      null &&
                  !(bestEffort &&
                      usableFortuneText(result['text'] as String?, 'stop'))) {
            throw const AiFailure('Yanıt kalite kontrolünden geçmedi.');
          }
          if (!bestEffort &&
              input['version'] == 'atlas-fortune-context-v2' &&
              narrativeRepetition(result['text'] as String, previousTexts) !=
                  null) {
            if (result['attempts'] != 1 || repetitionRepairRequested) {
              throw const AiFailure(
                'Hikâye önceki anlatılarla fazla benzeşti. Kayıtların korunuyor.',
              );
            }
            await _request(
              p,
              'POST',
              '/api/ai/v1/jobs/$jobId',
              key,
              body: {'reason': 'repetition'},
            );
            repetitionRepairRequested = true;
            onProgress?.call(const FortuneProgress(FortunePhase.repairing));
            continue;
          }
          return result;
        }
        if (['failed', 'cancelled'].contains(status['state'])) {
          throw const AiFailure(
            'Fal tamamlanamadı veya iptal edildi. Kayıtların korunuyor.',
          );
        }
        onProgress?.call(
          FortuneProgress(
            status['state'] == 'queued'
                ? FortunePhase.queued
                : status['phase'] == 'repairing'
                ? FortunePhase.repairing
                : FortunePhase.generating,
          ),
        );
        onStatus(
          status['state'] == 'queued'
              ? 'Sırada · ${status['queuePosition']}'
              : 'Fal hazırlanıyor…',
        );
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      await cancellation.cancel();
      throw const AiFailure('Bekleme süresi doldu.');
    }
    final kimiInstant = usesKimiInstant(p);
    final temperature = kimiInstant ? 0.6 : prompt.data['temperature'];
    final watch = Stopwatch()..start();
    String? lastError, previousReply;
    for (var attempt = 0; attempt < 2; attempt++) {
      cancellation.check();
      onProgress?.call(
        FortuneProgress(
          attempt == 0 ? FortunePhase.generating : FortunePhase.repairing,
        ),
      );
      onStatus('Fal hazırlanıyor…');
      final remaining = 180000 - watch.elapsedMilliseconds;
      if (remaining <= 0) throw const AiFailure('Üretim süresi doldu.');
      final data = await _request(
        p,
        'POST',
        '/chat/completions',
        key,
        timeout: Duration(milliseconds: remaining),
        body: {
          'model': p.model,
          'messages': prompt.messages(
            input,
            noThink: p.noThink && !kimiInstant,
            repair: attempt == 1,
            repairReason: lastError,
            previousReply: previousReply,
          ),
          'stream': false,
          if (kimiInstant) 'thinking': {'type': 'disabled'},
          'temperature': temperature,
          'max_tokens': prompt.data['maxTokens'],
        },
      );
      cancellation.check();
      final choice = (data['choices'] as List).first as Map;
      final content = (choice['message'] as Map)['content'] as String?;
      previousReply = content;
      lastError = fortuneQualityError(
        content,
        choice['finish_reason'] as String?,
        context: input,
      );
      lastError ??=
          input['version'] != 'atlas-fortune-context-v2' || content == null
          ? null
          : narrativeRepetition(content, previousTexts);
      if (lastError == null ||
          (bestEffort &&
              usableFortuneText(content, choice['finish_reason'] as String?))) {
        return {
          'text': content!.trim(),
          'qualityWarning': ?lastError,
          'model': p.model,
          'promptVersion': prompt.version,
          'promptHash': prompt.hash,
          'durationMs': watch.elapsedMilliseconds,
          'temperature': temperature,
          'maxTokens': prompt.data['maxTokens'],
          'noThink': p.noThink,
          'attempts': attempt + 1,
        };
      }
    }
    throw const AiFailure(
      'Yanıt kalite kontrolünden geçmedi. Farklı bir modelle deneyebilirsin.',
    );
  }
}
