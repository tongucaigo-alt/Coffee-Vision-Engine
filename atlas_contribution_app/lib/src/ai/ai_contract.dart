import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models.dart';
import '../mvp/regional_summary.dart';
import 'narrative.dart';
import '../mvp/review_models.dart';

const aiLabEnabled = bool.fromEnvironment('ATLAS_AI_LAB');
const playTestEnabled = bool.fromEnvironment('ATLAS_PLAY_TEST');

enum AiProvider { atlas, direct }

class AiProfile {
  const AiProfile({
    required this.id,
    required this.name,
    required this.url,
    required this.model,
    required this.provider,
    this.noThink = true,
  });
  final String id, name, url, model;
  final AiProvider provider;
  final bool noThink;
  String get credentialKey =>
      'atlas-ai-${sha256.convert(utf8.encode('$id|$url'))}';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'model': model,
    'provider': provider.name,
    'noThink': noThink,
  };
  factory AiProfile.fromJson(Map<String, dynamic> j) => AiProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    url: j['url'] as String,
    model: j['model'] as String,
    provider: AiProvider.values.byName(j['provider'] as String),
    noThink: j['noThink'] as bool,
  );
}

Uri validateAiUrl(String value, {bool allowLan = aiLabEnabled}) {
  final u = Uri.tryParse(value);
  if (u == null ||
      !u.hasAuthority ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment ||
      u.host.isEmpty) {
    throw const FormatException('Geçerli bir sunucu adresi gir.');
  }
  if (u.scheme == 'https') return u;
  final p = u.host.split('.').map(int.tryParse).toList();
  final private =
      p.length == 4 &&
      p.every((v) => v != null && v >= 0 && v <= 255) &&
      (p[0] == 10 ||
          (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31) ||
          (p[0] == 192 && p[1] == 168));
  if (allowLan && u.scheme == 'http' && private) return u;
  throw const FormatException(
    'HTTPS kullan. Testte yerel HTTP için bilgisayarının özel ağ IP adresini gir; localhost telefonun kendisidir.',
  );
}

void _keys(Map value, List<String> keys) {
  if (value.length != keys.length || value.keys.any((k) => !keys.contains(k))) {
    throw const FormatException('AI girdisinde beklenmeyen alan.');
  }
}

/// Reject rather than silently stripping research/private fields.
Map<String, dynamic> validateAiContext(Map<String, dynamic> value) {
  final v2 = value['version'] == 'atlas-fortune-context-v2';
  _keys(value, [
    'version',
    'language',
    'status',
    'photos',
    if (value.containsKey('narrative')) 'narrative',
  ]);
  if (value.containsKey('narrative')) validateNarrative(value['narrative']);
  if ((!v2 && value['version'] != 'atlas-fortune-context-v1') ||
      value['language'] != 'tr' ||
      !['ready', 'partial'].contains(value['status'])) {
    throw const FormatException('Önce kullanılabilir analizi tamamla.');
  }
  final photos = value['photos'] as List;
  if (photos.isEmpty || photos.length > 4) {
    throw const FormatException(
      'Fal için 1–3 fincan ve en fazla bir tabak fotoğrafı seç.',
    );
  }
  var cups = 0, saucers = 0, useful = false;
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i] as Map;
    _keys(p, [
      'photoNumber',
      'surface',
      'declaredRole',
      'analysisState',
      'userObservations',
      'physicalMeasurementsStatus',
      'physicalMeasurementScope',
      'globalPhysicalMeasurements',
      if (v2) 'regionalSummary',
    ]);
    if (v2) {
      validateRegionalSummary(p['regionalSummary']);
      if (p['analysisState'] != 'complete' && p['regionalSummary'] != null) {
        throw const FormatException('Failed analysis has regional data');
      }
    }
    if (p['photoNumber'] != i + 1 ||
        !['cup', 'saucer'].contains(p['surface']) ||
        ![
          null,
          'free',
          'top',
          'handleRight',
          'handleLeft',
        ].contains(p['declaredRole']) ||
        !['complete', 'technicalError'].contains(p['analysisState']) ||
        ![
          'available',
          'invalid',
          'notAvailable',
        ].contains(p['physicalMeasurementsStatus']) ||
        p['physicalMeasurementScope'] != 'wholeImageContentNotUserRegion') {
      throw const FormatException('Geçersiz AI bağlamı.');
    }
    if (p['surface'] == 'cup') {
      cups++;
    } else {
      saucers++;
      if (p['declaredRole'] != null) {
        throw const FormatException('Tabak için açı belirtilmez.');
      }
    }
    final observations = p['userObservations'] as List;
    if (observations.length > 10) {
      throw const FormatException('Çok fazla gözlem.');
    }
    for (final raw in observations) {
      final o = raw as Map;
      _keys(o, ['origin', 'symbolName', 'box']);
      if (o['origin'] != 'userObservation' ||
          !contributionLabels.containsValue(o['symbolName'])) {
        throw const FormatException('Geçersiz kullanıcı sembolü.');
      }
      final box = Map<String, dynamic>.from(o['box'] as Map);
      _keys(box, ['x', 'y', 'width', 'height']);
      RegionBox.fromJson(box);
      useful = true;
    }
    final m = p['globalPhysicalMeasurements'];
    if (m != null) {
      _keys(m as Map, preparationMeasurementFields);
      if (p['analysisState'] != 'complete' ||
          p['physicalMeasurementsStatus'] != 'available') {
        throw const FormatException('Geçersiz fiziksel veri.');
      }
      for (final key in preparationMeasurementFields) {
        final v = m[key];
        if (v is! num ||
            !v.isFinite ||
            v < 0 ||
            (key == 'contentResidueRatio' ? v > 1 : v is! int)) {
          throw const FormatException('Geçersiz ölçüm.');
        }
      }
      if ((m['selectedRelationCount'] as num) >
          (m['candidateRelationCount'] as num)) {
        throw const FormatException('Geçersiz ilişki sayısı.');
      }
      useful =
          useful ||
          (m['residuePixelCount'] as num) > 0 ||
          (m['contentResidueRatio'] as num) > 0;
    } else if (p['physicalMeasurementsStatus'] == 'available') {
      throw const FormatException('Eksik ölçüm.');
    }
  }
  if (cups < 1 || cups > 3 || saucers > 1 || !useful) {
    throw const FormatException(
      'En az bir fincan fotoğrafı ve kullanılabilir gözlem veya ölçüm gerekiyor.',
    );
  }
  return immutableDocument(value);
}

String lengthRepairHint(String? previousReply, String? reason) {
  if (reason != 'length' || previousReply == null) return '';
  final count = previousReply.trim().split(RegExp(r'\s+')).length;
  if (count >= 250) return 'Metni 320–380 kelimeye indir; tekrarları çıkar.';
  final extra = (340 - count).clamp(80, 340);
  return 'Önceki metin yalnız $count kelime. En az $extra yeni kelimelik özgün içerik ekle; toplam 320–380 kelime hedefle. Var olan cümleleri tekrar etme. İlk üç paragrafı farklı gündelik olasılıklar ve düşünme davetleriyle geliştir; yeni kişisel olay veya görsel bulgu uydurma.';
}

class FortunePrompt {
  FortunePrompt(String raw)
    : data = Map<String, dynamic>.from(jsonDecode(raw) as Map),
      hash = sha256.convert(utf8.encode(raw)).toString();
  final Map<String, dynamic> data;
  final String hash;
  String get version => data['version'] as String;
  List<Map<String, String>> messages(
    Map<String, dynamic> context, {
    required bool noThink,
    bool repair = false,
    String? repairReason,
    String? previousReply,
  }) => [
    {'role': 'system', 'content': data['system'] as String},
    if (repair && previousReply != null)
      {'role': 'assistant', 'content': previousReply},
    {
      'role': 'user',
      'content':
          '${data['userPrefix']}${jsonEncode(context)}\nİzinli kısa fiziksel ifadeler: ${jsonEncode(physicalCues(context))}. Bu ifadeler dışında fiziksel sahne betimleme.${repair ? '\nÖnceki adayın kelime sayısı: ${previousReply?.trim().split(RegExp(r"\s+")).length ?? 0}. ${data['repair']} ${(data['repairHints'] as Map?)?[repairReason] ?? ''} ${lengthRepairHint(previousReply, repairReason)}' : ''}${noThink ? '\n/no_think' : ''}',
    },
  ];
}

String _turkishLower(String text) =>
    text.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// These bounded language checks are also covered by the gateway's shared
/// fixtures. They are not a claim of complete semantic validation.
List<String> physicalCues(Map<String, dynamic>? context) {
  final cues = <String>[];
  for (final p in context?['photos'] as List? ?? []) {
    final summary = p['regionalSummary'];
    if (summary is! Map) continue;
    final bands = {
      for (final b in summary['bands'] as List)
        b['position']: b['density'] as num,
    };
    final surface = p['surface'] == 'saucer' ? 'tabağın' : 'fincanın';
    const names = {
      'top': 'üst',
      'middle': 'orta',
      'bottom': 'alt',
      'left': 'sol',
      'center': 'merkez',
      'right': 'sağ',
    };
    for (final axis in [
      ['top', 'middle', 'bottom'],
      ['left', 'center', 'right'],
    ]) {
      if (!axis.every(bands.containsKey)) continue;
      final ordered = [...axis]..sort((a, b) => bands[a]!.compareTo(bands[b]!));
      if (bands[ordered.last]! - bands[ordered.first]! < .05) continue;
      cues.add(
        '$surface ${names[ordered.first]} bölümündeki daha açık dağılım',
      );
      cues.add('$surface ${names[ordered.last]} bölümündeki toplanma');
    }
    final components = summary['components'] as List;
    if (components.isNotEmpty) {
      final c = components.first as Map;
      final horizontal = (c['x'] as num) < 1 / 3
          ? 'sol'
          : (c['x'] as num) > 2 / 3
          ? 'sağ'
          : 'orta';
      final vertical = (c['y'] as num) < 1 / 3
          ? 'üst'
          : (c['y'] as num) > 2 / 3
          ? 'alt'
          : 'orta';
      final position = horizontal == vertical
          ? 'orta'
          : horizontal == 'orta'
          ? vertical
          : vertical == 'orta'
          ? horizontal
          : '$vertical $horizontal';
      cues.insert(0, '$surface $position bölümündeki leke');
    }
  }
  return cues.toSet().take(3).toList();
}

String? _fortuneGroundingError(String lower, Map<String, dynamic>? context) {
  if (RegExp(
    r'piksel|%\s*\d|yüzde|bileşen|ilişkisel|üç kupa|üç farklı yüzey|üç fincan|ölçüm|ölçülen|çekim aç|kamera aç|(?:sağ|sol|üst) açı|(?:üç|3) (?:farklı )?açı|residuepixelcount|contentresidueratio|componentcount|candidaterelationcount|selectedrelationcount|globalphysicalmeasurements|physicalmeasurement|photonumber|declaredrole|handleright|handleleft',
  ).hasMatch(lower)) {
    return 'technical';
  }
  // Numbered captures/views expose acquisition metadata. Keep ordinary life
  // perspectives and "ilk bakışta" outside this deliberately narrow check.
  if (RegExp(
    r'(^|[^a-zçğıöşü0-9])(?:(?:[1-4]|bir|iki|üç|dört)(?:\s+(?:ayrı|farklı))?\s+(?:çekim|fotoğraf|görüntü|görünüm)[a-zçğıöşü]*|(?:birinci|ikinci|üçüncü|dördüncü|[1-4]\.)\s+(?:çekim|fotoğraf|görüntü|görünüm|açı)[a-zçğıöşü]*|(?:[2-4]|iki|üç|dört)(?:\s+(?:ayrı|farklı))?\s+bakış(?:ta|tan|taki|ında|ından|larında|larından))($|[^a-zçğıöşü])',
  ).hasMatch(lower)) {
    return 'technical';
  }
  // Empty reporting is not evidence that a scene or the reader lacks symbols.
  if (RegExp(
    r'(?:sembol|şekil|figür)[a-zçğıöşü]*\s+(?:(?:hiç|hiçbir|bir|de)\s+)*(?:yok|bulunm|görünm|gözükm|seçilm|göremedi|göremem|görmedi|seçemedi|seçemem)|(?:sembolsüz|şekilsiz)\s+(?:fincan|fotoğraf|görüntü)|(?:fincan|fotoğraf|görüntü)[a-zçğıöşü]*\s+(?:tamamen\s+)?boş',
  ).hasMatch(lower)) {
    return 'unsupported_absence_claim';
  }
  final visualText = physicalCues(context).fold(
    lower,
    (String text, cue) => text.replaceAll(cue, 'fiziksel çağrışım'),
  );
  if (RegExp(
    r'fincanın dib|kahvenin dib|fincanın kenarında|yüzeyindeki|görüyorum|görebiliyorum|tespit edil|içindeki sıvı|(?:fotoğraf|görüntü|fincan|telve|tabak|kahve)[a-zçğıöşü]*[^.!?\n]{0,120}(?:görünü|gözük|gördü|görül|göster|seçili|seçebili|belirgin|şekil|sembol|figür|izler|dolu|yoğun|koyu|leke|çizgi|dağılım|\svar(?:\s|$)|bulun|baktığ|bakınca|incele)',
  ).hasMatch(visualText)) {
    return 'unsupported_visual_claim';
  }
  if (context != null) {
    final reported = <String>{
      for (final photo in context['photos'] as List)
        for (final observation in photo['userObservations'] as List)
          _turkishLower(observation['symbolName'] as String),
    };
    for (final name in contributionLabels.values.map(_turkishLower)) {
      if (reported.contains(name)) continue;
      final escaped = RegExp.escape(name);
      // Match explicit symbol/attribution phrases, not ordinary words such as
      // kalp, yol, ev, ay, or seeing a situation from another angle.
      if (RegExp(
        '(^|[^a-zçğıöşü])$escaped(?:[’\x27][a-zçğıöşü]+)?\\s+(?:sembol|şekl|şekil|figür|simge|işaret)|(?:paylaştığın|işaretlediğin|belirttiğin|seçtiğin|bildirdiğin|gördüğün)\\s+(?:bir\\s+)?$escaped(?=\$|[^a-zçğıöşü])',
      ).hasMatch(lower)) {
        return 'unsupported_symbol_claim';
      }
    }
    if (reported.isEmpty &&
        RegExp(
          r'(?:paylaştığın|işaretlediğin|belirttiğin|seçtiğin|bildirdiğin|gördüğün)\s+(?:bu\s+)?(?:sembol|şekil|figür)',
        ).hasMatch(lower)) {
      return 'unsupported_symbol_claim';
    }
  }
  return null;
}

String? fortuneQualityError(
  String? text,
  String? finishReason, {
  Map<String, dynamic>? context,
  bool editorial = true,
}) {
  if (finishReason != 'stop' || text == null) return 'incomplete';
  if (RegExp(
    r'<\/?think|analysis:|reasoning:|```|\b(system|assistant)\s*:',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'reasoning';
  }
  if (text.trim().isEmpty || text.length > 12000) return 'incomplete';
  if (editorial && text.trim().split(RegExp(r'\s+')).length < 150) {
    return 'length';
  }
  if (editorial && context?['version'] == 'atlas-fortune-context-v2') {
    final words = text.trim().split(RegExp(r'\s+')).length;
    if (words < 250 || words > 400) return 'length';
    if (text.trim().split(RegExp(r'\n\s*\n')).length != 4) return 'structure';
  }
  final lower = _turkishLower(text);
  if (RegExp(
    r'kesinlikle|kesin olarak|yüzde yüz|%\s*100|garanti|mutlaka|olacaksın|kazanacaksın|evleneceksin|gerçekleşecek|olacaktır|öleceksin|olacağını|şekillenecek|getirecek|açılacak|karşılaşacaksın|bulacaksın|seni bekliyor',
  ).hasMatch(lower)) {
    return 'certainty';
  }
  if (RegExp(
    r'(^|[^a-zçğıöşü])(olacak|yaşanacak|göreceksin|hissedeceksin|başlayacak|bitecek|kalacak|taşıyacak|çıkacak)($|[^a-zçğıöşü])',
  ).hasMatch(lower)) {
    return 'certainty';
  }
  final groundingError = _fortuneGroundingError(lower, context);
  if (groundingError != null) return groundingError;
  if (!RegExp(
    r'olabilir|belki|çağrıştır|düşünülebilir|ihtimal',
  ).hasMatch(lower)) {
    return 'certainty';
  }
  return null;
}

class AiFailure implements Exception {
  const AiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Beta delivery policy: editorial checks remain diagnostic, not a gate.
/// Empty, truncated and reasoning-only replies are still unusable.
bool usableFortuneText(String? text, String? finishReason) {
  if (finishReason != 'stop' || text == null) return false;
  final value = text.trim();
  if (value.split(RegExp(r'\s+')).length < 40 || value.length > 12000) {
    return false;
  }
  return !RegExp(
    r'<\/?think|analysis:|reasoning:|```|\b(system|assistant)\s*:',
    caseSensitive: false,
  ).hasMatch(value);
}
