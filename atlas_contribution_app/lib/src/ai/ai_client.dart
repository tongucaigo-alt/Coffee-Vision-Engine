import '../fortune_progress.dart';
import 'narrative.dart';
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'ai_contract.dart';
import 'ai_transport.dart';
import 'ai_bundled.dart';
import 'fortune_personalization.dart';

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

/// One explicit reading action shares this budget across model comparisons.
/// Gateway attempts are reserved until the server reports its final count.
class AiGenerationBudget {
  AiGenerationBudget({
    this.maxAttempts = 2,
    this.duration = const Duration(seconds: 180),
  }) {
    if (maxAttempts < 1 ||
        maxAttempts > 2 ||
        duration.inMilliseconds < 1 ||
        duration.inMilliseconds > 180000) {
      throw ArgumentError('Invalid generation budget');
    }
  }
  final int maxAttempts;
  final Duration duration;
  final Stopwatch _watch = Stopwatch()..start();
  int _attempts = 0;
  int get attempts => _attempts;
  int get remainingAttempts => maxAttempts - _attempts;
  int get remainingMilliseconds =>
      (duration.inMilliseconds - _watch.elapsedMilliseconds).clamp(0, 180000);
  void reserveAttempts(int count) {
    if (remainingMilliseconds <= 0) {
      throw const AiFailure('Üretim süresi doldu.', code: 'generation_timeout');
    }
    if (count < 1 || count > remainingAttempts) {
      throw const AiFailure(
        'Üretim deneme sınırına ulaşıldı.',
        code: 'quality_rejected',
      );
    }
    _attempts += count;
  }

  void releaseAttempts(int count) {
    if (count < 0 || count > _attempts) {
      throw StateError('Invalid attempt count');
    }
    _attempts -= count;
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
  late final _transport = AiTransport(
    allowLan: allowLan,
    createHttpClient: createHttpClient,
  );
  Future<Map<String, dynamic>> _request(
    AiProfile profile,
    String method,
    String suffix,
    String key, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
  }) => _transport.request(
    profile,
    method,
    suffix,
    key,
    body: body,
    headers: headers ?? const {},
    timeout: timeout,
  );

  Future<void> sendReport(
    AiProfile profile,
    String key,
    Map<String, dynamic> report,
  ) async {
    if (profile.provider != AiProvider.atlas) {
      throw const AiFailure('Bildirim için Atlas test bağlantısı gerekli.');
    }
    final reply = await _request(
      profile,
      'POST',
      '/api/ai/v1/reports',
      key,
      body: report,
    );
    if (reply['version'] != 1 ||
        reply['status'] != 'received' ||
        reply['reportId'] != report['id']) {
      throw const AiFailure('Bildirim henüz alınamadı.');
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
      if ([
            'atlas-fortune-context-v2',
            personalizedContextVersion,
            currentFortuneContextVersion,
          ].contains(contextVersion) &&
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
    Future<void> Function()? beforeRequest,
    AiGenerationBudget? budget,
    int maxAttempts = 2,
  }) async {
    if (maxAttempts < 1 || maxAttempts > 2) {
      throw ArgumentError('Invalid attempt limit');
    }
    final sharedBudget = budget ?? AiGenerationBudget();
    final attemptLimit = maxAttempts < sharedBudget.remainingAttempts
        ? maxAttempts
        : sharedBudget.remainingAttempts;
    if (attemptLimit == 0) {
      throw const AiFailure(
        'Üretim deneme sınırına ulaşıldı.',
        code: 'quality_rejected',
      );
    }
    final input = validateAiContext(context);
    final repetitionTexts = prompt.repetitionReferences(input, previousTexts);
    cancellation.check();
    if (p.provider == AiProvider.atlas) {
      await models(p, key, contextVersion: input['version'] as String);
      cancellation.check();
      await beforeRequest?.call();
      cancellation.check();
      sharedBudget.reserveAttempts(attemptLimit);
      final request = {
        'context': input,
        'modelAlias': p.model,
        'promptVersion': prompt.version,
        'generationLimits': {
          'maxAttempts': attemptLimit,
          'maxDurationMs': sharedBudget.remainingMilliseconds,
        },
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
      // Existing queue allowance is separate from the bounded upstream work.
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
                        editorial: !playTestEnabled,
                      ) !=
                      null &&
                  !(bestEffort &&
                      !isPersonalizedContextVersion(input['version']) &&
                      usableFortuneText(result['text'] as String?, 'stop'))) {
            throw const AiFailure('Yanıt kalite kontrolünden geçmedi.');
          }
          if ((isPersonalizedContextVersion(input['version']) ||
                  (!bestEffort && !playTestEnabled)) &&
              [
                'atlas-fortune-context-v2',
                personalizedContextVersion,
                currentFortuneContextVersion,
              ].contains(input['version']) &&
              narrativeRepetition(result['text'] as String, repetitionTexts) !=
                  null) {
            if (result['attempts'] != 1 ||
                repetitionRepairRequested ||
                attemptLimit < 2 ||
                sharedBudget.remainingMilliseconds == 0) {
              throw const AiFailure(
                'Hikâye önceki anlatılarla fazla benzeşti. Kayıtların korunuyor.',
              );
            }
            await beforeRequest?.call();
            cancellation.check();
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
          result['qualityWarnings'] = fortuneQualityWarnings(
            result['text'] as String,
            input,
          );
          result['diagnostics'] = safeAiDiagnostics(result['diagnostics']);
          final actualAttempts = result['attempts'];
          if (actualAttempts is! int ||
              actualAttempts < 1 ||
              actualAttempts > attemptLimit) {
            throw const AiFailure('Geçersiz üretim deneme bilgisi.');
          }
          sharedBudget.releaseAttempts(attemptLimit - actualAttempts);
          return result;
        }
        if (['failed', 'cancelled'].contains(status['state'])) {
          final diagnostics = safeAiDiagnostics(status['diagnostics']);
          throw AiFailure(
            'Fal tamamlanamadı veya iptal edildi. Kayıtların korunuyor.',
            code: diagnostics['code'] as String? ?? 'ai_failure',
            stage: diagnostics['stage'] as String? ?? 'generation',
            reason: diagnostics['reason'] as String?,
            attempts: diagnostics['attempts'] as int? ?? 0,
            durationMs: diagnostics['durationMs'] as int? ?? 0,
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
    for (var attempt = 0; attempt < attemptLimit; attempt++) {
      cancellation.check();
      onProgress?.call(
        FortuneProgress(
          attempt == 0 ? FortunePhase.generating : FortunePhase.repairing,
        ),
      );
      onStatus('Fal hazırlanıyor…');
      final remaining = sharedBudget.remainingMilliseconds;
      if (remaining <= 0) throw const AiFailure('Üretim süresi doldu.');
      late final Map<String, dynamic> data;
      try {
        await beforeRequest?.call();
        cancellation.check();
        sharedBudget.reserveAttempts(1);
        data = await _request(
          p,
          'POST',
          '/chat/completions',
          key,
          timeout: Duration(milliseconds: sharedBudget.remainingMilliseconds),
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
      } on AiFailure catch (error) {
        throw error.timed(
          attempt == 0 ? 'generating' : 'repairing',
          attempt + 1,
          watch.elapsedMilliseconds,
        );
      }
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
          ![
                'atlas-fortune-context-v2',
                personalizedContextVersion,
                currentFortuneContextVersion,
              ].contains(input['version']) ||
              content == null
          ? null
          : narrativeRepetition(content, repetitionTexts);
      if (lastError == null ||
          (bestEffort &&
              !isPersonalizedContextVersion(input['version']) &&
              usableFortuneText(content, choice['finish_reason'] as String?))) {
        return {
          'text': content!.trim(),
          'qualityWarning': ?lastError,
          'qualityWarnings': fortuneQualityWarnings(content, input),
          'diagnostics': {
            'code': 'completed',
            'stage': attempt == 0 ? 'generating' : 'repairing',
            'attempts': attempt + 1,
            'durationMs': watch.elapsedMilliseconds,
          },
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
    throw AiFailure(
      'Fal hazırlanamadı. Kaydın korunuyor; yeniden deneyebilirsin.',
      code: 'quality_rejected',
      stage: 'repairing',
      reason: lastError,
      attempts: attemptLimit,
      durationMs: watch.elapsedMilliseconds,
    );
  }
}
