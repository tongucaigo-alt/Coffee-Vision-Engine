import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'tarot_models.dart';

/// Independent local storage. Never participates in coffee research exports.
class TarotStore {
  TarotStore(this.directory, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Directory directory;
  final DateTime Function() now;
  Future<void> _tail = Future.value();
  Future<Map<String, dynamic>> _read() async {
    final file = File('${directory.path}/state.json');
    if (!await file.exists()) {
      return {'version': 1, 'draws': [], 'deletedDailyDays': []};
    }
    final data = Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    if (data['version'] != 1 ||
        data['draws'] is! List ||
        data['deletedDailyDays'] is! List) {
      throw const FormatException(
        'Tarot kayıtları okunamadı. Kayıtlar silinmedi.',
      );
    }
    _draws(data); // Fail closed; never reset a malformed file.
    return data;
  }

  List<TarotDraw> _draws(Map<String, dynamic> data) => (data['draws'] as List)
      .map((j) => TarotDraw.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
  Future<T> _change<T>(T Function(Map<String, dynamic>) action) {
    final next = _tail.then((_) async {
      final data = await _read();
      final value = action(data);
      await directory.create(recursive: true);
      final pending = File('${directory.path}/state.pending');
      await pending.writeAsString(jsonEncode(data), flush: true);
      await pending.rename('${directory.path}/state.json');
      return value;
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _put(Map<String, dynamic> data, TarotDraw draw) {
    final list = data['draws'] as List;
    list.removeWhere((j) => j['id'] == draw.id);
    list.add(draw.toJson());
  }

  TarotDraw _find(Map<String, dynamic> data, String id) =>
      _draws(data).firstWhere(
        (d) => d.id == id,
        orElse: () => throw StateError('Açılım bulunamadı.'),
      );
  Future<List<TarotDraw>> draws() async {
    await _tail;
    return _draws(await _read())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<TarotDraw?> get(String id) async =>
      (await draws()).where((d) => d.id == id).firstOrNull;
  Future<void> initialize() => _change((data) {
    for (final draw in _draws(data)) {
      if (draw.result.state == TarotResultState.running) {
        _put(
          data,
          draw.copy(
            result: TarotResult(
              state: TarotResultState.interrupted,
              promptVersion: draw.result.promptVersion,
              promptHash: draw.result.promptHash,
              error:
                  'Önceki yorum işlemi tamamlanmadı. Aynı kartlarla yeniden deneyebilirsin.',
            ),
          ),
        );
      }
    }
  });
  Future<TarotDraw> start(TarotSpread spread, List<TarotCard> catalog) =>
      _change((data) {
        final existing = _draws(data);
        if (spread == TarotSpread.daily) {
          final day = localTarotDay(now());
          if ((data['deletedDailyDays'] as List).contains(day)) {
            throw StateError(
              'Bugünün kartını sildin. Yarın yeni bir kart seçebilirsin.',
            );
          }
          final daily = existing
              .where((d) => d.spread == spread && d.day == day)
              .firstOrNull;
          if (daily != null) return daily;
          final pending = existing
              .where((d) => d.spread == spread && d.selected.isEmpty)
              .firstOrNull;
          if (pending != null) return pending;
        }
        final draw = TarotDraw(
          id: const Uuid().v4(),
          spread: spread,
          createdAt: now().toUtc().toIso8601String(),
          deck: shuffleTarot(catalog),
        );
        _put(data, draw);
        return draw;
      });
  Future<TarotDraw> reshuffle(String id, List<TarotCard> catalog) =>
      _change((data) {
        final draw = _find(data, id);
        if (draw.selected.isNotEmpty) {
          throw StateError('Seçimden sonra deste değişmez.');
        }
        final next = draw.copy(deck: shuffleTarot(catalog));
        _put(data, next);
        return next;
      });
  Future<TarotDraw> select(String id, int index) => _change((data) {
    final draw = _find(data, id);
    if (index < 0 ||
        index >= draw.deck.length ||
        draw.selected.contains(index) ||
        draw.selected.length >= draw.requiredCards) {
      throw StateError('Bu kart seçilemez.');
    }
    String? day;
    if (draw.spread == TarotSpread.daily) {
      day = localTarotDay(now());
      if ((data['deletedDailyDays'] as List).contains(day) ||
          _draws(data).any(
            (d) => d.id != id && d.spread == TarotSpread.daily && d.day == day,
          )) {
        throw StateError(
          'Bugünün kartı zaten seçildi. Tarot ekranından yeniden aç.',
        );
      }
    }
    final next = draw.copy(selected: [...draw.selected, index], day: day);
    _put(data, next);
    return next;
  });
  Future<TarotDraw> reveal(String id, int position) => _change((data) {
    final draw = _find(data, id);
    if (draw.selected.length != draw.requiredCards ||
        position != draw.revealed ||
        position >= draw.requiredCards) {
      throw StateError('Kartlarını sırayla aç.');
    }
    final next = draw.copy(revealed: draw.revealed + 1);
    _put(data, next);
    return next;
  });
  Future<TarotDraw> begin(
    String id,
    String attemptId,
    String version,
    String hash,
  ) => _change((data) {
    final draw = _find(data, id);
    if (!draw.ready ||
        [
          TarotResultState.running,
          TarotResultState.completed,
        ].contains(draw.result.state)) {
      throw StateError('Bu açılım için yeni yorum başlatılamaz.');
    }
    final next = draw.copy(
      result: TarotResult(
        state: TarotResultState.running,
        attemptId: attemptId,
        promptVersion: version,
        promptHash: hash,
      ),
    );
    _put(data, next);
    return next;
  });
  Future<void> finish(
    String id,
    String attemptId,
    TarotResultState state, {
    String? text,
    String? error,
  }) => _change((data) {
    final draw = _draws(data).where((d) => d.id == id).firstOrNull;
    if (draw == null ||
        draw.result.attemptId != attemptId ||
        draw.result.state != TarotResultState.running) {
      return;
    }
    _put(
      data,
      draw.copy(
        result: TarotResult(
          state: state,
          text: text,
          error: error,
          attemptId: attemptId,
          promptVersion: draw.result.promptVersion,
          promptHash: draw.result.promptHash,
        ),
      ),
    );
  });
  Future<void> star(String id, bool value) => _change((data) {
    final draw = _find(data, id);
    if (draw.result.state != TarotResultState.completed) {
      throw StateError('Önce yorumunu oluştur.');
    }
    if (value &&
        !draw.starred &&
        _draws(data).where((d) => d.starred).length >= 20) {
      throw StateError('20 tarot yorumu yıldızlı. Önce bir yıldızı kaldır.');
    }
    _put(data, draw.copy(starred: value));
  });
  Future<void> delete(String id) => _change((data) {
    final draw = _find(data, id);
    if (draw.result.state == TarotResultState.running) {
      throw StateError('Önce yorum işlemini iptal et.');
    }
    if (draw.spread == TarotSpread.daily && draw.day == localTarotDay(now())) {
      final days = data['deletedDailyDays'] as List;
      if (!days.contains(draw.day)) days.add(draw.day);
    }
    (data['draws'] as List).removeWhere((j) => j['id'] == id);
    // Old tombstones have no role once their local day has passed.
    (data['deletedDailyDays'] as List).removeWhere(
      (day) => day != localTarotDay(now()),
    );
  });
}
