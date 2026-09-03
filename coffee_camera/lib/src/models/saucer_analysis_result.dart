import 'residue_analysis_result.dart';
import 'saucer_detection_result.dart';

class SaucerAnalysisResult {
  const SaucerAnalysisResult({
    required this.analysisAvailable,
    required this.saucer,
    required this.brightness,
    required this.sharpness,
    required this.angleDegrees,
    required this.isStable,
    required this.timestamp,
    this.residue = const ResidueAnalysisResult.empty(),
  });

  factory SaucerAnalysisResult.initial({
    bool analysisAvailable = false,
    DateTime? timestamp,
  }) {
    return SaucerAnalysisResult(
      analysisAvailable: analysisAvailable,
      saucer: null,
      brightness: 0.5,
      sharpness: 0.5,
      angleDegrees: 0,
      isStable: true,
      timestamp: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
      residue: const ResidueAnalysisResult.empty(),
    );
  }

  final bool analysisAvailable;
  final SaucerDetectionResult? saucer;
  final double brightness;
  final double sharpness;
  final double angleDegrees;
  final bool isStable;
  final DateTime timestamp;
  final ResidueAnalysisResult residue;

  SaucerAnalysisResult copyWith({
    bool? analysisAvailable,
    SaucerDetectionResult? saucer,
    bool clearSaucer = false,
    double? brightness,
    double? sharpness,
    double? angleDegrees,
    bool? isStable,
    DateTime? timestamp,
    ResidueAnalysisResult? residue,
    bool clearResidue = false,
  }) {
    return SaucerAnalysisResult(
      analysisAvailable: analysisAvailable ?? this.analysisAvailable,
      saucer: clearSaucer ? null : (saucer ?? this.saucer),
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
      angleDegrees: angleDegrees ?? this.angleDegrees,
      isStable: isStable ?? this.isStable,
      timestamp: timestamp ?? this.timestamp,
      residue: clearResidue
          ? const ResidueAnalysisResult.empty()
          : (residue ?? this.residue),
    );
  }
}
