import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

enum CameraFailureType { permissionDenied, restricted, unavailable, unknown }

class CameraFailure implements Exception {
  const CameraFailure(this.type, this.message);

  final CameraFailureType type;
  final String message;

  @override
  String toString() => message;
}

abstract interface class CameraService {
  CameraController? get controller;
  bool get isInitialized;
  bool get hasMultipleCameras;
  FlashMode get flashMode;
  CameraDescription? get description;

  Future<void> initialize();
  Future<void> pause();
  Future<void> resume();
  Future<void> switchCamera();
  Future<void> cycleFlashMode();
  Future<void> setFocusPoint(Offset point);
  Future<void> startFrameStream(void Function(CameraImage image) onFrame);
  Future<void> stopFrameStream();
  Future<XFile> takePicture();
  Future<void> dispose();
}

class PluginCameraService implements CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  FlashMode _flashMode = FlashMode.off;
  void Function(CameraImage image)? _frameListener;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  bool get hasMultipleCameras => _cameras.length > 1;

  @override
  FlashMode get flashMode => _flashMode;

  @override
  CameraDescription? get description => _selectedCamera;

  @override
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw const CameraFailure(
          CameraFailureType.unavailable,
          'Cihazda kullanılabilir kamera bulunamadı.',
        );
      }
      _selectedCamera ??= _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      await _openSelectedCamera();
    } on CameraException catch (error) {
      throw _mapCameraException(error);
    }
  }

  Future<void> _openSelectedCamera() async {
    await _disposeController();
    final selected = _selectedCamera;
    if (selected == null) return;
    final imageFormat = defaultTargetPlatform == TargetPlatform.iOS
        ? ImageFormatGroup.bgra8888
        : ImageFormatGroup.yuv420;
    final next = CameraController(
      selected,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: imageFormat,
    );
    _controller = next;
    await next.initialize();
    _flashMode = FlashMode.off;
    await next.setFlashMode(_flashMode);
  }

  @override
  Future<void> pause() async {
    await stopFrameStream();
    await _disposeController();
  }

  @override
  Future<void> resume() async {
    if (isInitialized) return;
    try {
      if (_selectedCamera == null) {
        await initialize();
      } else {
        await _openSelectedCamera();
      }
      final listener = _frameListener;
      if (listener != null) await startFrameStream(listener);
    } on CameraException catch (error) {
      throw _mapCameraException(error);
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    final currentIndex = _cameras.indexOf(_selectedCamera!);
    _selectedCamera = _cameras[(currentIndex + 1) % _cameras.length];
    final listener = _frameListener;
    await _openSelectedCamera();
    if (listener != null) await startFrameStream(listener);
  }

  @override
  Future<void> cycleFlashMode() async {
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.torch,
      _ => FlashMode.off,
    };
    try {
      await _controller?.setFlashMode(next);
      _flashMode = next;
    } on CameraException {
      await _controller?.setFlashMode(FlashMode.off);
      _flashMode = FlashMode.off;
    }
  }

  @override
  Future<void> setFocusPoint(Offset point) async {
    final active = _controller;
    if (active == null || !active.value.isInitialized) return;
    try {
      await active.setFocusPoint(point);
      await active.setExposurePoint(point);
    } on CameraException {
      // Some fixed-focus cameras do not support focus or exposure points.
    }
  }

  @override
  Future<void> startFrameStream(
    void Function(CameraImage image) onFrame,
  ) async {
    _frameListener = onFrame;
    final active = _controller;
    if (active == null ||
        !active.value.isInitialized ||
        active.value.isStreamingImages) {
      return;
    }
    try {
      await active.startImageStream(onFrame);
    } on CameraException {
      // Manual capture remains available if a device cannot stream frames.
    }
  }

  @override
  Future<void> stopFrameStream() async {
    final active = _controller;
    if (active == null ||
        !active.value.isInitialized ||
        !active.value.isStreamingImages) {
      return;
    }
    try {
      await active.stopImageStream();
    } on CameraException {
      // The camera may already have stopped during a lifecycle transition.
    }
  }

  @override
  Future<XFile> takePicture() async {
    final active = _controller;
    if (active == null || !active.value.isInitialized) {
      throw const CameraFailure(
        CameraFailureType.unavailable,
        'Kamera çekime hazır değil.',
      );
    }
    await stopFrameStream();
    try {
      return await active.takePicture();
    } on CameraException catch (error) {
      throw _mapCameraException(error);
    }
  }

  @override
  Future<void> dispose() async {
    _frameListener = null;
    await _disposeController();
  }

  Future<void> _disposeController() async {
    final previous = _controller;
    _controller = null;
    if (previous != null) await previous.dispose();
  }

  CameraFailure _mapCameraException(CameraException error) {
    final type = switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' => CameraFailureType.permissionDenied,
      'CameraAccessRestricted' => CameraFailureType.restricted,
      _ => CameraFailureType.unknown,
    };
    return CameraFailure(type, error.description ?? error.code);
  }
}
