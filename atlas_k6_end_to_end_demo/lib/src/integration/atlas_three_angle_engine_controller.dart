import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/foundation.dart';

import '../capture/atlas_three_angle_capture_models.dart';
import 'atlas_k6_result.dart';
import 'atlas_k6_surface_processor.dart';
import 'atlas_three_angle_engine_models.dart';

typedef AtlasThreeAngleSurfaceOperation =
    Future<AtlasK6SurfaceResult> Function({
      required AtlasCupCaptureRole role,
      required String path,
    });

final class AtlasThreeAngleEngineController extends ChangeNotifier {
  factory AtlasThreeAngleEngineController({
    required AtlasThreeAngleSurfaceOperation processSurface,
    String? setupError,
  }) => AtlasThreeAngleEngineController._(processSurface, setupError);

  AtlasThreeAngleEngineController._(this._processSurface, this._setupError)
    : _state = AtlasThreeAngleEngineState.idle(setupError: _setupError);

  factory AtlasThreeAngleEngineController.withProcessor(
    AtlasK6SurfaceProcessor processor,
  ) => AtlasThreeAngleEngineController(
    processSurface: ({required role, required path}) =>
        processor.process(path: path, surfaceType: VisionSurfaceType.cup),
  );

  final AtlasThreeAngleSurfaceOperation _processSurface;
  final String? _setupError;

  AtlasThreeAngleEngineState _state;
  Future<void>? _activeOperation;
  var _generation = 0;
  var _closed = false;

  AtlasThreeAngleEngineState get state => _state;

  Future<bool> analyze(AtlasThreeAngleCupCaptureResult captureResult) async {
    if (_closed ||
        _state.phase != AtlasThreeAngleEnginePhase.idle ||
        _state.setupError != null) {
      return false;
    }
    final token = ++_generation;
    final operation = _runAnalysis(captureResult, token);
    return _waitFor(operation);
  }

  Future<bool> retry(AtlasCupCaptureRole role) async {
    if (_closed || _state.isBusy || !_state.isComplete) return false;
    final current = _state.result!;
    if (!current.resultFor(role).isTechnicalError) return false;

    final token = ++_generation;
    final operation = _runRetry(current, role, token);
    return _waitFor(operation);
  }

  bool reset() {
    if (_closed || _state.isBusy) return false;
    _setState(
      AtlasThreeAngleEngineState.idle(setupError: _setupError),
      ++_generation,
    );
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

  Future<bool> _waitFor(Future<void> operation) async {
    _activeOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeOperation, operation)) _activeOperation = null;
    }
    return true;
  }

  Future<void> _runAnalysis(
    AtlasThreeAngleCupCaptureResult captureResult,
    int token,
  ) async {
    final results = <AtlasThreeAngleAngleResult>[];
    for (final role in AtlasCupCaptureRole.values) {
      if (!_isCurrent(token)) return;
      _setState(
        AtlasThreeAngleEngineState.processing(
          captureResult: captureResult,
          activeRole: role,
          angleResults: results,
        ),
        token,
      );
      final capture = captureResult.captureFor(role);
      results.add(await _attempt(role, capture));
    }
    if (!_isCurrent(token)) return;
    _setState(
      AtlasThreeAngleEngineState.complete(
        AtlasThreeAngleEngineResult(
          captureResult: captureResult,
          angleResults: results,
        ),
      ),
      token,
    );
  }

  Future<void> _runRetry(
    AtlasThreeAngleEngineResult current,
    AtlasCupCaptureRole role,
    int token,
  ) async {
    _setState(
      AtlasThreeAngleEngineState.processing(
        captureResult: current.captureResult,
        activeRole: role,
        angleResults: current.angleResults,
      ),
      token,
    );
    final capture = current.captureResult.captureFor(role);
    final replacement = await _attempt(role, capture);
    if (!_isCurrent(token)) return;

    final results = [
      for (final result in current.angleResults)
        if (result.role == role) replacement else result,
    ];
    _setState(
      AtlasThreeAngleEngineState.complete(
        AtlasThreeAngleEngineResult(
          captureResult: current.captureResult,
          angleResults: results,
        ),
      ),
      token,
    );
  }

  Future<AtlasThreeAngleAngleResult> _attempt(
    AtlasCupCaptureRole role,
    CameraCaptureResult capture,
  ) async {
    try {
      final surfaceResult = await _processSurface(
        role: role,
        path: capture.croppedCupPath ?? capture.filePath,
      );
      return AtlasThreeAngleAngleResult.success(
        role: role,
        capture: capture,
        surfaceResult: surfaceResult,
      );
    } on AtlasSurfaceProcessingException catch (error) {
      return AtlasThreeAngleAngleResult.technicalError(
        role: role,
        capture: capture,
        failureStage: error.stage,
        errorMessage: error.safeMessage,
      );
    } catch (_) {
      return AtlasThreeAngleAngleResult.technicalError(
        role: role,
        capture: capture,
        failureStage: AtlasSurfaceProcessingStage.resultAssembly,
        errorMessage: 'Açı sonucu tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  void _setState(AtlasThreeAngleEngineState next, int token) {
    if (!_isCurrent(token)) return;
    _state = next;
    notifyListeners();
  }

  bool _isCurrent(int token) => !_closed && token == _generation;
}
