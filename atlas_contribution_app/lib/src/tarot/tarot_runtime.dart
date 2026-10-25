import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../ai/ai_client.dart' show AiCancellation;
import '../ai/ai_contract.dart';
import '../ai/ai_runtime.dart';
import 'tarot_ai.dart';
import 'tarot_models.dart';
import 'tarot_store.dart';

typedef TarotGenerate = Future<String> Function(TarotDraw, AiCancellation);

class TarotRuntime extends ChangeNotifier {
  TarotRuntime({
    required this.store,
    required this.catalog,
    required this.generateReading,
    required this.promptVersion,
    required this.promptHash,
    this.reportingRuntime,
  });
  final TarotStore store;
  final List<TarotCard> catalog;
  final TarotGenerate generateReading;
  final String promptVersion, promptHash;
  final AiRuntime? reportingRuntime;
  final Map<String, ({AiCancellation cancellation, String attemptId})> _active =
      {};
  bool busy(String id) => _active.containsKey(id);
  static Future<TarotRuntime> create(
    Directory directory,
    AiRuntime? ai, {
    TarotAiClient? client,
  }) async {
    final catalog = loadTarotCatalog(
      await rootBundle.loadString('assets/tarot/catalog-v1.json'),
    );
    final tarotClient =
        client ??
        TarotAiClient(
          await rootBundle.loadString('assets/tarot-prompt-v1.json'),
        );
    final store = TarotStore(directory);
    await store.initialize();
    return TarotRuntime(
      store: store,
      catalog: catalog,
      promptVersion: tarotClient.version,
      promptHash: tarotClient.hash,
      reportingRuntime: ai,
      generateReading: (draw, cancellation) async {
        if (ai == null) {
          throw const AiFailure(
            'Yorum bağlantısı bu sürümde hazır değil. Kartlarını çevrimdışı açabilirsin.',
          );
        }
        final profile = (await ai.store.profiles())
            .where((p) => !playTestEnabled || p.provider == AiProvider.atlas)
            .firstOrNull;
        cancellation.check();
        if (profile == null) {
          throw const AiFailure(
            'Tarot yorum hizmeti bu bağlantıda henüz kullanılamıyor. Kartların telefonda korunuyor.',
          );
        }
        final key = await ai.key(profile);
        cancellation.check();
        return tarotClient.generate(draw, profile, key, cancellation);
      },
    );
  }

  Future<void> generate(String id) async {
    if (busy(id)) return;
    final cancellation = AiCancellation();
    final attempt = const Uuid().v4();
    _active[id] = (cancellation: cancellation, attemptId: attempt);
    notifyListeners(); // Synchronous guard across screens/double taps.
    var persisted = false;
    try {
      final draw = await store.begin(id, attempt, promptVersion, promptHash);
      persisted = true;
      cancellation.check();
      notifyListeners();
      final text = await generateReading(draw, cancellation);
      cancellation.check();
      await store.finish(id, attempt, TarotResultState.completed, text: text);
    } catch (error) {
      if (!persisted) rethrow;
      await store.finish(
        id,
        attempt,
        cancellation.cancelled
            ? TarotResultState.cancelled
            : TarotResultState.failed,
        error: cancellation.cancelled
            ? 'Yorum işlemi iptal edildi. Kartların korunuyor.'
            : error is AiFailure
            ? error.message
            : 'Yorum tamamlanamadı. Aynı kartlarla yeniden deneyebilirsin.',
      );
    } finally {
      if (_active[id]?.attemptId == attempt) {
        _active.remove(id);
      }
      notifyListeners();
    }
  }

  Future<void> cancel(String id) async {
    final active = _active[id];
    if (active == null) return;
    await active.cancellation.cancel();
    await store.finish(
      id,
      active.attemptId,
      TarotResultState.cancelled,
      error: 'Yorum işlemi iptal edildi. Kartların korunuyor.',
    );
    notifyListeners();
  }
}
