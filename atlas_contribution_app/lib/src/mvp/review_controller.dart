import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'review_engine.dart';
import 'review_models.dart';
import 'review_preparation.dart';
import 'review_store.dart';

final class ReviewController extends ChangeNotifier {
  factory ReviewController({
    required ReviewStore store,
    required ReviewSession session,
    Future<ReviewEngine> Function()? loadEngine,
  }) => ReviewController._(store, session, loadEngine ?? ReviewEngine.load);
  ReviewController._(this.store, this._session, this._loadEngine);
  final ReviewStore store;
  final Future<ReviewEngine> Function() _loadEngine;
  final Map<String, ReviewEngineOutput> _liveResults = {};
  ReviewSession _session;
  ReviewSession get session => _session;
  Map<String, ReviewEngineOutput> get liveResults =>
      Map.unmodifiable(_liveResults);
  String? activePhotoId, setupError;
  bool _closed = false;
  Future<void>? _running;
  bool get busy => _running != null;

  Future<void> save(ReviewSession next) async {
    if (busy || _closed) throw StateError('Review busy or closed');
    await store.save(next);
    _session = next;
    _liveResults.removeWhere(
      (id, value) => !next.photos.any(
        (p) => p.id == id && p.analysis?['runId'] == value.document['runId'],
      ),
    );
    notifyListeners();
  }

  Future<void> analyze({String? retryPhotoId}) {
    if (_closed || busy || !_session.ready) {
      throw StateError('Review not ready');
    }
    if (retryPhotoId != null &&
        !_session.photos.any((p) => p.id == retryPhotoId && p.failed)) {
      throw StateError('Only failed photos may be retried');
    }
    final run = _completeReview(retryPhotoId);
    _running = run;
    notifyListeners();
    return run.whenComplete(() {
      _running = null;
      if (!_closed) notifyListeners();
    });
  }

  Future<void> _completeReview(String? retryPhotoId) async {
    try {
      final exposures = await store.knownGroupExposures(_session);
      if (_closed) return;
      final captured = captureInitialObservations(
        _session,
        capturedAtUtc: DateTime.now().toUtc().toIso8601String(),
        priorExposures: exposures,
      );
      if (!identical(captured, _session)) {
        await store.save(captured);
        _session = captured;
        if (_closed) return;
        notifyListeners();
      }
      // Use the durably captured photos, including normalized skip decisions.
      final targets = _session.orderedPhotos
          .where(
            (p) => retryPhotoId == null ? !p.analyzed : p.id == retryPhotoId,
          )
          .toList();
      if (targets.isNotEmpty) {
        await _process(targets);
      } else {
        setupError = null;
      }
      if (_closed) return;
      final next = _session.next(
        preparedInput: prepareReviewInput(
          _session,
          preparedAtUtc: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      await store.save(next);
      _session = next;
      if (!_closed) notifyListeners();
    } finally {
      activePhotoId = null;
    }
  }

  Future<void> _process(List<ReviewPhoto> targets) async {
    setupError = null;
    final ReviewEngine engine;
    try {
      engine = await _loadEngine();
    } catch (_) {
      setupError = 'Fiziksel araştırma verisi doğrulanamadı.';
      return;
    }
    for (final p in targets) {
      if (_closed) break;
      activePhotoId = p.id;
      notifyListeners();
      ReviewEngineOutput? output;
      Map<String, dynamic> analysis;
      try {
        output = await engine.analyze(p, () => store.readPhoto(p));
        analysis = output.document;
      } catch (error) {
        analysis = {
          'version': 'atlas-local-analysis-v1',
          'runId': const Uuid().v4(),
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
          'photoId': p.id,
          'photoChecksum': p.photo.checksum,
          'surface': p.surface.name,
          'engineBaseline': mvpEngineBaseline,
          'outcome': 'technicalError',
          'errorStage': error is ReviewEngineFailure ? error.stage : 'unknown',
          'symbolAvailability': 'notConfigured',
          'symbols': <Object?>[],
        };
      }
      if (_closed) break;
      final next = _session.withPhoto(p.update(analysis: analysis));
      // Never publish a partial or undurable per-photo analysis.
      await store.save(next);
      _session = next;
      if (output != null) _liveResults[p.id] = output;
      if (!_closed) notifyListeners();
    }
    activePhotoId = null;
  }

  Future<void> close() async {
    _closed = true;
    await _running;
    activePhotoId = null;
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
