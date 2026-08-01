import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/foundation.dart';

import 'atlas_k6_result.dart';
import 'atlas_k6_state.dart';

typedef AtlasCaptureOperation = Future<CoffeeCameraCaptureResult?> Function();
typedef AtlasFeatureAnalyzer =
    Future<VisionFeatureSet> Function(VisionImageInput input);
typedef AtlasPatternAnalyzer =
    Future<PatternAnalysisResult> Function(VisionFeatureSet featureSet);
typedef AtlasKnowledgeMatcher =
    List<KnowledgeMatchResult> Function({
      required PatternCandidate candidate,
      required Iterable<KnowledgeRecord> records,
    });
typedef AtlasFileReader = Future<Uint8List> Function(String path);

final class AtlasK6Controller extends ChangeNotifier {
  AtlasK6Controller({
    required this.dataset,
    CoffeeVisionEngine? visionEngine,
    PatternEngine? patternEngine,
    KnowledgeRecordCollectionMatcher? knowledgeMatcher,
    AtlasFeatureAnalyzer? analyzeFeatures,
    AtlasPatternAnalyzer? analyzePatterns,
    AtlasKnowledgeMatcher? matchRecords,
    AtlasFileReader? readFile,
  }) : _analyzeFeatures =
           analyzeFeatures ??
           (visionEngine ?? CoffeeVisionEngine()).analyzeFeatures,
       _analyzePatterns =
           analyzePatterns ??
           (patternEngine ?? const PatternEngine()).analyzePatterns,
       _matchRecords =
           matchRecords ??
           (knowledgeMatcher ?? const KnowledgeRecordCollectionMatcher()).match,
       _readFile = readFile ?? _readFileBytes;

  final KnowledgeDatasetSnapshot dataset;
  final AtlasFeatureAnalyzer _analyzeFeatures;
  final AtlasPatternAnalyzer _analyzePatterns;
  final AtlasKnowledgeMatcher _matchRecords;
  final AtlasFileReader _readFile;

  AtlasK6State _state = const AtlasK6State.idle();
  Future<void>? _activeOperation;
  var _generation = 0;
  var _closed = false;

  AtlasK6State get state => _state;

  Future<bool> startCapture(AtlasCaptureOperation launchCapture) async {
    if (_closed || _state.isBusy) return false;

    final token = ++_generation;
    final previous = _state;
    final operation = _runCapture(launchCapture, previous, token);
    _activeOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeOperation, operation)) _activeOperation = null;
    }
    return true;
  }

  Future<bool> retry() async {
    if (_closed || _state.isBusy || !_state.canRetry) return false;

    final capture = _state.captureResult!;
    final retrySaucerOnly =
        _state.failureStage == AtlasK6FailureStage.saucerProcessing &&
        _state.cupResult != null;
    final token = ++_generation;
    final operation = _runProcessing(
      capture: capture,
      token: token,
      existingCupResult: retrySaucerOnly ? _state.cupResult : null,
    );
    _activeOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeOperation, operation)) _activeOperation = null;
    }
    return true;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    final operation = _activeOperation;
    if (operation != null) await operation;
    super.dispose();
  }

  Future<void> _runCapture(
    AtlasCaptureOperation launchCapture,
    AtlasK6State previous,
    int token,
  ) async {
    _setState(AtlasK6State.capturing(previous), token);

    CoffeeCameraCaptureResult? capture;
    try {
      capture = await launchCapture();
    } catch (_) {
      _setState(
        AtlasK6State.failure(
          failureStage: AtlasK6FailureStage.capture,
          errorMessage: 'Kamera akisi tamamlanamadi.',
          captureResult: previous.captureResult,
          cupResult: previous.cupResult,
        ),
        token,
      );
      return;
    }

    if (!_isCurrent(token)) return;
    if (capture == null) {
      _setState(previous, token);
      return;
    }
    if (capture.saucer == null) {
      _setState(
        AtlasK6State.failure(
          failureStage: AtlasK6FailureStage.capture,
          errorMessage: 'Fincan ve tabak cekimi birlikte tamamlanmalidir.',
          captureResult: capture,
        ),
        token,
      );
      return;
    }

    await _runProcessing(capture: capture, token: token);
  }

  Future<void> _runProcessing({
    required CoffeeCameraCaptureResult capture,
    required int token,
    AtlasK6SurfaceResult? existingCupResult,
  }) async {
    var cupResult = existingCupResult;
    if (cupResult == null) {
      _setState(AtlasK6State.processingCup(captureResult: capture), token);
      try {
        cupResult = await _processSurface(
          path: capture.cup.croppedCupPath ?? capture.cup.filePath,
          surfaceType: VisionSurfaceType.cup,
        );
      } catch (_) {
        _setState(
          AtlasK6State.failure(
            failureStage: AtlasK6FailureStage.cupProcessing,
            errorMessage: 'Fincan fiziksel eslestirmesi tamamlanamadi.',
            captureResult: capture,
          ),
          token,
        );
        return;
      }
      if (!_isCurrent(token)) return;
    }

    final completeCupResult = cupResult;
    _setState(
      AtlasK6State.processingSaucer(
        captureResult: capture,
        cupResult: completeCupResult,
      ),
      token,
    );

    AtlasK6SurfaceResult saucerResult;
    try {
      final saucer = capture.saucer!;
      saucerResult = await _processSurface(
        path: saucer.croppedSaucerPath ?? saucer.filePath,
        surfaceType: VisionSurfaceType.saucer,
      );
    } catch (_) {
      _setState(
        AtlasK6State.failure(
          failureStage: AtlasK6FailureStage.saucerProcessing,
          errorMessage: 'Tabak fiziksel eslestirmesi tamamlanamadi.',
          captureResult: capture,
          cupResult: completeCupResult,
        ),
        token,
      );
      return;
    }
    if (!_isCurrent(token)) return;

    _setState(
      AtlasK6State.success(
        AtlasK6EndToEndResult(
          captureResult: capture,
          datasetVersion: dataset.datasetVersion,
          cupResult: completeCupResult,
          saucerResult: saucerResult,
        ),
      ),
      token,
    );
  }

  Future<AtlasK6SurfaceResult> _processSurface({
    required String path,
    required VisionSurfaceType surfaceType,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final bytes = await _readFile(path);
      final featureSet = await _analyzeFeatures(
        VisionImageInput(imageBytes: bytes, surfaceType: surfaceType),
      );
      final patternResult = await _analyzePatterns(featureSet);
      final candidateResults = <AtlasK6CandidateResult>[];
      for (final candidate in patternResult.candidates) {
        candidateResults.add(
          AtlasK6CandidateResult(
            candidate: candidate,
            matches: _matchRecords(
              candidate: candidate,
              records: dataset.activeRecords,
            ),
          ),
        );
      }
      stopwatch.stop();
      return AtlasK6SurfaceResult(
        featureSet: featureSet,
        patternResult: patternResult,
        candidateResults: candidateResults,
        processingDuration: stopwatch.elapsed,
      );
    } catch (_) {
      stopwatch.stop();
      rethrow;
    }
  }

  void _setState(AtlasK6State next, int token) {
    if (!_isCurrent(token)) return;
    _state = next;
    notifyListeners();
  }

  bool _isCurrent(int token) => !_closed && token == _generation;

  static Future<Uint8List> _readFileBytes(String path) {
    return File(path).readAsBytes();
  }
}
