import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/guidance/saucer_residue_guidance_engine.dart';
import 'package:coffee_camera/src/models/quality_assessment.dart';
import 'package:coffee_camera/src/models/residue_analysis_result.dart';
import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CoffeeCameraConfig();
  const engine = SaucerResidueGuidanceEngine();

  test('uses residue-focused guidance priority', () {
    expect(
      engine.message(
        residue: const ResidueAnalysisResult.empty(),
        assessment: _assessment(),
        config: config,
      ),
      config.strings.positionSaucerResidue,
    );
    expect(
      engine.message(
        residue: _result(candidate: true),
        assessment: _assessment(stable: false),
        config: config,
      ),
      config.strings.holdCameraStill,
    );
    expect(
      engine.message(
        residue: _result(candidate: true),
        assessment: _assessment(lightEnough: false),
        config: config,
      ),
      config.strings.moveToBrighterArea,
    );
    expect(
      engine.message(
        residue: _result(candidate: false),
        assessment: _assessment(),
        config: config,
      ),
      config.strings.moveSaucerResidueCloser,
    );
    expect(
      engine.message(
        residue: _result(candidate: true),
        assessment: _assessment(),
        config: config,
      ),
      config.strings.inspectingSaucerResidue,
    );
    expect(
      engine.message(
        residue: _result(candidate: true, stabilized: true),
        assessment: _assessment(),
        config: config,
      ),
      config.strings.saucerResidueFound,
    );
    expect(
      engine.message(
        residue: _result(candidate: true, stabilized: true),
        assessment: _assessment(stable: false, lightEnough: false),
        config: config,
      ),
      config.strings.saucerResidueFound,
    );
  });
}

QualityAssessment _assessment({bool stable = true, bool lightEnough = true}) {
  return QualityAssessment(
    score: 80,
    level: CaptureQualityLevel.guidance,
    cupDetected: true,
    centered: true,
    rightSize: true,
    contained: true,
    notClipped: true,
    lightEnough: lightEnough,
    sharpEnough: true,
    angleOk: true,
    stable: stable,
    cupDiameterRatio: 0.9,
    autoCaptureReady: false,
  );
}

ResidueAnalysisResult _result({
  required bool candidate,
  bool stabilized = false,
}) {
  final values = Uint8List(32 * 32);
  if (candidate) values.fillRange(0, 32, 220);
  final mask = ResidueRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.8, 0.4),
    width: 32,
    height: 32,
    intensities: values,
    coverage: candidate ? 0.04 : 0,
    residueBounds: candidate ? const Rect.fromLTWH(0.1, 0.2, 0.8, 0.04) : null,
    componentCount: candidate ? 1 : 0,
  );
  return ResidueAnalysisResult(
    mask: candidate ? mask : null,
    score: candidate ? 0.6 : 0,
    confidence: candidate ? 0.72 : 0,
    residueDetected: stabilized,
    residueBounds: candidate ? mask.residueBounds : null,
    boundaryUsed: false,
    analysisPerformed: true,
  );
}
