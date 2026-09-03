enum CaptureQualityLevel { unsuitable, guidance, ready }

class QualityAssessment {
  const QualityAssessment({
    required this.score,
    required this.level,
    required this.cupDetected,
    required this.centered,
    required this.rightSize,
    required this.contained,
    required this.notClipped,
    required this.lightEnough,
    required this.sharpEnough,
    required this.angleOk,
    required this.stable,
    required this.cupDiameterRatio,
    required this.autoCaptureReady,
  });

  factory QualityAssessment.unavailable() {
    return const QualityAssessment(
      score: 0,
      level: CaptureQualityLevel.unsuitable,
      cupDetected: false,
      centered: false,
      rightSize: false,
      contained: false,
      notClipped: true,
      lightEnough: false,
      sharpEnough: false,
      angleOk: false,
      stable: false,
      cupDiameterRatio: 0,
      autoCaptureReady: false,
    );
  }

  final int score;
  final CaptureQualityLevel level;
  final bool cupDetected;
  final bool centered;
  final bool rightSize;
  final bool contained;
  final bool notClipped;
  final bool lightEnough;
  final bool sharpEnough;
  final bool angleOk;
  final bool stable;
  final double cupDiameterRatio;
  final bool autoCaptureReady;
}
