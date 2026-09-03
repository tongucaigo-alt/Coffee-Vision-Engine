import 'dart:ui';

import 'residue_region_mask.dart';

class ResidueAnalysisResult {
  const ResidueAnalysisResult({
    required this.mask,
    required this.score,
    required this.confidence,
    required this.residueDetected,
    required this.residueBounds,
    required this.boundaryUsed,
    required this.analysisPerformed,
  });

  const ResidueAnalysisResult.empty({this.analysisPerformed = false})
    : mask = null,
      score = 0,
      confidence = 0,
      residueDetected = false,
      residueBounds = null,
      boundaryUsed = false;

  final ResidueRegionMask? mask;
  final double score;
  final double confidence;
  final bool residueDetected;
  final Rect? residueBounds;
  final bool boundaryUsed;
  final bool analysisPerformed;

  double get coverage => mask?.coverage ?? 0;
  int get activeCellCount => mask?.activeCellCount ?? 0;
  int get componentCount => mask?.componentCount ?? 0;

  ResidueAnalysisResult copyWith({
    ResidueRegionMask? mask,
    bool clearMask = false,
    double? score,
    double? confidence,
    bool? residueDetected,
    Rect? residueBounds,
    bool clearResidueBounds = false,
    bool? boundaryUsed,
    bool? analysisPerformed,
  }) {
    return ResidueAnalysisResult(
      mask: clearMask ? null : (mask ?? this.mask),
      score: score ?? this.score,
      confidence: confidence ?? this.confidence,
      residueDetected: residueDetected ?? this.residueDetected,
      residueBounds: clearResidueBounds
          ? null
          : (residueBounds ?? this.residueBounds),
      boundaryUsed: boundaryUsed ?? this.boundaryUsed,
      analysisPerformed: analysisPerformed ?? this.analysisPerformed,
    );
  }
}
