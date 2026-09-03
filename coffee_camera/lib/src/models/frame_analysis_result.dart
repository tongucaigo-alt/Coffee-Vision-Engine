import 'cup_detection_result.dart';
import 'coffee_region_mask.dart';

class FrameAnalysisResult {
  const FrameAnalysisResult({
    required this.cupAnalysisAvailable,
    required this.cup,
    required this.brightness,
    required this.sharpness,
    required this.darkPixelRatio,
    required this.coffeePresenceScore,
    this.coffeeDetected = false,
    this.coffeeMask,
    required this.angleDegrees,
    required this.isStable,
    required this.timestamp,
  });

  factory FrameAnalysisResult.initial({
    bool cupAnalysisAvailable = false,
    DateTime? timestamp,
  }) {
    return FrameAnalysisResult(
      cupAnalysisAvailable: cupAnalysisAvailable,
      cup: null,
      brightness: 0.5,
      sharpness: 0.5,
      darkPixelRatio: 0,
      coffeePresenceScore: 0,
      coffeeDetected: false,
      angleDegrees: 0,
      isStable: true,
      timestamp: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final bool cupAnalysisAvailable;
  final CupDetectionResult? cup;
  final double brightness;
  final double sharpness;
  final double darkPixelRatio;
  final double coffeePresenceScore;
  final bool coffeeDetected;
  final CoffeeRegionMask? coffeeMask;
  final double angleDegrees;
  final bool isStable;
  final DateTime timestamp;

  FrameAnalysisResult copyWith({
    bool? cupAnalysisAvailable,
    CupDetectionResult? cup,
    bool clearCup = false,
    double? brightness,
    double? sharpness,
    double? darkPixelRatio,
    double? coffeePresenceScore,
    bool? coffeeDetected,
    CoffeeRegionMask? coffeeMask,
    bool clearCoffeeMask = false,
    double? angleDegrees,
    bool? isStable,
    DateTime? timestamp,
  }) {
    return FrameAnalysisResult(
      cupAnalysisAvailable: cupAnalysisAvailable ?? this.cupAnalysisAvailable,
      cup: clearCup ? null : (cup ?? this.cup),
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
      darkPixelRatio: darkPixelRatio ?? this.darkPixelRatio,
      coffeePresenceScore: coffeePresenceScore ?? this.coffeePresenceScore,
      coffeeDetected: coffeeDetected ?? this.coffeeDetected,
      coffeeMask: clearCoffeeMask ? null : (coffeeMask ?? this.coffeeMask),
      angleDegrees: angleDegrees ?? this.angleDegrees,
      isStable: isStable ?? this.isStable,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
