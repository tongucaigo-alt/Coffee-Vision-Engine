import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models.dart';
import '../user_profile_store.dart';
import '../mvp/review_models.dart' show immutableDocument;

const personalizedContextVersion = 'atlas-fortune-context-v3';
const currentFortuneContextVersion = 'atlas-fortune-context-v4';
const readingFocusValues = ['general', 'love', 'work', 'money'];
bool isPersonalizedContextVersion(Object? version) =>
    version == personalizedContextVersion ||
    version == currentFortuneContextVersion;
const creativeCatalogVersion = 'atlas-creative-symbols-v1';
const creativeSymbolIds = [
  'key',
  'bird',
  'fish',
  'tree',
  'star',
  'road',
  'heart',
];

bool hasUserSymbols(Map context) => (context['photos'] as List).any(
  (p) => (p['userObservations'] as List).isNotEmpty,
);

/// Personalization is added only at the AI boundary, never to research input.
/// An existing random reading identity makes this selection stable across
/// retries/restarts without changing labels, observations or the trace cache.
Map<String, dynamic> personalizeFortuneContext(
  Map<String, dynamic> base, {
  required String readingIdentity,
  UserProfile profile = const UserProfile(),
  Map<String, dynamic>? previousContext,
  String readingFocus = 'general',
  String? pastReadingExcerpt,
}) {
  if (!readingFocusValues.contains(readingFocus)) {
    throw const FormatException('Invalid reading focus');
  }
  if (pastReadingExcerpt != null) {
    validatePastReadingExcerpt(pastReadingExcerpt);
  }
  Map<String, dynamic>? creative;
  if (!hasUserSymbols(base)) {
    final prior = previousContext?['creativeSymbol'];
    if (prior is Map) {
      validateCreativeSymbol(prior);
      creative = Map<String, dynamic>.from(prior);
    } else {
      final digest = sha256
          .convert(utf8.encode('$creativeCatalogVersion|$readingIdentity'))
          .bytes;
      final index =
          ((digest[0] << 16) | (digest[1] << 8) | digest[2]) %
          creativeSymbolIds.length;
      final id = creativeSymbolIds[index];
      creative = {
        'catalogVersion': creativeCatalogVersion,
        'origin': 'creativeSelectionNotVisualDetection',
        'symbolId': id,
        'symbolName': contributionLabels[id]!,
      };
    }
  }
  return immutableDocument({
    ...({...base}
      ..remove('personalization')
      ..remove('pastReadingExcerpt')),
    'version': currentFortuneContextVersion,
    'readingFocus': readingFocus,
    'creativeSymbol': creative,
    if ((profile.useZodiacInReading && profile.zodiac != null) ||
        profile.age != null)
      'personalization': {
        if (profile.useZodiacInReading && profile.zodiac != null)
          'zodiac': profile.zodiac!.name,
        if (profile.age != null) 'age': profile.age,
      },
    'pastReadingExcerpt': ?pastReadingExcerpt,
  });
}

void validatePastReadingExcerpt(Object? value) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > 500 ||
      value.trim().split(RegExp(r'\s+')).length > 60 ||
      value.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length >
          2) {
    throw const FormatException('Invalid past reading excerpt');
  }
}

void validateCreativeSymbol(Map value) {
  const keys = ['catalogVersion', 'origin', 'symbolId', 'symbolName'];
  if (value.length != keys.length ||
      value.keys.any((k) => !keys.contains(k)) ||
      value['catalogVersion'] != creativeCatalogVersion ||
      value['origin'] != 'creativeSelectionNotVisualDetection' ||
      !creativeSymbolIds.contains(value['symbolId']) ||
      contributionLabels[value['symbolId']] != value['symbolName']) {
    throw const FormatException('Invalid creative symbol');
  }
}

void validatePersonalizedContext(Map<String, dynamic> value) {
  final current = value['version'] == currentFortuneContextVersion;
  if (current && !readingFocusValues.contains(value['readingFocus'])) {
    throw const FormatException('Invalid reading focus');
  }
  if (current && value.containsKey('pastReadingExcerpt')) {
    validatePastReadingExcerpt(value['pastReadingExcerpt']);
  }
  final creative = value['creativeSymbol'];
  if (hasUserSymbols(value)) {
    if (creative != null) {
      throw const FormatException('User symbols take priority');
    }
  } else {
    if (creative is! Map) {
      throw const FormatException('Missing creative symbol');
    }
    validateCreativeSymbol(creative);
  }
  if (value.containsKey('personalization')) {
    final p = value['personalization'];
    if (p is! Map ||
        p.isEmpty ||
        p.keys.any((k) => k != 'zodiac' && !(current && k == 'age')) ||
        (!current && (p.length != 1 || !p.containsKey('zodiac'))) ||
        (p.containsKey('zodiac') &&
            !ZodiacSign.values.any((z) => z.name == p['zodiac'])) ||
        (p.containsKey('age') &&
            (p['age'] is! int || p['age'] < 18 || p['age'] > 120))) {
      throw const FormatException('Invalid personalization');
    }
  }
}

/// Saved results need the stable motif, not a copy of the private profile.
/// The current preference is re-read only for a new, explicit generation.
Map<String, dynamic> storedFortuneContext(Map<String, dynamic> context) =>
    immutableDocument(
      {...context}
        ..remove('personalization')
        ..remove('pastReadingExcerpt'),
    );

String personalizedBrief(Map<String, dynamic> context) {
  if (!isPersonalizedContextVersion(context['version'])) return '';
  final symbols = <String>{
    for (final p in context['photos'] as List)
      for (final o in p['userObservations'] as List) o['symbolName'] as String,
  };
  final creative = context['creativeSymbol'] as Map?;
  final zodiac = (context['personalization'] as Map?)?['zodiac'];
  final sign = ZodiacSign.values.where((z) => z.name == zodiac).firstOrNull;
  final age = (context['personalization'] as Map?)?['age'];
  return [
    if (symbols.isNotEmpty)
      'Kullanıcının bildirdiği semboller: ${symbols.join(', ')}. Yalnız bu sembolleri kullan.'
    else
      'Yaratıcı anlatı sembolü: ${creative!['symbolName']}. Kullanıcı bunu bildirmedi; görüntüde tespit edilmedi. Yalnız çağrışımını kullan, paylaştığın deme ve fincanda konumlandırma.',
    if (sign != null)
      'Kullanıcının izin verdiği burç: ${sign.label}. En fazla bir hafif değinme; kişilik veya özel hayat çıkarımı yapma.'
    else
      'Burç bilgisi gönderilmedi. Burç veya kişilik özelliği ekleme; eksik bilgiden de söz etme.',
    if (age != null)
      'Kullanıcının izin verdiği yaş: $age. Yalnız dili ve gündelik örnekleri uyarla; evlilik, çalışma, emeklilik, yalnızlık veya kişilik varsayma. Yaşı metinde tekrarlama.',
  ].join('\n');
}
