import '../config/coffee_camera_config.dart';
import '../models/quality_assessment.dart';
import '../models/residue_analysis_result.dart';

class SaucerResidueGuidanceEngine {
  const SaucerResidueGuidanceEngine();

  String message({
    required ResidueAnalysisResult residue,
    required QualityAssessment assessment,
    required CoffeeCameraConfig config,
  }) {
    final strings = config.strings;
    if (!residue.analysisPerformed) return strings.positionSaucerResidue;
    if (residue.residueDetected) return strings.saucerResidueFound;
    if (!assessment.stable) return strings.holdCameraStill;
    if (!assessment.lightEnough) return strings.moveToBrighterArea;
    if (!_hasCandidate(residue, config)) {
      return strings.moveSaucerResidueCloser;
    }
    return strings.inspectingSaucerResidue;
  }

  bool _hasCandidate(ResidueAnalysisResult residue, CoffeeCameraConfig config) {
    final profile = config.saucerConfig.residueProfile;
    return residue.mask != null &&
        residue.coverage >= profile.minimumCoverage &&
        residue.coverage <= profile.maximumCoverage &&
        residue.activeCellCount >= profile.minimumActiveCells &&
        residue.score >= profile.minimumScore;
  }
}
