import 'dart:convert';
import 'dart:math';

enum TarotSpread { three, daily }

enum TarotResultState {
  idle,
  running,
  completed,
  failed,
  cancelled,
  interrupted,
}

String localTarotDay(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

class TarotCard {
  TarotCard({
    required this.id,
    required this.name,
    required this.image,
    required List<String> upright,
    required List<String> reversed,
  }) : upright = List.unmodifiable(upright),
       reversed = List.unmodifiable(reversed);
  final String id, name, image;
  final List<String> upright, reversed;
  factory TarotCard.fromJson(Map<String, dynamic> json) => TarotCard(
    id: json['id'] as String,
    name: json['ad'] as String,
    image: json['gorsel'] as String,
    upright: List<String>.from(json['duz_temalar'] as List),
    reversed: List<String>.from(json['ters_temalar'] as List),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'ad': name,
    'gorsel': image,
    'duz_temalar': upright,
    'ters_temalar': reversed,
  };
}

List<TarotCard> loadTarotCatalog(String raw) {
  final cards = (jsonDecode(raw) as List)
      .map((j) => TarotCard.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
  if (cards.length != 78 ||
      cards.map((c) => c.id).toSet().length != 78 ||
      cards.any(
        (c) =>
            c.id.isEmpty ||
            c.name.isEmpty ||
            !RegExp(r'^[A-Z0-9_]+\.webp$').hasMatch(c.image) ||
            c.upright.isEmpty ||
            c.reversed.isEmpty ||
            [...c.upright, ...c.reversed].any((t) => t.trim().isEmpty),
      )) {
    throw const FormatException('Tarot kart kütüphanesi doğrulanamadı.');
  }
  return List.unmodifiable(cards);
}

class TarotDeckCard {
  const TarotDeckCard(this.card, this.reversed);
  final TarotCard card;
  final bool reversed;
  Map<String, dynamic> toJson() => {
    'card': card.toJson(),
    'reversed': reversed,
  };
  factory TarotDeckCard.fromJson(Map<String, dynamic> j) => TarotDeckCard(
    TarotCard.fromJson(Map<String, dynamic>.from(j['card'] as Map)),
    j['reversed'] as bool,
  );
}

List<TarotDeckCard> shuffleTarot(List<TarotCard> cards, {Random? random}) {
  final rng = random ?? Random.secure();
  final deck = cards.map((c) => TarotDeckCard(c, rng.nextBool())).toList();
  for (var i = deck.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final current = deck[i];
    deck[i] = deck[j];
    deck[j] = current;
  }
  return List.unmodifiable(deck);
}

class TarotResult {
  const TarotResult({
    this.state = TarotResultState.idle,
    this.text,
    this.attemptId,
    this.promptVersion,
    this.promptHash,
    this.error,
  });
  final TarotResultState state;
  final String? text, attemptId, promptVersion, promptHash, error;
  Map<String, dynamic> toJson() => {
    'state': state.name,
    'text': text,
    'attemptId': attemptId,
    'promptVersion': promptVersion,
    'promptHash': promptHash,
    'error': error,
  };
  factory TarotResult.fromJson(Map<String, dynamic> j) => TarotResult(
    state: TarotResultState.values.byName(j['state'] as String),
    text: j['text'] as String?,
    attemptId: j['attemptId'] as String?,
    promptVersion: j['promptVersion'] as String?,
    promptHash: j['promptHash'] as String?,
    error: j['error'] as String?,
  );
}

class TarotDraw {
  TarotDraw({
    required this.id,
    required this.spread,
    required this.createdAt,
    required List<TarotDeckCard> deck,
    List<int> selected = const [],
    this.revealed = 0,
    this.day,
    this.starred = false,
    this.result = const TarotResult(),
  }) : deck = List.unmodifiable(deck),
       selected = List.unmodifiable(selected) {
    if (deck.length != 78 ||
        deck.map((c) => c.card.id).toSet().length != 78 ||
        selected.length > requiredCards ||
        selected.toSet().length != selected.length ||
        selected.any((i) => i < 0 || i >= deck.length) ||
        revealed < 0 ||
        revealed > selected.length ||
        (revealed > 0 && selected.length != requiredCards) ||
        (spread == TarotSpread.daily && selected.isNotEmpty && day == null) ||
        (result.state == TarotResultState.completed &&
            (result.text?.trim().isEmpty != false ||
                revealed != requiredCards))) {
      throw const FormatException('Tarot açılımı geçersiz.');
    }
  }
  final String id, createdAt;
  final TarotSpread spread;
  final List<TarotDeckCard> deck;
  final List<int> selected;
  final int revealed;
  final String? day;
  final bool starred;
  final TarotResult result;
  int get requiredCards => spread == TarotSpread.three ? 3 : 1;
  bool get ready => revealed == requiredCards;
  String get title => spread == TarotSpread.three ? 'Üç Kart' : 'Günün Kartı';
  List<String> get positions => spread == TarotSpread.three
      ? const ['Geçmiş', 'Şimdi', 'Olası Yön']
      : const ['Günlük Odak'];
  List<TarotDeckCard> get chosen => selected.map((i) => deck[i]).toList();
  TarotDraw copy({
    List<TarotDeckCard>? deck,
    List<int>? selected,
    int? revealed,
    String? day,
    bool? starred,
    TarotResult? result,
  }) => TarotDraw(
    id: id,
    spread: spread,
    createdAt: createdAt,
    deck: deck ?? this.deck,
    selected: selected ?? this.selected,
    revealed: revealed ?? this.revealed,
    day: day ?? this.day,
    starred: starred ?? this.starred,
    result: result ?? this.result,
  );
  Map<String, dynamic> context() {
    if (!ready) throw StateError('Önce kartlarını aç.');
    return {
      'version': 'atlas-tarot-context-v1',
      'language': 'tr',
      'spread': spread.name,
      'cards': [
        for (var i = 0; i < chosen.length; i++)
          {
            'id': chosen[i].card.id,
            'name': chosen[i].card.name,
            'position': positions[i],
            'orientation': chosen[i].reversed ? 'reversed' : 'upright',
            'themes': chosen[i].reversed
                ? chosen[i].card.reversed
                : chosen[i].card.upright,
          },
      ],
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'spread': spread.name,
    'createdAt': createdAt,
    'deck': deck.map((c) => c.toJson()).toList(),
    'selected': selected,
    'revealed': revealed,
    'day': day,
    'starred': starred,
    'result': result.toJson(),
  };
  factory TarotDraw.fromJson(Map<String, dynamic> j) => TarotDraw(
    id: j['id'] as String,
    spread: TarotSpread.values.byName(j['spread'] as String),
    createdAt: j['createdAt'] as String,
    deck: (j['deck'] as List)
        .map((c) => TarotDeckCard.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
    selected: List<int>.from(j['selected'] as List),
    revealed: j['revealed'] as int,
    day: j['day'] as String?,
    starred: j['starred'] as bool,
    result: TarotResult.fromJson(Map<String, dynamic>.from(j['result'] as Map)),
  );
}
