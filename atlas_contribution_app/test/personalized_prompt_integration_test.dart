import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/fortune_personalization.dart';
import 'fortune_personalization_test.dart' show personalizedQualityFixtures;

void main() {
  Future<Map<String, dynamic>> fixture() async =>
      jsonDecode(
            await File(
              '../atlas_ai_gateway/test/fixtures/source-brief-v12.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  test(
    'shared production brief preserves both surfaces, narrative and permission without raw data',
    () async {
      final row = await fixture();
      final context = validateAiContext(row['context'] as Map<String, dynamic>);
      final before = jsonEncode(context);
      expect(physicalCues(context), row['expectedCues']);
      expect(sourceAwareBrief(context), row['expectedBrief']);
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final messages = prompt.messages(context, noThink: false);
      expect(messages.map((m) => m['role']), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      expect(
        messages.last['content'],
        contains(row['expectedBrief'] as String),
      );
      for (final field in [
        'photoNumber',
        'residuePixelCount',
        'globalPhysicalMeasurements',
        'box',
        'libra',
      ]) {
        expect(messages.last['content'], isNot(contains(field)));
      }
      expect(
        prompt.repetitionReferences(context, ['PRIVATE_PRIOR_STORY']),
        contains('PRIVATE_PRIOR_STORY'),
      );
      expect(jsonEncode(messages), isNot(contains('PRIVATE_PRIOR_STORY')));
      final repaired = prompt.messages(
        context,
        noThink: false,
        repair: true,
        previousReply: 'Önceki kısa taslak.',
        repairReason: 'missing_physical_surface',
      );
      expect(repaired.map((m) => m['role']), [
        'system',
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      expect(
        repaired.last['content'],
        contains(
          prompt.data['personalizedRepairHints']['missing_physical_surface']
              as String,
        ),
      );
      expect(jsonEncode(context), before);
      final sampleSentence =
          (prompt.data['personalizedStyleExample']['assistant'] as String)
              .split(RegExp(r'[.!?\n]+'))
              .where((s) => s.trim().isNotEmpty)
              .last
              .trim();
      final copyRepair = prompt.messages(
        context,
        noThink: false,
        repair: true,
        repairReason: 'repetition',
        previousReply: sampleSentence,
      );
      expect(
        copyRepair.last['content'],
        contains('Şu cümleler üslup örneğinden kopyalanmış:'),
      );
      expect(copyRepair.last['content'], contains(sampleSentence));
      final privateRepair = prompt.messages(
        context,
        noThink: false,
        repair: true,
        repairReason: 'repetition',
        previousReply: 'Tamamen başka bir aday.',
      );
      expect(
        privateRepair.last['content'],
        isNot(contains('PRIVATE_PRIOR_STORY')),
      );
      expect(
        privateRepair.last['content'],
        isNot(contains('Şu cümleler üslup örneğinden kopyalanmış:')),
      );
      final optedOut = storedFortuneContext(context);
      expect(sourceAwareBrief(optedOut), isNot(contains('Terazi')));
      expect(sourceAwareBrief(optedOut), contains('Burç bilgisi gönderilmedi'));
    },
  );

  test(
    'surface and complete-sentence checks reject omitted saucer and nominal fragments',
    () async {
      final row = await fixture();
      final context = validateAiContext(row['context'] as Map<String, dynamic>);
      final story =
          ((await personalizedQualityFixtures())['transportStory'] as String)
              .replaceAll(
                'Fincanın üst bölümündeki daha açık dağılım',
                'Fincanın alt bölümündeki daha açık dağılım',
              );
      expect(
        fortuneQualityError(story, 'stop', context: context),
        'missing_physical_surface',
      );
      final complete =
          '$story Tabağın üst bölümündeki daha açık dağılım, bu ihtimale başka bir ferahlık katabilir.';
      expect(fortuneQualityError(complete, 'stop', context: context), null);
      expect(
        fortuneQualityError(
          '$complete Fincanın alt bölümündeki daha açık dağılım.',
          'stop',
          context: context,
        ),
        'fragmented_physical_phrase',
      );
      final legacy = {...context, 'version': 'atlas-fortune-context-v2'}
        ..remove('creativeSymbol')
        ..remove('personalization');
      expect(
        physicalCues(legacy).every((cue) => cue.startsWith('fincanın')),
        true,
      );
    },
  );
}
