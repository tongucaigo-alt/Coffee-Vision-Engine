import 'dart:ui';

import '../config/coffee_camera_config.dart';
import '../models/quality_assessment.dart';
import '../models/saucer_analysis_result.dart';
import 'saucer_failure_classifier.dart';

class SaucerReadyStabilizer {
  SaucerReadyStabilizer(this.config);

  final CoffeeCameraConfig config;
  var _positiveFrames = 0;
  var _negativeFrames = 0;
  var _ready = false;
  final SaucerFailureClassifier _failureClassifier =
      const SaucerFailureClassifier();

  bool get isReady => _ready;

  bool update({
    required SaucerAnalysisResult result,
    required QualityAssessment assessment,
    required Size viewportSize,
  }) {
    if (_failureClassifier.isHardFailure(
      result: result,
      viewportSize: viewportSize,
      config: config,
    )) {
      reset();
      return false;
    }

    if (_isPositive(result, assessment)) {
      _negativeFrames = 0;
      _positiveFrames++;
      if (_positiveFrames >= config.saucerConfig.readyPositiveFrames) {
        _ready = true;
      }
      return _ready;
    }

    _positiveFrames = 0;
    _negativeFrames++;
    if (_negativeFrames >= config.saucerConfig.readyNegativeFrames) {
      _ready = false;
    }
    return _ready;
  }

  bool _isPositive(SaucerAnalysisResult result, QualityAssessment assessment) {
    final residue = result.residue;
    final profile = config.saucerConfig.residueProfile;
    return assessment.cupDetected &&
        assessment.stable &&
        assessment.lightEnough &&
        residue.mask != null &&
        residue.coverage >= profile.minimumCoverage &&
        residue.coverage <= profile.maximumCoverage &&
        residue.activeCellCount >= profile.minimumActiveCells &&
        residue.score >= profile.minimumScore &&
        residue.confidence >= profile.minimumStableConfidence;
  }

  void reset() {
    _positiveFrames = 0;
    _negativeFrames = 0;
    _ready = false;
  }
}
