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
  presentation: CoffeeCameraPresentation(
    backgroundImage: const AssetImage('assets/brand/atlas-logo.png'),
    title: 'Fincanını Tara',
    stepLabel:
        '${role.title} · ${switch (role) {
          CaptureRole.handleRight => 2,
          CaptureRole.handleLeft => 3,
          _ => 1,
        }}/3',
    instruction: switch (role) {
      CaptureRole.top => role.instruction,
      CaptureRole.free =>
        'Fincan sabit kalsın; kamerayla telvenin yoğun bölgesini göster.',
      CaptureRole.handleRight =>
        'Fincan sabit kalsın; kamerayı sağ kulp çizgisine göre hizala.',
      CaptureRole.handleLeft =>
        'Fincan sabit kalsın; kamerayı sol kulp çizgisine göre hizala.',
    },
  ),
  backgroundBlurSigma: 5,
  showQualityScore: false,
  coffeeActivationFrames: 2,
  coffeeReleaseFrames: 3,
  theme: const CoffeeCameraTheme(
    overlay: Color(0x55000000),
    background: Color(0xff1e100a),
    foreground: Color(0xfffaf7f2),
    mutedForeground: Color(0xffdfd5c4),
  ),
  handleGuide: switch (role) {
    CaptureRole.handleRight => CameraHandleGuide.right,
    CaptureRole.handleLeft => CameraHandleGuide.left,
    _ => CameraHandleGuide.none,
  },
  thresholds: QualityThresholds(
    maximumCenterDistanceRatio: 0.26,
    minimumCupDiameterRatio: 0.64,
    maximumCupDiameterRatio: 0.96,
    maximumAngleDegrees: role == CaptureRole.free ? 90 : 18,
  ),
  strings: CoffeeCameraStrings(
    approve: 'Bu fotoğrafı kullan',
    holdOverCup: role == CaptureRole.free
        ? 'Fincanın içini görünür tut.'
        : 'Fincanın içini yukarıdan göster.',
  ),
);

CoffeeCameraConfig cameraConfigForSaucer() => const CoffeeCameraConfig(
  showQualityScore: false,
  presentation: CoffeeCameraPresentation(
    backgroundImage: AssetImage('assets/brand/atlas-logo.png'),
    title: 'Tabak Fotoğrafı',
    stepLabel: 'İsteğe bağlı',
    instruction: 'Tabağı hedef alana yerleştir.',
  ),
  theme: CoffeeCameraTheme(
    overlay: Color(0x55000000),
    background: Color(0xff1e100a),
    foreground: Color(0xfffaf7f2),
    mutedForeground: Color(0xffdfd5c4),
  ),
  strings: CoffeeCameraStrings(approve: 'Bu fotoğrafı kullan'),
);
