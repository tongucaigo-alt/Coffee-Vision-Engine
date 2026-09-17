import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';
import 'models.dart';

String cameraCaptureTitle(CaptureRole role) => switch (role) {
  CaptureRole.free => 'Telvenin en yoğun olduğu bölgeyi göster',
  CaptureRole.handleRight => 'Kulpu sağdaki çizgiyle hizala',
  CaptureRole.handleLeft => 'Kulpu soldaki çizgiyle hizala',
  CaptureRole.top => role.title,
};

String cameraCaptureInstruction(CaptureRole role) => role == CaptureRole.top
    ? role.instruction
    : 'Fincanı sabit tut, kamerayı hareket ettir.';

CoffeeCameraConfig cameraConfigForRole(CaptureRole role) => CoffeeCameraConfig(
  backgroundBlurSigma: 5,
  theme: const CoffeeCameraTheme(overlay: Color(0x55000000)),
  handleGuide: switch (role) {
    CaptureRole.handleRight => CameraHandleGuide.right,
    CaptureRole.handleLeft => CameraHandleGuide.left,
    _ => CameraHandleGuide.none,
  },
  thresholds: QualityThresholds(
    maximumAngleDegrees: role == CaptureRole.free ? 90 : 12,
  ),
  strings: CoffeeCameraStrings(
    holdOverCup: role == CaptureRole.free
        ? 'Fincanın içini görünür tut.'
        : 'Fincanın içini yukarıdan göster.',
  ),
);
