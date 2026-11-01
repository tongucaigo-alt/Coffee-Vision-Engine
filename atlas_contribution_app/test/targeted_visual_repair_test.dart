import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';

void main() {
  late Map<String, dynamic> fixture;
  late FortunePrompt prompt;
  setUpAll(() async {
    fixture =
        jsonDecode(
              await File(
                '../atlas_ai_gateway/test/fixtures/fortune-v4-cases.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    prompt = FortunePrompt(
      await File('assets/fortune-prompt-v1.json').readAsString(),
    );
  });
  test(
    'repair identifies the offending visual claim and retains all quality gates',
    () {
      final context = validateAiContext(
        Map<String, dynamic>.from(fixture['context'] as Map),
      );
      final before = jsonEncode(context);
      const claim = 'Fincanda bir kuş görüyorum.';
      final rejected = '${fixture['story']} $claim';
      expect(
        fortuneQualityError(rejected, 'stop', context: context),
        'unsupported_visual_claim',
      );
      final hint = visualClaimRepairHint(
        rejected,
        'unsupported_visual_claim',
        context,
      );
      expect(hint, contains(jsonEncode([claim])));
      expect(hint, isNot(contains(fixture['story'] as String)));
      expect(hint, contains('uzunluk hedefini koru'));
      final repair = prompt.messages(
        context,
        noThink: false,
        repair: true,
        repairReason: 'unsupported_visual_claim',
        previousReply: rejected,
      );
      expect(repair.last['content'], contains(hint));
      expect(repair[4]['content'], rejected);
      expect(jsonEncode(context), before);
      expect(
        fortuneQualityError(
          fixture['story'] as String,
          'stop',
          context: context,
        ),
        isNull,
      );
      expect(
        fortuneQualityError(
          '${fixture['story']} Telve üzerinde bir balık görüyorum.',
          'stop',
          context: context,
        ),
        'unsupported_visual_claim',
      );
      expect(fortuneQualityError('Kısa.', 'stop', context: context), 'length');
      expect(
        fortuneQualityError(
          fixture['story'] as String,
          'length',
          context: context,
        ),
        'incomplete',
      );
      expect(prompt.data['maxTokens'], 1800);
    },
  );
  test(
    'repair context is bounded, reason-specific and never a diagnostic field',
    () {
      final context = Map<String, dynamic>.from(fixture['context'] as Map);
      final many = List.filled(20, 'Fincanda bir kuş görüyorum.').join(' ');
      final hint = visualClaimRepairHint(
        many,
        'unsupported_visual_claim',
        context,
      );
      expect(
        hint,
        contains(
          jsonEncode([
            'Fincanda bir kuş görüyorum.',
            'Fincanda bir kuş görüyorum.',
          ]),
        ),
      );
      expect(visualClaimRepairHint(many, 'length', context), isEmpty);
      expect(
        visualClaimRepairHint(null, 'unsupported_visual_claim', context),
        isEmpty,
      );
      expect(
        safeAiDiagnostics({
          'code': 'quality_rejected',
          'reason': 'unsupported_visual_claim',
          'repairText': hint,
        }),
        {'code': 'quality_rejected', 'reason': 'unsupported_visual_claim'},
      );
    },
  );
}
