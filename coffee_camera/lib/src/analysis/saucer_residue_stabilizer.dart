import '../config/residue_detection_profile.dart';
import '../models/residue_analysis_result.dart';
import '../models/residue_region_mask.dart';

class SaucerResidueStabilizer {
  SaucerResidueStabilizer(this.profile);

  final ResidueDetectionProfile profile;
  var _positiveFrames = 0;
  var _negativeFrames = 0;
  var _active = false;
  ResidueRegionMask? _lastValidMask;

  bool get residueDetected => _active;

  ResidueAnalysisResult update(
    ResidueAnalysisResult result, {
    bool hardFailure = false,
  }) {
    if (hardFailure) {
      reset();
      return result.copyWith(
        residueDetected: false,
        clearMask: true,
        clearResidueBounds: true,
      );
    }

    final valid =
        result.residueDetected &&
        result.mask != null &&
        result.confidence >= profile.minimumStableConfidence;
    if (valid) {
      _negativeFrames = 0;
      _positiveFrames++;
      _lastValidMask = result.mask;
      if (_positiveFrames >= profile.positiveFramesRequired) _active = true;
    } else {
      _positiveFrames = 0;
      _negativeFrames++;
      if (_negativeFrames >= profile.negativeFramesRequired) {
        _active = false;
        _lastValidMask = null;
      }
    }

    if (!_active) {
      return result.copyWith(
        residueDetected: false,
        clearMask: _lastValidMask == null && !valid,
        clearResidueBounds: _lastValidMask == null && !valid,
      );
    }
    final mask = _lastValidMask;
    return result.copyWith(
      mask: mask,
      residueDetected: true,
      residueBounds: mask?.residueBounds,
    );
  }

  void reset() {
    _positiveFrames = 0;
    _negativeFrames = 0;
    _active = false;
    _lastValidMask = null;
  }
}
