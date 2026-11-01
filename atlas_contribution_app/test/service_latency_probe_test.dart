// Never contacts a provider unless this exact paid measurement is authorized
// and ATLAS_PERF_LIVE is explicitly enabled. No answer or credential is logged.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'fortune_prompt_comparison_live_test.dart' show comparisonCases;

void main() {
  const enabled = bool.fromEnvironment('ATLAS_PERF_LIVE');
  test('two authorized synthetic direct-provider latency samples', () async {
    final credential = Platform.environment['ATLAS_KIMI_TEST_KEY'] ?? '';
    if (credential.isEmpty) fail('Measurement credential is missing.');
    final prompt = FortunePrompt(
      await File('assets/fortune-prompt-v1.json').readAsString(),
    );
    final client = AiClient(prompt, bestEffort: false);
    final input = Map<String, dynamic>.from(
      comparisonCases().first['context'] as Map,
    );
    final samples = <Map<String, dynamic>>[];
    for (var i = 0; i < 2; i++) {
      final watch = Stopwatch()..start();
      final stages = <String, int>{};
      var code = 'completed';
      try {
        await client.generate(
          bundledKimiProfile,
          credential,
          input,
          cancellation: AiCancellation(),
          maxAttempts: 1,
          onStatus: (_) {},
          onStage: (stage, elapsed) => stages[stage] = elapsed,
        );
      } on AiFailure catch (error) {
        code = error.code;
      } catch (_) {
        code = 'local_measurement_failure';
      }
      samples.add({
        'code': code,
        'elapsedMs': watch.elapsedMilliseconds,
        'stageMs': stages,
      });
    }
    final output = File(
      'perf-live-metrics-${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
    );
    await output.writeAsString(
      jsonEncode({
        'synthetic': true,
        'model': bundledKimiProfile.model,
        'maxProviderRequests': 2,
        'attemptsPerSample': 1,
        'promptHash': prompt.hash,
        'samples': samples,
      }),
    );
  }, skip: !enabled);
}
