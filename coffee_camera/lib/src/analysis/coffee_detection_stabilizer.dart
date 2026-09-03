import '../config/coffee_camera_config.dart';
import '../models/coffee_region_mask.dart';
import '../models/frame_analysis_result.dart';

class CoffeeDetectionStabilizer {
  CoffeeDetectionStabilizer(this.config);

  final CoffeeCameraConfig config;
  int _successCount = 0;
  int _failureCount = 0;
  bool _active = false;
  CoffeeRegionMask? _lastMask;

  FrameAnalysisResult update(FrameAnalysisResult result) {
    final mask = result.coffeeMask;
    final valid =
        result.cup != null &&
        result.cup!.confidence >= config.minimumCupConfidence &&
        result.coffeePresenceScore >= config.minimumCoffeePresence &&
        mask != null &&
        mask.coverage >= config.minimumGroundCoverage &&
        mask.coverage <= config.maximumGroundCoverage &&
        mask.activeCellCount >= 24;

    if (valid) {
      _failureCount = 0;
      _successCount++;
      _lastMask = mask;
      if (_successCount >= config.coffeeActivationFrames) _active = true;
    } else {
      _successCount = 0;
      _failureCount++;
      if (_failureCount >= config.coffeeReleaseFrames) {
        _active = false;
        _lastMask = null;
      }
    }

    if (!_active) {
      return result.copyWith(coffeeDetected: false, clearCoffeeMask: true);
    }
    return result.copyWith(coffeeDetected: true, coffeeMask: _lastMask);
  }

  void reset() {
    _successCount = 0;
    _failureCount = 0;
    _active = false;
    _lastMask = null;
  }
}
