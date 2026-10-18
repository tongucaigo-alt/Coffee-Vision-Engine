import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const memoryOpening = 'Eski fallarından birinde';

String _fold(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

String memoryPartHash(String text) => sha256
    .convert(utf8.encode(_fold(text).replaceAll(RegExp(r'\s+'), ' ').trim()))
    .toString();

/// These rules deliberately prefer no bridge to an ambiguous match. They do
/// not infer that the old story happened or inspect a photograph.
const _themeWords = <String, List<String>>{
  'communication': ['mesaj', 'konusma', 'telefon', 'haber', 'iletisim'],
  'return': ['gecmis', 'yarim kal', 'yeniden gorus', 'eski bir'],
  'meeting': ['bulus', 'gorusme', 'toplanti', 'davet', 'randevu'],
  'opportunity': ['teklif', 'firsat', 'yeni gorev', 'basvuru'],
  'payment': ['odeme', 'alacagin para', 'tahsilat', 'borc', 'bekleyen para'],
  'expense': ['masraf', 'harcama', 'alisveris'],
  'travel': ['seyahat', 'ziyaret', 'yolculuk', 'kisa bir yol'],
  'choice': ['karar', 'secim', 'iki secenek', 'secenek aras'],
};

const _symbolThemes = <String, Set<String>>{
  'bird': {'communication'},
  'heart': {'communication', 'return', 'meeting'},
  'fish': {'payment', 'opportunity'},
  'key': {'opportunity', 'choice'},
  'road': {'travel', 'choice'},
  'star': {'opportunity'},
  'tree': {'meeting'},
  'ring': {'meeting', 'choice'},
  'house': {'meeting', 'travel'},
  'humanFigure': {'communication', 'meeting'},
  'airplane': {'travel'},
  'boat': {'travel'},
  'bridge': {'communication', 'return'},
  'ladder': {'opportunity'},
  'horse': {'communication', 'travel'},
  'flower': {'meeting'},
};

const _symbolNames = <String, String>{
  'kus': 'bird',
  'kalp': 'heart',
  'balik': 'fish',
  'anahtar': 'key',
  'yol': 'road',
  'yildiz': 'star',
  'agac': 'tree',
  'yuzuk': 'ring',
  'ev': 'house',
  'insan figuru': 'humanFigure',
  'ucak': 'airplane',
  'tekne': 'boat',
  'kopru': 'bridge',
  'merdiven': 'ladder',
  'at': 'horse',
  'cicek': 'flower',
};

bool _hasPhrase(String text, String phrase) =>
    RegExp('(^|[^a-z])${RegExp.escape(phrase)}').hasMatch(text);

Set<String> _themes(String text) {
  final folded = _fold(text);
  return {
    for (final entry in _themeWords.entries)
      if (entry.value.any((word) => _hasPhrase(folded, word))) entry.key,
  };
}

Set<String> _currentThemes(Map<String, dynamic> context) {
  final ids = <String>{};
  final creative = context['creativeSymbol'];
  if (creative is Map && creative['symbolId'] is String) {
    ids.add(creative['symbolId'] as String);
  }
  for (final photo in context['photos'] as List? ?? const []) {
    for (final observation in photo['userObservations'] as List? ?? const []) {
      final id =
          _symbolNames[_fold(observation['symbolName'] as String? ?? '')];
      if (id != null) ids.add(id);
    }
  }
  return {for (final id in ids) ...?_symbolThemes[id]};
}

bool _topicFits(String text, String focus, Map result) {
  if (focus == 'general') return true;
  final oldFocus = (result['context'] as Map?)?['readingFocus'];
  if (oldFocus != null && oldFocus != 'general' && oldFocus != focus) {
    return false;
  }
  final t = _fold(text);
  const words = {
    'love': ['iliski', 'duygusal', 'sevdig', 'eski sevgili', 'gonul'],
    'work': [
      'is hayati',
      'is yer',
      'is gorus',
      'kariyer',
      'gorev',
      'proje',
      'yonetici',
      'meslek',
      'calisma',
    ],
    'money': [
      'para',
      'odeme',
      'kazanc',
      'maddi',
      'masraf',
      'harcama',
      'borc',
      'tahsilat',
    ],
  };
  final topics = {
    for (final entry in words.entries)
      if (entry.value.any((word) => _hasPhrase(t, word))) entry.key,
    if (RegExp(r'\bask(?:in(?:in|da|dan)?|a|ta|i|tan|iniz|la)?\b').hasMatch(t))
      'love',
  };
  // An old love-focused story can contain a money aside. The selected part
  // must itself fit; the result's overall topic is not sufficient evidence.
  return topics.length == 1 && topics.contains(focus);
}

bool _usable(String text) {
  if (text.length > 500 || text.split(RegExp(r'\s+')).length > 60) return false;
  if (text.split(RegExp(r'\s+')).length < 8) return false;
  final t = _fold(text);
  // Discard dated/letter-based claims rather than moving their deadline or
  // identity into a new fortune. Skip negation instead of guessing its scope.
  return !RegExp(
    r'\d|\b(?:vakit\w*|vakt\w*|zaman[ai]?|gun(?:e|u|un|de|den|ler\w*)?|hafta(?:ya|da|dan|nin|lar\w*)?|ay(?:a|i|in|da|dan|lar\w*|lik)?|yil(?:a|i|in|da|dan|lar\w*|lik)?|harf\w*|ismin(?:de|in)?|isim(?:de|ler\w*)?|kesin\w*|garanti\w*|olum\w*|hastalik\w*|teshis\w*|yatirim\w*)\b|'
    r'eski fallar|yildizladigin|onceki fal|degil|yok\b|olmay|gelmey|donmey|bitmis|kapanmis|artık|artik|istemiyor|talimat|prompt|sistem mesaji',
  ).hasMatch(t);
}

class FortuneMemoryCandidate {
  const FortuneMemoryCandidate({
    required this.sourceId,
    required this.partHash,
    required this.excerpt,
    required this.score,
    required this.createdAt,
  });
  final String sourceId, partHash, excerpt, createdAt;
  final int score;
  Map<String, String> get receipt => {
    'sourceId': sourceId,
    'partHash': partHash,
  };
}

/// Metadata stays in the private AI store. No old text is duplicated here.
class FortuneMemoryEngine {
  FortuneMemoryEngine({Random? random}) : _random = random ?? Random.secure();
  final Random _random;
  int _interval() => 2 + _random.nextInt(4);

  Map<String, dynamic> _state(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(
        data.putIfAbsent(
              'fortuneMemoryV1',
              () => {
                'completedKeys': <String>[],
                'nextAt': _interval(),
                'usedParts': <Map<String, dynamic>>[],
                'pending': <String, dynamic>{},
              },
            )
            as Map,
      );

  List<FortuneMemoryCandidate> _candidates(
    Map<String, dynamic> data,
    String readingKey,
    String focus,
    Map<String, dynamic> context,
    Map<String, dynamic> state,
  ) {
    final stars = Set<String>.from(data['starredResultIds'] as List? ?? []);
    final current = _currentThemes(context);
    if (current.isEmpty) return [];
    final used = state['usedParts'] as List;
    final nextIndex = (state['completedKeys'] as List).length + 1;
    final result = <FortuneMemoryCandidate>[];
    for (final row in data['results'] as List? ?? const []) {
      if (row['state'] != 'completed' || !stars.contains(row['id'])) continue;
      if ('${row['sessionId']}|${row['sourceFingerprint']}' == readingKey) {
        continue;
      }
      if (used.any(
        (u) => u['sourceId'] == row['id'] && nextIndex - (u['at'] as int) < 10,
      )) {
        continue;
      }
      for (final answer in row['answers'] as List? ?? const []) {
        final text = answer['text'] as String? ?? '';
        final sentences = RegExp(r'[^.!?\n]+[.!?]?')
            .allMatches(text)
            .map((m) => m.group(0)!.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (var i = 0; i < sentences.length; i++) {
          for (
            var length = 1;
            length <= 2 && i + length <= sentences.length;
            length++
          ) {
            final excerpt = sentences.sublist(i, i + length).join(' ');
            if (!_usable(excerpt) || !_topicFits(excerpt, focus, row)) continue;
            final shared = _themes(excerpt).intersection(current);
            if (shared.isEmpty) continue;
            final hash = memoryPartHash(excerpt);
            // Also reject reuse through a differently-sized neighbouring window.
            final sentenceHashes = sentences
                .sublist(i, i + length)
                .map(memoryPartHash)
                .toSet();
            if (used.any(
              (u) =>
                  (u['partHash'] == hash ||
                  (u['sentenceHashes'] as List? ?? []).any(
                    sentenceHashes.contains,
                  )),
            )) {
              continue;
            }
            result.add(
              FortuneMemoryCandidate(
                sourceId: row['id'] as String,
                partHash: hash,
                excerpt: excerpt,
                score: shared.length,
                createdAt: row['createdAtUtc'] as String? ?? '',
              ),
            );
          }
        }
      }
    }
    result.sort((a, b) {
      var order = b.score.compareTo(a.score);
      if (order == 0) order = b.createdAt.compareTo(a.createdAt);
      if (order == 0) order = a.excerpt.length.compareTo(b.excerpt.length);
      if (order == 0) order = a.partHash.compareTo(b.partHash);
      return order;
    });
    return result;
  }

  FortuneMemoryCandidate? prepare(
    Map<String, dynamic> data, {
    required String readingKey,
    required String focus,
    required Map<String, dynamic> context,
  }) {
    final state = _state(data);
    data['fortuneMemoryV1'] = state;
    if ((state['completedKeys'] as List).contains(readingKey) ||
        (state['completedKeys'] as List).length + 1 < (state['nextAt'] as int)) {
      return null;
    }
    final candidates = _candidates(data, readingKey, focus, context, state);
    final pending = Map<String, dynamic>.from(state['pending'] as Map);
    final previous = pending[readingKey] as Map?;
    final same = previous == null
        ? null
        : candidates
              .where(
                (c) =>
                    c.sourceId == previous['sourceId'] &&
                    c.partHash == previous['partHash'],
              )
              .firstOrNull;
    final candidate = same ?? candidates.firstOrNull;
    if (candidate == null) {
      pending.remove(readingKey);
    } else {
      pending[readingKey] = candidate.receipt;
    }
    state['pending'] = pending;
    return candidate;
  }

  bool isCurrent(
    Map<String, dynamic> data,
    String readingKey,
    FortuneMemoryCandidate candidate,
  ) {
    final state = _state(data);
    final receipt = (state['pending'] as Map)[readingKey] as Map?;
    if (receipt?['sourceId'] != candidate.sourceId ||
        receipt?['partHash'] != candidate.partHash) {
      return false;
    }
    final stars = data['starredResultIds'] as List? ?? [];
    return stars.contains(candidate.sourceId) &&
        (data['results'] as List).any(
          (r) => r['id'] == candidate.sourceId && r['state'] == 'completed',
        );
  }

  /// Called in the same serialized write as saving the completed result.
  void complete(
    Map<String, dynamic> data,
    Map<String, dynamic> result, {
    FortuneMemoryCandidate? candidate,
  }) {
    if (result['state'] != 'completed' ||
        (result['context'] as Map?)?['version'] != 'atlas-fortune-context-v4') {
      return;
    }
    final key = '${result['sessionId']}|${result['sourceFingerprint']}';
    final state = _state(data);
    data['fortuneMemoryV1'] = state;
    final keys = List<String>.from(state['completedKeys'] as List);
    if (keys.contains(key)) return;
    keys.add(key);
    state['completedKeys'] = keys;
    final actual = (result['answers'] as List? ?? []).any(
      (a) => _fold(a['text'] as String? ?? '').contains(_fold(memoryOpening)),
    );
    if (candidate != null && actual && isCurrent(data, key, candidate)) {
      (state['usedParts'] as List).add({
        ...candidate.receipt,
        'sentenceHashes': RegExp(r'[^.!?\n]+[.!?]?')
            .allMatches(candidate.excerpt)
            .map((m) => memoryPartHash(m.group(0)!.trim()))
            .toList(),
        'at': keys.length,
      });
      state['nextAt'] = keys.length + _interval();
      result['memorySource'] = candidate.receipt;
    }
    (state['pending'] as Map).remove(key);
  }
}
