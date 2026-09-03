import 'package:flutter/material.dart';

import 'residue_detection_profile.dart';

@immutable
class QualityThresholds {
  const QualityThresholds({
    this.minimumDetectionConfidence = 0.65,
    this.maximumCenterDistanceRatio = 0.20,
    this.minimumCupDiameterRatio = 0.68,
    this.maximumCupDiameterRatio = 0.92,
    this.minimumBrightness = 0.28,
    this.minimumSharpness = 0.30,
    this.maximumAngleDegrees = 12,
    this.screenEdgeMargin = 0.015,
  });

  final double minimumDetectionConfidence;
  final double maximumCenterDistanceRatio;
  final double minimumCupDiameterRatio;
  final double maximumCupDiameterRatio;
  final double minimumBrightness;
  final double minimumSharpness;
  final double maximumAngleDegrees;
  final double screenEdgeMargin;
}

@immutable
class SaucerQualityThresholds {
  const SaucerQualityThresholds({
    this.minimumDetectionConfidence = 0.65,
    this.maximumCenterDistanceRatio = 0.20,
    this.minimumSaucerDiameterRatio = 0.88,
    this.maximumSaucerDiameterRatio = 0.98,
    this.minimumBrightness = 0.28,
    this.minimumSharpness = 0.30,
    this.maximumAngleDegrees = 12,
    this.screenEdgeMargin = 0.015,
    this.minimumRoundness = 0.88,
  });

  final double minimumDetectionConfidence;
  final double maximumCenterDistanceRatio;
  final double minimumSaucerDiameterRatio;
  final double maximumSaucerDiameterRatio;
  final double minimumBrightness;
  final double minimumSharpness;
  final double maximumAngleDegrees;
  final double screenEdgeMargin;
  final double minimumRoundness;
}

@immutable
class SaucerResidueEffectStyle {
  const SaucerResidueEffectStyle({
    this.scanDuration = const Duration(milliseconds: 1800),
    this.maskTransitionDuration = const Duration(milliseconds: 220),
    this.lockDuration = const Duration(milliseconds: 420),
    this.minimumVisibleConfidence = 0.36,
    this.minimumConfidenceOpacity = 0.40,
    this.minimumVisiblePoints = 20,
    this.maximumVisiblePoints = 64,
    this.phaseCount = 13,
    this.maximumSparkles = 4,
    this.sparkleIntensityThreshold = 0.90,
    this.targetStrokeWidth = 2.5,
    this.targetBreathingScale = 1.010,
    this.searchingTargetOpacity = 0.42,
    this.candidateTargetOpacity = 0.56,
    this.stableTargetOpacity = 0.78,
    this.stableInnerGlowOpacity = 0.055,
    this.scanBandHeightRatio = 0.295,
    this.scanBandAngleRadians = -0.07,
    this.searchingBandOpacity = 0.09,
    this.candidateBandOpacity = 0.14,
    this.stableBandOpacity = 0.19,
    this.scanBandCenterWhiteMix = 0.22,
    this.scanWaveBrightnessBoost = 0.31,
    this.pointCoreBaseRadius = 0.62,
    this.pointCoreIntensityRadius = 0.67,
    this.pointGlowRadiusRatio = 3.3,
    this.pointMinimumOpacity = 0.28,
    this.pointMaximumOpacity = 0.86,
    this.pointGlowOpacity = 0.245,
    this.pointBodyWhiteMix = 0.44,
    this.pointBodyScanWhiteMix = 0.26,
    this.pointCenterRadiusRatio = 0.46,
    this.pointCenterWhiteMix = 0.78,
    this.pointCenterScanWhiteMix = 0.06,
    this.pointCenterOpacityRatio = 0.90,
    this.sparkleWhiteMix = 0.82,
    this.lockPointBoost = 0.22,
    this.lockExpansion = 14.0,
    this.lockStrokeOpacity = 0.70,
  });

  final Duration scanDuration;
  final Duration maskTransitionDuration;
  final Duration lockDuration;
  final double minimumVisibleConfidence;
  final double minimumConfidenceOpacity;
  final int minimumVisiblePoints;
  final int maximumVisiblePoints;
  final int phaseCount;
  final int maximumSparkles;
  final double sparkleIntensityThreshold;
  final double targetStrokeWidth;
  final double targetBreathingScale;
  final double searchingTargetOpacity;
  final double candidateTargetOpacity;
  final double stableTargetOpacity;
  final double stableInnerGlowOpacity;
  final double scanBandHeightRatio;
  final double scanBandAngleRadians;
  final double searchingBandOpacity;
  final double candidateBandOpacity;
  final double stableBandOpacity;
  final double scanBandCenterWhiteMix;
  final double scanWaveBrightnessBoost;
  final double pointCoreBaseRadius;
  final double pointCoreIntensityRadius;
  final double pointGlowRadiusRatio;
  final double pointMinimumOpacity;
  final double pointMaximumOpacity;
  final double pointGlowOpacity;
  final double pointBodyWhiteMix;
  final double pointBodyScanWhiteMix;
  final double pointCenterRadiusRatio;
  final double pointCenterWhiteMix;
  final double pointCenterScanWhiteMix;
  final double pointCenterOpacityRatio;
  final double sparkleWhiteMix;
  final double lockPointBoost;
  final double lockExpansion;
  final double lockStrokeOpacity;
}

@immutable
class SaucerCaptureConfig {
  const SaucerCaptureConfig({
    this.targetDiameterWidthRatio = 0.86,
    this.targetMaximumHeightRatio = 0.50,
    this.targetCenter = const Offset(0.5, 0.42),
    this.cropPaddingRatio = 0.08,
    this.minimumSaucerConfidence = 0.68,
    this.readyPositiveFrames = 2,
    this.readyNegativeFrames = 5,
    this.residueProfile = const ResidueDetectionProfile(),
    this.residueEffectStyle = const SaucerResidueEffectStyle(),
    this.thresholds = const SaucerQualityThresholds(),
  });

  final double targetDiameterWidthRatio;
  final double targetMaximumHeightRatio;
  final Offset targetCenter;
  final double cropPaddingRatio;
  final double minimumSaucerConfidence;
  final int readyPositiveFrames;
  final int readyNegativeFrames;
  final ResidueDetectionProfile residueProfile;
  final SaucerResidueEffectStyle residueEffectStyle;
  final SaucerQualityThresholds thresholds;
}

@immutable
class CoffeeCameraStrings {
  const CoffeeCameraStrings({
    this.bringCupToTarget = 'Fincanı hedef alanına getir',
    this.moveCloser = 'Fincanı biraz yaklaştır',
    this.moveFarther = 'Fincanı biraz uzaklaştır',
    this.moveLeft = 'Fincanı biraz sola getir',
    this.moveRight = 'Fincanı biraz sağa getir',
    this.holdOverCup = 'Telefonu fincanın tam üzerine getir',
    this.tooBlurry = 'Görüntü bulanık, telefonu sabit tut',
    this.lowLight = 'Işık yetersiz',
    this.readyHoldStill = 'Hazır, sabit tut',
    this.capturing = 'Fotoğraf çekiliyor',
    this.cameraPermissionDenied = 'Kamera izni olmadan fotoğraf çekilemiyor.',
    this.cameraUnavailable = 'Kamera başlatılamadı.',
    this.retry = 'Tekrar dene',
    this.retake = 'Yeniden çek',
    this.approve = 'Fotoğrafı onayla',
    this.autoCapture = 'Otomatik çekim',
    this.cupCaptureStep = '1/2 Fincan çekimi',
    this.saucerCaptureStep = '2/2 Tabak çekimi',
    this.positionSaucer = 'Tabağı hedef alana yerleştir',
    this.moveSaucerCloser = 'Tabağa biraz yaklaş',
    this.moveSaucerFarther = 'Tabaktan biraz uzaklaş',
    this.moveSaucerLeft = 'Tabağı biraz sola getir',
    this.moveSaucerRight = 'Tabağı biraz sağa getir',
    this.moveSaucerUp = 'Tabağı biraz yukarı getir',
    this.moveSaucerDown = 'Tabağı biraz aşağı getir',
    this.levelOverSaucer = 'Telefonu tabağın tam üzerine getir',
    this.saucerReadyHoldStill = 'Tabak hazır, sabit tut',
    this.centerSaucer = 'Tabağı ortala',
    this.holdCameraStill = 'Kamerayı sabit tut',
    this.adjustingFocus = 'Netlik ayarlanıyor',
    this.moveToBrighterArea = 'Daha aydınlık bir alana geç',
    this.saucerReady = 'Tabak hazır',
    this.positionSaucerResidue =
        'Tabaktaki telve izlerini hedef alana yerleştir',
    this.moveSaucerResidueCloser = 'Telve izlerini hedef alana yaklaştır',
    this.inspectingSaucerResidue = 'Telve alanı inceleniyor',
    this.saucerResidueFound = 'Telve alanı bulundu',
  });

  final String bringCupToTarget;
  final String moveCloser;
  final String moveFarther;
  final String moveLeft;
  final String moveRight;
  final String holdOverCup;
  final String tooBlurry;
  final String lowLight;
  final String readyHoldStill;
  final String capturing;
  final String cameraPermissionDenied;
  final String cameraUnavailable;
  final String retry;
  final String retake;
  final String approve;
  final String autoCapture;
  final String cupCaptureStep;
  final String saucerCaptureStep;
  final String positionSaucer;
  final String moveSaucerCloser;
  final String moveSaucerFarther;
  final String moveSaucerLeft;
  final String moveSaucerRight;
  final String moveSaucerUp;
  final String moveSaucerDown;
  final String levelOverSaucer;
  final String saucerReadyHoldStill;
  final String centerSaucer;
  final String holdCameraStill;
  final String adjustingFocus;
  final String moveToBrighterArea;
  final String saucerReady;
  final String positionSaucerResidue;
  final String moveSaucerResidueCloser;
  final String inspectingSaucerResidue;
  final String saucerResidueFound;
}

@immutable
class CoffeeCameraTheme {
  const CoffeeCameraTheme({
    this.background = const Color(0xFF0E1114),
    this.overlay = const Color(0x99000000),
    this.idleRing = const Color(0xFFE6E8EA),
    this.warningRing = const Color(0xFFFFC857),
    this.readyRing = const Color(0xFF45D483),
    this.foreground = Colors.white,
    this.mutedForeground = const Color(0xFFB4BBC2),
  });

  final Color background;
  final Color overlay;
  final Color idleRing;
  final Color warningRing;
  final Color readyRing;
  final Color foreground;
  final Color mutedForeground;
}

@immutable
class CoffeeCameraEffectStyle {
  const CoffeeCameraEffectStyle({
    this.targetRingStrokeWidth = 4.0,
    this.ringColorTransitionDuration = const Duration(milliseconds: 220),
    this.ringPulseMaxScale = 1.010,
    this.readyRingPulseMaxScale = 1.006,
    this.ringPulseStrokeWidthDelta = 0.18,
    this.readyRingPulseStrokeWidthDelta = 0.10,
    this.ringPulseMinOpacity = 0.92,
    this.readyRingPulseMinOpacity = 0.95,
    this.ringPulseDuration = const Duration(milliseconds: 1400),
    this.readyRingPulseDuration = const Duration(milliseconds: 2000),
    this.scanLightCoreBaseRadius = 0.75,
    this.scanLightCoreIntensityRadius = 0.85,
    this.scanLightGlowBaseRadius = 2.40,
    this.scanLightGlowIntensityRadius = 2.10,
    this.scanLightGlowBlurSigma = 3.20,
    this.scanLightStarRayCoreRatio = 2.20,
    this.scanLightStarCenterCoreRatio = 0.45,
    this.scanLightCoreMinimumOpacity = 0.28,
    this.scanLightGlowMinimumOpacity = 0.12,
    this.scanLightGlowMaximumOpacity = 0.70,
    this.scanLightStarMaximumOpacity = 0.82,
    this.scanLineWhiteStrokeWidth = 0.90,
    this.scanLineBandStrokeWidth = 3.0,
    this.scanLineGlowHeight = 20.0,
    this.scanLineGlowCenterOpacity = 0.44,
    this.scanLineBandOpacity = 0.56,
    this.scanLineWhiteOpacity = 0.94,
    this.scanLineEdgeFadeFraction = 0.06,
    this.readyLockDuration = const Duration(milliseconds: 240),
    this.readyLockMaxScale = 1.012,
    this.readyLockWhiteMix = 0.28,
    this.saucerRingStrokeWidth = 5.0,
    this.saucerRingPulseMaxScale = 1.014,
    this.saucerReadyRingPulseMaxScale = 1.009,
    this.saucerRingPulseStrokeWidthDelta = 0.30,
    this.saucerReadyRingPulseStrokeWidthDelta = 0.16,
    this.saucerRingPulseMinOpacity = 0.86,
    this.saucerReadyRingPulseMinOpacity = 0.93,
    this.saucerSweepStrokeWidth = 5.4,
    this.saucerSweepWarningOpacity = 0.30,
    this.saucerSweepReadyOpacity = 0.76,
    this.saucerSweepWarningLength = 0.72,
    this.saucerSweepReadyLength = 1.22,
    this.saucerInnerGlowWarningOpacity = 0.018,
    this.saucerInnerGlowReadyOpacity = 0.035,
    this.saucerReadyExpansion = 0.045,
    this.saucerReadyExpansionOpacity = 0.48,
  });

  final double targetRingStrokeWidth;
  final Duration ringColorTransitionDuration;
  final double ringPulseMaxScale;
  final double readyRingPulseMaxScale;
  final double ringPulseStrokeWidthDelta;
  final double readyRingPulseStrokeWidthDelta;
  final double ringPulseMinOpacity;
  final double readyRingPulseMinOpacity;
  final Duration ringPulseDuration;
  final Duration readyRingPulseDuration;
  final double scanLightCoreBaseRadius;
  final double scanLightCoreIntensityRadius;
  final double scanLightGlowBaseRadius;
  final double scanLightGlowIntensityRadius;
  final double scanLightGlowBlurSigma;
  final double scanLightStarRayCoreRatio;
  final double scanLightStarCenterCoreRatio;
  final double scanLightCoreMinimumOpacity;
  final double scanLightGlowMinimumOpacity;
  final double scanLightGlowMaximumOpacity;
  final double scanLightStarMaximumOpacity;
  final double scanLineWhiteStrokeWidth;
  final double scanLineBandStrokeWidth;
  final double scanLineGlowHeight;
  final double scanLineGlowCenterOpacity;
  final double scanLineBandOpacity;
  final double scanLineWhiteOpacity;
  final double scanLineEdgeFadeFraction;
  final Duration readyLockDuration;
  final double readyLockMaxScale;
  final double readyLockWhiteMix;
  final double saucerRingStrokeWidth;
  final double saucerRingPulseMaxScale;
  final double saucerReadyRingPulseMaxScale;
  final double saucerRingPulseStrokeWidthDelta;
  final double saucerReadyRingPulseStrokeWidthDelta;
  final double saucerRingPulseMinOpacity;
  final double saucerReadyRingPulseMinOpacity;
  final double saucerSweepStrokeWidth;
  final double saucerSweepWarningOpacity;
  final double saucerSweepReadyOpacity;
  final double saucerSweepWarningLength;
  final double saucerSweepReadyLength;
  final double saucerInnerGlowWarningOpacity;
  final double saucerInnerGlowReadyOpacity;
  final double saucerReadyExpansion;
  final double saucerReadyExpansionOpacity;
}

@immutable
class CoffeeCameraConfig {
  const CoffeeCameraConfig({
    this.analysisInterval = const Duration(milliseconds: 250),
    this.autoCaptureStableDuration = const Duration(milliseconds: 1200),
    this.targetDiameterWidthRatio = 0.72,
    this.targetCenter = const Offset(0.5, 0.42),
    this.cropPaddingRatio = 0.08,
    this.minimumCoffeePresence = 0.18,
    this.minimumCupConfidence = 0.68,
    this.minimumGroundCoverage = 0.06,
    this.maximumGroundCoverage = 0.70,
    this.coffeeActivationFrames = 3,
    this.coffeeReleaseFrames = 2,
    this.enableReleaseAutoCapture = false,
    this.enableReadyLockHaptic = false,
    this.initialAutoCaptureEnabled = true,
    this.showQualityScore = true,
    this.requireSaucerCapture = false,
    this.saucerConfig = const SaucerCaptureConfig(),
    this.thresholds = const QualityThresholds(),
    this.strings = const CoffeeCameraStrings(),
    this.theme = const CoffeeCameraTheme(),
    this.effectStyle = const CoffeeCameraEffectStyle(),
  });

  final Duration analysisInterval;
  final Duration autoCaptureStableDuration;
  final double targetDiameterWidthRatio;
  final Offset targetCenter;
  final double cropPaddingRatio;
  final double minimumCoffeePresence;
  final double minimumCupConfidence;
  final double minimumGroundCoverage;
  final double maximumGroundCoverage;
  final int coffeeActivationFrames;
  final int coffeeReleaseFrames;
  final bool enableReleaseAutoCapture;
  final bool enableReadyLockHaptic;
  final bool initialAutoCaptureEnabled;
  final bool showQualityScore;
  final bool requireSaucerCapture;
  final SaucerCaptureConfig saucerConfig;
  final QualityThresholds thresholds;
  final CoffeeCameraStrings strings;
  final CoffeeCameraTheme theme;
  final CoffeeCameraEffectStyle effectStyle;
}
