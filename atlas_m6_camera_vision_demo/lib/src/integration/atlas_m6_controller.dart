import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/foundation.dart';

import 'atlas_m6_result.dart';
import 'atlas_m6_state.dart';

typedef AtlasCaptureOperation = Future<CoffeeCameraCaptureResult?> Function();
typedef AtlasVisionAnalyzer =
    Future<VisionPipelineResult> Function(VisionImageInput input);
typedef AtlasFileReader = Future<Uint8List> Function(String path);
typedef AtlasFileDeleter = Future<void> Function(String path);

final class AtlasM6Controller extends ChangeNotifier {
  AtlasM6Controller({
    CoffeeVisionEngine? visionEngine,
    AtlasVisionAnalyzer? analyze,
    AtlasFileReader? readFile,
    AtlasFileDeleter? deleteFile,
  }) : _analyze =
           analyze ?? (visionEngine ?? CoffeeVisionEngine()).analyzeDetailed,
       _readFile = readFile ?? _readFileBytes,
       _deleteFile = deleteFile ?? _deleteFileIfPresent;

  final AtlasVisionAnalyzer _analyze;
  final AtlasFileReader _readFile;
  final AtlasFileDeleter _deleteFile;

  AtlasM6State _state = const AtlasM6State.idle();
  Future<void>? _activeOperation;
  var _generation = 0;
  var _closed = false;

  AtlasM6State get state => _state;

  Future<bool> startCapture(AtlasCaptureOperation launchCapture) async {
    if (_closed || _state.isBusy) return false;

    final token = ++_generation;
    final previous = _state;
    final operation = _runCapture(launchCapture, previous, token);
    _activeOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeOperation, operation)) {
        _activeOperation = null;
      }
    }
    return true;
  }

  Future<bool> retry() async {
    if (_closed || _state.isBusy || !_state.canRetry) return false;

    final capture = _state.captureResult!;
    final retrySaucerOnly =
        _state.failureStage == AtlasM6FailureStage.saucerAnalysis &&
        _state.cupVisionResult != null &&
        _state.cupAnalysisDuration != null;
    final token = ++_generation;
    final operation = _runAnalysis(
      capture: capture,
      token: token,
      existingCupResult: retrySaucerOnly ? _state.cupVisionResult : null,
      existingCupDuration: retrySaucerOnly ? _state.cupAnalysisDuration : null,
    );
    _activeOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeOperation, operation)) {
        _activeOperation = null;
      }
    }
    return true;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    final operation = _activeOperation;
    if (operation != null) {
      await operation;
    }
    await _deleteCaptureFiles(_state.captureResult);
    super.dispose();
  }

  Future<void> _runCapture(
    AtlasCaptureOperation launchCapture,
    AtlasM6State previous,
    int token,
  ) async {
    _setState(AtlasM6State.capturing(previous), token);

    CoffeeCameraCaptureResult? capture;
    try {
      capture = await launchCapture();
    } catch (_) {
      if (_isCurrent(token)) {
        _setState(
          AtlasM6State.failure(
            failureStage: AtlasM6FailureStage.capture,
            errorMessage: 'Kamera akisi tamamlanamadi.',
            captureResult: previous.captureResult,
            cupVisionResult: previous.cupVisionResult,
            cupAnalysisDuration: previous.cupAnalysisDuration,
            saucerAnalysisDuration: previous.saucerAnalysisDuration,
          ),
          token,
        );
      }
      return;
    }

    if (!_isCurrent(token)) {
      await _deleteCaptureFiles(capture);
      return;
    }
    if (capture == null) {
      _setState(previous, token);
      return;
    }
    if (capture.saucer == null) {
      await _deleteCaptureFiles(previous.captureResult);
      _setState(
        AtlasM6State.failure(
          failureStage: AtlasM6FailureStage.capture,
          errorMessage: 'Fincan ve tabak cekimi birlikte tamamlanmalidir.',
          captureResult: capture,
        ),
        token,
      );
      return;
    }

    await _deleteCaptureFiles(previous.captureResult);
    if (!_isCurrent(token)) {
      await _deleteCaptureFiles(capture);
      return;
    }
    await _runAnalysis(capture: capture, token: token);
  }

  Future<void> _runAnalysis({
    required CoffeeCameraCaptureResult capture,
    required int token,
    VisionPipelineResult? existingCupResult,
    Duration? existingCupDuration,
  }) async {
    var cupResult = existingCupResult;
    var cupDuration = existingCupDuration;

    if (cupResult == null || cupDuration == null) {
      _setState(AtlasM6State.analyzingCup(captureResult: capture), token);
      final stopwatch = Stopwatch()..start();
      try {
        final cupPath = capture.cup.croppedCupPath ?? capture.cup.filePath;
        final bytes = await _readFile(cupPath);
        cupResult = await _analyze(
          VisionImageInput(
            imageBytes: bytes,
            surfaceType: VisionSurfaceType.cup,
          ),
        );
      } catch (_) {
        stopwatch.stop();
        _setState(
          AtlasM6State.failure(
            failureStage: AtlasM6FailureStage.cupAnalysis,
            errorMessage: 'Fincan analizi tamamlanamadi.',
            captureResult: capture,
            cupAnalysisDuration: stopwatch.elapsed,
          ),
          token,
        );
        return;
      }
      stopwatch.stop();
      cupDuration = stopwatch.elapsed;
      if (!_isCurrent(token)) return;
    }

    final completeCupResult = cupResult;
    final completeCupDuration = cupDuration;
    _setState(
      AtlasM6State.analyzingSaucer(
        captureResult: capture,
        cupVisionResult: completeCupResult,
        cupAnalysisDuration: completeCupDuration,
      ),
      token,
    );

    final stopwatch = Stopwatch()..start();
    VisionPipelineResult saucerResult;
    try {
      final saucerCapture = capture.saucer!;
      final saucerPath =
          saucerCapture.croppedSaucerPath ?? saucerCapture.filePath;
      final bytes = await _readFile(saucerPath);
      saucerResult = await _analyze(
        VisionImageInput(
          imageBytes: bytes,
          surfaceType: VisionSurfaceType.saucer,
        ),
      );
    } catch (_) {
      stopwatch.stop();
      _setState(
        AtlasM6State.failure(
          failureStage: AtlasM6FailureStage.saucerAnalysis,
          errorMessage: 'Tabak analizi tamamlanamadi.',
          captureResult: capture,
          cupVisionResult: completeCupResult,
          cupAnalysisDuration: completeCupDuration,
          saucerAnalysisDuration: stopwatch.elapsed,
        ),
        token,
      );
      return;
    }
    stopwatch.stop();
    if (!_isCurrent(token)) return;

    _setState(
      AtlasM6State.success(
        AtlasM6CameraVisionResult(
          captureResult: capture,
          cupVisionResult: completeCupResult,
          saucerVisionResult: saucerResult,
          cupAnalysisDuration: completeCupDuration,
          saucerAnalysisDuration: stopwatch.elapsed,
        ),
      ),
      token,
    );
  }

  void _setState(AtlasM6State next, int token) {
    if (!_isCurrent(token)) return;
    _state = next;
    notifyListeners();
  }

  bool _isCurrent(int token) => !_closed && token == _generation;

  Future<void> _deleteCaptureFiles(CoffeeCameraCaptureResult? capture) async {
    if (capture == null) return;
    final paths = <String>{};
    _addCapturePaths(paths, capture.cup);
    final saucer = capture.saucer;
    if (saucer != null) _addCapturePaths(paths, saucer);
    for (final path in paths) {
      try {
        await _deleteFile(path);
      } catch (_) {
        // Cleanup is best-effort; analysis and user-visible state stay intact.
      }
    }
  }

  static void _addCapturePaths(Set<String> paths, CameraCaptureResult capture) {
    paths.add(capture.filePath);
    final cupPath = capture.croppedCupPath;
    final saucerPath = capture.croppedSaucerPath;
    if (cupPath != null) paths.add(cupPath);
    if (saucerPath != null) paths.add(saucerPath);
  }

  static Future<Uint8List> _readFileBytes(String path) {
    return File(path).readAsBytes();
  }

  static Future<void> _deleteFileIfPresent(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
