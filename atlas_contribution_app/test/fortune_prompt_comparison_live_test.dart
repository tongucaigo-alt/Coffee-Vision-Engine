import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_transport.dart';
import 'package:atlas_contribution_app/src/ai/fortune_personalization.dart';
import 'package:atlas_contribution_app/src/ai/narrative.dart';
import 'package:atlas_contribution_app/src/user_profile_store.dart';
import 'rich_fortune_test.dart' show richContext;

List<Map<String, dynamic>> comparisonCases() {
  final specs = [
    ('general-no-age', 'general', null, <String>[], false, false),
    ('general-age65-pisces', 'general', 65, ['Ağaç'], true, false),
    ('general-with-history', 'general', 45, ['Yol', 'Anahtar'], false, true),
    ('love-age25', 'love', 25, ['Kalp', 'Kuş'], false, false),
    ('work-age45', 'work', 45, ['Anahtar', 'Merdiven'], false, false),
    ('money-age65-pisces', 'money', 65, ['Balık'], true, false),
  ];
  return [
    for (final (id, focus, age, symbols, zodiac, history) in specs)
      (() {
        final base = richContext();
        base['photos'] = (base['photos'] as List).take(1).toList();
        base['photos'][0]['userObservations'] = [
          for (var i = 0; i < symbols.length; i++)
            {
              'origin': 'userObservation',
              'symbolName': symbols[i],
              'box': {'x': .15 + i * .3, 'y': .2, 'width': .15, 'height': .2},
            },
        ];
        base['photos'][0]['regionalSummary']['components'] = [
          {
            'number': 1,
            'x': .5,
            'y': .5,
            'residueShare': .5,
            'aspectRatio': 1.2,
          },
        ];
        final context = personalizeFortuneContext(
          base,
          readingIdentity: 'synthetic-prompt-comparison-$id',
          readingFocus: focus,
          profile: UserProfile(
            age: age,
            zodiac: zodiac ? ZodiacSign.pisces : null,
            useZodiacInReading: zodiac,
          ),
          pastReadingExcerpt: history
              ? 'Kısa bir yolculuk için bir görüşme gündeme gelecek. Bir ziyaret planı kararını yeniden düşünmene neden olacak.'
              : null,
        );
        return <String, dynamic>{
          'id': id,
          'context': validateAiContext(context),
        };
      })(),
  ];
}

Map<String, int> promptSize(List<Map<String, String>> messages) {
  final text = messages.map((m) => m['content']!).join('\n');
  return {
    'messages': messages.length,
    'characters': text.length,
    'words': text.split(RegExp(r'\s+')).length,
    'lines': text.split('\n').length,
  };
}

void main() {
  test(
    'paired cases are synthetic, all topics and complaints have source data',
    () {
      final cases = comparisonCases();
      expect(cases, hasLength(6));
      expect(
        cases.map((c) => c['context']['readingFocus']).toSet(),
        readingFocusValues.toSet(),
      );
      expect(cases[1]['context']['personalization'], {
        'age': 65,
        'zodiac': 'pisces',
      });
      expect(cases[2]['context']['pastReadingExcerpt'], isNotNull);
      for (final c in cases) {
        expect(validateAiContext(c['context']), c['context']);
      }
    },
  );

  test(
    'same model and input compare frozen baseline against compact candidate without repair bias',
    () async {
      const baselinePath = String.fromEnvironment('ATLAS_BASELINE_PROMPT');
      expect(baselinePath, isNotEmpty);
      final baseline = FortunePrompt(await File(baselinePath).readAsString());
      final current = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      expect(baseline.version, 'atlas-fortune-prompt-v17');
      expect(
        current.version,
        const String.fromEnvironment(
          'ATLAS_CANDIDATE_PROMPT_VERSION',
          defaultValue: 'atlas-fortune-prompt-v23',
        ),
      );
      expect(current.data['maxTokens'], baseline.data['maxTokens']);
      final transport = AiTransport();
      final records = <Map<String, dynamic>>[];
      final previous = <String, List<String>>{'baseline': [], 'candidate': []};
      DateTime? lastPost;
      final report = File(
        const String.fromEnvironment(
          'ATLAS_PROMPT_COMPARISON_REPORT',
          defaultValue: 'build/prompt-comparison-v18.json',
        ),
      );
      await report.parent.create(recursive: true);
      Future<void> save() => report.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'synthetic': true,
          'containsRealUserData': false,
          'mode': 'paired-first-response-no-repairs',
          'qualityPolicy':
              'common-current-policy; baseline physical phrasing is intentionally scored by the new policy',
          'model': bundledKimiProfile.model,
          'temperature': .6,
          'maxTokens': current.data['maxTokens'],
          'minimumPostSpacingMs': 26000,
          'cases': records,
        }),
        flush: true,
      );
      const selectedCases = String.fromEnvironment('ATLAS_COMPARISON_CASES');
      const selectedVariant = String.fromEnvironment(
        'ATLAS_COMPARISON_VARIANT',
      );
      expect(['', 'baseline', 'candidate'], contains(selectedVariant));
      final cases = comparisonCases()
          .where(
            (row) =>
                selectedCases.isEmpty ||
                selectedCases.split(',').contains(row['id']),
          )
          .toList();
      expect(cases, isNotEmpty);
      for (var index = 0; index < cases.length; index++) {
        final spec = cases[index];
        final context = spec['context'] as Map<String, dynamic>;
        final contextBefore = jsonEncode(context);
        final variants = selectedVariant.isNotEmpty
            ? [selectedVariant]
            : index.isEven
            ? ['baseline', 'candidate']
            : ['candidate', 'baseline'];
        for (final variant in variants) {
          final prompt = variant == 'baseline' ? baseline : current;
          final messages = prompt.messages(context, noThink: false);
          final record = <String, dynamic>{
            'case': spec['id'],
            'variant': variant,
            'context': context,
            'contextFingerprint': sha256
                .convert(utf8.encode(contextBefore))
                .toString(),
            'promptVersion': prompt.version,
            'promptHash': prompt.hash,
            'promptSize': promptSize(messages),
          };
          final elapsed = lastPost == null
              ? 26000
              : DateTime.now().difference(lastPost).inMilliseconds;
          final pacingWait = elapsed < 26000 ? 26000 - elapsed : 0;
          if (pacingWait > 0) {
            await Future<void>.delayed(Duration(milliseconds: pacingWait));
          }
          lastPost = DateTime.now();
          final watch = Stopwatch()..start();
          try {
            final response = await transport.request(
              bundledKimiProfile,
              'POST',
              '/chat/completions',
              bundledCredential(bundledKimiProfile),
              timeout: const Duration(seconds: 180),
              body: {
                'model': bundledKimiProfile.model,
                'messages': messages,
                'thinking': {'type': 'disabled'},
                'stream': false,
                'temperature': .6,
                'max_tokens': current.data['maxTokens'],
              },
            );
            final choice = (response['choices'] as List).first as Map;
            final text = (choice['message'] as Map)['content'] as String? ?? '';
            final quality = fortuneQualityError(
              text,
              choice['finish_reason'] as String?,
              context: context,
            );
            final repeat = narrativeRepetition(
              text,
              prompt.repetitionReferences(context, previous[variant]!),
            );
            record.addAll({
              'text': text,
              'qualityError': quality,
              'repetitionError': repeat,
              'acceptedUnderCommonPolicy': quality == null && repeat == null,
              'wordCount': text.trim().split(RegExp(r'\s+')).length,
              'paragraphs': text.trim().split(RegExp(r'\n\s*\n')).length,
              'mechanicalLanguage': mechanicalFortuneLanguage(
                text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase(),
              ),
              'qualityWarnings': fortuneQualityWarnings(text, context),
              'usage': {
                for (final k in [
                  'prompt_tokens',
                  'completion_tokens',
                  'total_tokens',
                ])
                  if ((response['usage'] as Map?)?[k] is int)
                    k: response['usage'][k],
              },
            });
            previous[variant]!.add(text);
          } on AiFailure catch (error) {
            record.addAll({
              'error': error.message,
              'diagnostics': error.diagnostics,
            });
            records.add({
              ...record,
              'modelElapsedMs': watch.elapsedMilliseconds,
              'pacingWaitMs': pacingWait,
            });
            await save();
            rethrow;
          }
          record['modelElapsedMs'] = watch.elapsedMilliseconds;
          record['pacingWaitMs'] = pacingWait;
          expect(jsonEncode(context), contextBefore);
          records.add(record);
          await save();
          // No request, header or credential is printed; all stories are synthetic.
          // ignore: avoid_print
          print(
            '${spec['id']} $variant: ${record['qualityError'] ?? record['repetitionError'] ?? 'accepted'} (${record['modelElapsedMs']} ms)',
          );
        }
      }
      expect(
        records,
        hasLength(cases.length * (selectedVariant.isEmpty ? 2 : 1)),
      );
    },
    skip:
        !const bool.fromEnvironment('ATLAS_PROMPT_COMPARISON_LIVE') ||
        !bundledKimiEnabled,
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'final compact prompt uses the production client with at most two calls',
    () async {
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final client = AiClient(prompt);
      final report = File(
        const String.fromEnvironment(
          'ATLAS_PROMPT_PRODUCTION_REPORT',
          defaultValue: 'build/compact-production-live.json',
        ),
      );
      await report.parent.create(recursive: true);
      final rows = <Map<String, dynamic>>[];
      final previous = <String>[];
      const previousPath = String.fromEnvironment(
        'ATLAS_PRODUCTION_PREVIOUS_REPORT',
      );
      if (previousPath.isNotEmpty) {
        final seed = jsonDecode(await File(previousPath).readAsString()) as Map;
        expect(seed['synthetic'], true);
        previous.addAll(
          (seed['cases'] as List).take(2).map((row) => row['text'] as String),
        );
      }

      DateTime? lastPost;
      Future<void> save() => report.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'synthetic': true,
          'containsRealUserData': false,
          'mode': 'actual-production-client-bounded-repair',
          'promptVersion': prompt.version,
          'promptHash': prompt.hash,
          'model': bundledKimiProfile.model,
          'temperature': .6,
          'minimumPostSpacingMs': 26000,
          'cases': rows,
        }),
        flush: true,
      );
      const selected = String.fromEnvironment('ATLAS_PRODUCTION_CASES');
      final cases = comparisonCases()
          .where(
            (row) =>
                selected.isEmpty || selected.split(',').contains(row['id']),
          )
          .toList();
      expect(cases, isNotEmpty);
      for (final spec in cases) {
        final context = spec['context'] as Map<String, dynamic>;
        final row = <String, dynamic>{
          'case': spec['id'],
          'context': context,
          'contextFingerprint': sha256
              .convert(utf8.encode(jsonEncode(context)))
              .toString(),
          'promptSize': promptSize(prompt.messages(context, noThink: false)),
        };
        var calls = 0, waitMs = 0;
        final watch = Stopwatch()..start();
        try {
          final answer = await client.generate(
            bundledKimiProfile,
            bundledCredential(bundledKimiProfile),
            context,
            cancellation: AiCancellation(),
            onStatus: (_) {},
            previousTexts: previous,
            beforeRequest: () async {
              final elapsed = lastPost == null
                  ? 26000
                  : DateTime.now().difference(lastPost!).inMilliseconds;
              if (elapsed < 26000) {
                waitMs += 26000 - elapsed;
                await Future<void>.delayed(
                  Duration(milliseconds: 26000 - elapsed),
                );
              }
              lastPost = DateTime.now();
              calls++;
            },
          );
          final text = answer['text'] as String;
          final quality = fortuneQualityError(text, 'stop', context: context);
          row.addAll({
            'passed':
                quality == null && calls <= 2 && calls == answer['attempts'],
            'text': text,
            'attempts': answer['attempts'],
            'qualityError': quality,
            'qualityWarnings': answer['qualityWarnings'],
            'wordCount': text.split(RegExp(r'\s+')).length,
            'mechanicalLanguage': mechanicalFortuneLanguage(
              text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase(),
            ),
          });
          previous.add(text);
        } on AiFailure catch (error) {
          row.addAll({
            'passed': false,
            'error': error.message,
            'diagnostics': error.diagnostics,
          });
          if (error.code != 'quality_rejected') {
            rows.add({
              ...row,
              'calls': calls,
              'elapsedMs': watch.elapsedMilliseconds,
              'pacingWaitMs': waitMs,
            });
            await save();
            rethrow;
          }
        }
        row.addAll({
          'calls': calls,
          'elapsedMs': watch.elapsedMilliseconds,
          'pacingWaitMs': waitMs,
        });
        rows.add(row);
        await save();
        // ignore: avoid_print
        print('${spec['id']} production: ${row['passed']} ($calls calls)');
      }
      expect(rows.where((row) => row['passed'] != true), isEmpty);
    },
    skip:
        !const bool.fromEnvironment('ATLAS_PROMPT_PRODUCTION_LIVE') ||
        !bundledKimiEnabled,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
