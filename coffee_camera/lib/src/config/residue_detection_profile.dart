import 'dart:ui';

import 'package:flutter/foundation.dart';

enum ResidueCaptureType { cupInterior, saucerResidue }

enum ResidueAnalysisShape { ellipse, roundedRectangle }

@immutable
class ResidueDetectionProfile {
  const ResidueDetectionProfile({
    this.type = ResidueCaptureType.saucerResidue,
    this.gridSize = 32,
    this.normalizedAnalysisBounds = const Rect.fromLTWH(0.09, 0.24, 0.82, 0.36),
    this.minimumCoverage = 0.008,
    this.maximumCoverage = 0.55,
    this.minimumActiveCells = 8,
    this.minimumScore = 0.24,
    this.minimumStableConfidence = 0.58,
    this.analysisShape = ResidueAnalysisShape.roundedRectangle,
    this.luminanceContrastWeight = 0.55,
    this.chromaDifferenceWeight = 0.30,
    this.textureWeight = 0.15,
    this.minimumCandidateIntensity = 0.24,
    this.minimumComponentCells = 3,
    this.strongComponentMinimumIntensity = 0.58,
    this.preserveMultipleComponents = true,
    this.positiveFramesRequired = 2,
    this.negativeFramesRequired = 5,
    this.localReferenceRadius = 4,
    this.boundaryInnerRatio = 0.88,
  });

  final ResidueCaptureType type;
  final int gridSize;
  final Rect normalizedAnalysisBounds;
  final double minimumCoverage;
  final double maximumCoverage;
  final int minimumActiveCells;
  final double minimumScore;
  final double minimumStableConfidence;
  final ResidueAnalysisShape analysisShape;
  final double luminanceContrastWeight;
  final double chromaDifferenceWeight;
  final double textureWeight;
  final double minimumCandidateIntensity;
  final int minimumComponentCells;
  final double strongComponentMinimumIntensity;
  final bool preserveMultipleComponents;
  final int positiveFramesRequired;
  final int negativeFramesRequired;
  final int localReferenceRadius;
  final double boundaryInnerRatio;
}
