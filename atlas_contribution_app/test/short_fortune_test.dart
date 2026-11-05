import 'dart:convert';
import 'dart:io';

import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/fortune_personalization.dart';
import 'package:atlas_contribution_app/src/user_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rich_fortune_test.dart' show richContext;

void main() {
  const married = UserProfile(
    addressName: 'Deniz',
    age: 37,
    maritalStatus: MaritalStatus.married,
  );
  Map<String, dynamic> context({
    UserProfile profile = married,
    bool short = true,
  }) {
    final base = richContext();
    base['photos'][0]['userObservations'] = [
      {
        'origin': 'userObservation',
        'symbolName': 'Kuş',
        'box': {'x': .15, 'y': .2, 'width': .15, 'height': .2},
      },
    ];
    return validateAiContext(
      personalizeFortuneContext(
        base,
        readingIdentity: 'synthetic-short-fortune',
        profile: profile,
        readingFocus: 'love',
        shortFortune: short,
      ),
    );
  }

  test(
    'short brief keeps both sources, excludes density and strips profile on save',
    () {
      final prompt = FortunePrompt(
        File('assets/fortune-prompt-short.json').readAsStringSync(),
      );
      final input = context();
      final messages = prompt.messages(input, noThink: false);
      expect(messages, hasLength(2));
      final brief =
          jsonDecode(messages.last['content']!.split('\n').last) as Map;
      expect(brief['isim'], 'Deniz');
      expect(brief['medeni_durum'], 'evli');
      expect(brief['kullanıcının_seçtiği_semboller'], ['Kuş']);
      expect(brief['rastgele_sembol'], isNot(anyOf(isNull, 'Kuş')));
      expect(
        brief.keys,
        unorderedEquals([
          'isim',
          'yaş',
          'medeni_durum',
          'kullanıcının_seçtiği_semboller',
          'rastgele_sembol',
        ]),
      );
      expect(storedFortuneContext(input), isNot(contains('personalization')));
      expect(context()['creativeSymbol'], input['creativeSymbol']);
    },
  );

  test('short acceptance permits optional symbols and a known spouse only', () {
    final input = context();
    final words = List.filled(74, 'gündelik').join(' ');
    expect(fortuneQualityError(words, 'stop', context: input), 'length');
    expect(
      fortuneQualityError('$words Eşinle.', 'stop', context: input),
      isNull,
    );
    expect(
      fortuneQualityError(
        '$words Eşinle.',
        'stop',
        context: context(profile: const UserProfile()),
      ),
      'unsupported_personalization',
    );
    expect(
      fortuneQualityError(
        '$words Fincanında beliren kuş.',
        'stop',
        context: input,
      ),
      'unsupported_visual_claim',
    );
    expect(
      fortuneQualityError(
        '$words Eşinle.',
        'stop',
        context: context(short: false),
      ),
      'length',
    );
  });
}
