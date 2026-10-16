import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models.dart';
import '../user_profile_store.dart';
import '../mvp/review_models.dart' show immutableDocument;

const personalizedContextVersion = 'atlas-fortune-context-v3';
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
}) {
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
    ...({...base}..remove('personalization')),
    'version': personalizedContextVersion,
    'creativeSymbol': creative,
    if (profile.useZodiacInReading && profile.zodiac != null)
      'personalization': {'zodiac': profile.zodiac!.name},
  });
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
        p.length != 1 ||
        !p.containsKey('zodiac') ||
        !ZodiacSign.values.any((z) => z.name == p['zodiac'])) {
      throw const FormatException('Invalid personalization');
    }
  }
}

/// Saved results need the stable motif, not a copy of the private profile.
/// The current preference is re-read only for a new, explicit generation.
Map<String, dynamic> storedFortuneContext(Map<String, dynamic> context) =>
    immutableDocument({...context}..remove('personalization'));

String personalizedBrief(Map<String, dynamic> context) {
  if (context['version'] != personalizedContextVersion) return '';
  final symbols = <String>{
    for (final p in context['photos'] as List)
      for (final o in p['userObservations'] as List) o['symbolName'] as String,
  };
  final creative = context['creativeSymbol'] as Map?;
  final zodiac = (context['personalization'] as Map?)?['zodiac'];
  final sign = ZodiacSign.values.where((z) => z.name == zodiac).firstOrNull;
  return [
    if (symbols.isNotEmpty)
      'Kullanıcının bildirdiği semboller: ${symbols.join(', ')}. Yalnız bu sembolleri kullan.'
    else
      'Yaratıcı anlatı sembolü: ${creative!['symbolName']}. Kullanıcı bunu bildirmedi; görüntüde tespit edilmedi. Yalnız çağrışımını kullan, paylaştığın deme ve fincanda konumlandırma.',
    if (sign != null)
      'Kullanıcının izin verdiği burç: ${sign.label}. En fazla bir hafif değinme; kişilik veya özel hayat çıkarımı yapma.'
    else
      'Burç bilgisi gönderilmedi. Burç veya kişilik özelliği ekleme; eksik bilgiden de söz etme.',
  ].join('\n');
}
