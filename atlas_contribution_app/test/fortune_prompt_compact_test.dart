import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';

void main() {
  test(
    'compact v4 brief matches shared source facts without editing the context',
    () async {
      final rows =
          jsonDecode(
                await File(
                  '../atlas_ai_gateway/test/fixtures/compact-brief-v18.json',
                ).readAsString(),
              )
              as List;
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      expect(
        (prompt.data['currentSystem'] as String).split(RegExp(r'\s+')).length,
        lessThan(200),
      );
      expect(
        (prompt.data['currentStyleExample']['assistant'] as String)
            .split(RegExp(r'\s+'))
            .length,
        lessThan(110),
      );
      for (final row in rows) {
        final context = validateAiContext(
          Map<String, dynamic>.from(row['context'] as Map),
        );
        final original = jsonEncode(context);
        final brief = sourceAwareBrief(context);
        expect(jsonDecode(brief), row['brief'], reason: row['id'] as String);
        expect(brief, isNot(contains('leke')));
        expect(brief, isNot(contains('Akış:')));
        expect(brief, isNot(contains('aynen kullan')));
        expect(jsonEncode(context), original);
        final messages = prompt.messages(context, noThink: false);
        expect(messages, hasLength(4));
        expect(messages.last['content'], endsWith(brief));
        final repair = prompt.messages(
          context,
          noThink: false,
          repair: true,
          repairReason: 'mechanical_language',
          previousReply: 'Eski ve mekanik aday.',
        );
        expect(repair, hasLength(6));
        expect(
          repair.last['content'],
          contains(prompt.data['currentRepairHints']['mechanical_language']),
        );
        expect(repair.last['content'], isNot(contains('Her mevcut yüzeyden')));
      }
    },
  );

  test('compact diagnostics retain only the bounded mechanical reason', () {
    expect(
      safeAiDiagnostics({
        'code': 'quality_rejected',
        'reason': 'mechanical_language',
        'text': 'PRIVATE_STORY',
        'profile': 'PRIVATE_PROFILE',
      }),
      {'code': 'quality_rejected', 'reason': 'mechanical_language'},
    );
  });

  test(
    'memory copy failure omits the optional reference on repair without changing input',
    () async {
      final rows =
          jsonDecode(
                await File(
                  '../atlas_ai_gateway/test/fixtures/compact-brief-v18.json',
                ).readAsString(),
              )
              as List;
      final context = Map<String, dynamic>.from(rows[1]['context'] as Map);
      final before = jsonEncode(context);
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      for (final reason in ['repetition', 'unsupported_memory']) {
        final turns = prompt.messages(
          context,
          noThink: false,
          repair: true,
          repairReason: reason,
          previousReply: 'Eski aday.',
        );
        Map payload(int i) =>
            jsonDecode(
                  (turns[i]['content'] as String)
                      .substring(
                        (prompt.data['currentUserPrefix'] as String).length,
                      )
                      .split('\n')
                      .first,
                )
                as Map;
        expect(payload(3)['memory_reference_allowed'], true);
        expect(payload(5)['memory_reference_allowed'], false);
        expect(payload(5)['past_excerpt'], isNull);
        expect(jsonEncode(context), before);
      }
    },
  );

  test(
    'generation revision preserves source brief, style and output limits',
    () async {
      const oldPath = String.fromEnvironment('ATLAS_PREVIOUS_PROMPT');
      final old = FortunePrompt(await File(oldPath).readAsString());
      final current = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final rows =
          jsonDecode(
                await File(
                  '../atlas_ai_gateway/test/fixtures/compact-brief-v18.json',
                ).readAsString(),
              )
              as List;
      for (final row in rows) {
        final context = Map<String, dynamic>.from(row['context'] as Map);
        expect(
          current.messages(context, noThink: false).skip(1).toList(),
          old.messages(context, noThink: false).skip(1).toList(),
        );
        expect(current.data['maxTokens'], old.data['maxTokens']);
        expect(current.data['temperature'], old.data['temperature']);
        expect(
          current.data['currentSystem'],
          contains('250–400 Turkish words'),
        );
        expect(current.data['currentSystem'], contains('finish at least 150'));
      }
    },
    skip: const String.fromEnvironment('ATLAS_PREVIOUS_PROMPT').isEmpty,
  );
}
