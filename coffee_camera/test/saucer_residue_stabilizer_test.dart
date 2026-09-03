import 'dart:typed_data';
import 'dart:ui';

import 'package:coffee_camera/src/analysis/saucer_residue_stabilizer.dart';
import 'package:coffee_camera/src/config/residue_detection_profile.dart';
import 'package:coffee_camera/src/models/residue_analysis_result.dart';
import 'package:coffee_camera/src/models/residue_region_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ResidueDetectionProfile();

  test('activates in two frames and tolerates four soft failures', () {
    final stabilizer = SaucerResidueStabilizer(profile);
    final good = _result(valid: true);
    final bad = _result(valid: false);

    expect(stabilizer.update(good).residueDetected, isFalse);
    final active = stabilizer.update(good);
    expect(active.residueDetected, isTrue);
    for (var frame = 0; frame < 4; frame++) {
      final held = stabilizer.update(bad);
      expect(held.residueDetected, isTrue);
      expect(identical(held.mask, active.mask), isTrue);
    }
    final released = stabilizer.update(bad);
    expect(released.residueDetected, isFalse);
    expect(released.mask, isNull);
  });

  test('hard failure immediately clears ready and the retained mask', () {
    final stabilizer = SaucerResidueStabilizer(profile);
    stabilizer.update(_result(valid: true));
    expect(stabilizer.update(_result(valid: true)).residueDetected, isTrue);

    final failed = stabilizer.update(_result(valid: false), hardFailure: true);
    expect(failed.residueDetected, isFalse);
    expect(failed.mask, isNull);
  });

  test('reset clears the last stabilized mask and counters', () {
    final stabilizer = SaucerResidueStabilizer(profile);
    stabilizer.update(_result(valid: true));
    expect(stabilizer.update(_result(valid: true)).residueDetected, isTrue);
    stabilizer.reset();
    expect(stabilizer.residueDetected, isFalse);
    expect(stabilizer.update(_result(valid: true)).residueDetected, isFalse);
  });
}

ResidueAnalysisResult _result({required bool valid}) {
  final values = Uint8List(32 * 32);
  if (valid) values.fillRange(100, 120, 210);
  final mask = ResidueRegionMask(
    normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.8, 0.4),
    width: 32,
    height: 32,
    intensities: values,
    coverage: valid ? 0.025 : 0,
    residueBounds: valid ? const Rect.fromLTWH(0.2, 0.3, 0.2, 0.1) : null,
    componentCount: valid ? 1 : 0,
  );
  return ResidueAnalysisResult(
    mask: valid ? mask : null,
    score: valid ? 0.5 : 0,
    confidence: valid ? 0.72 : 0,
    residueDetected: valid,
    residueBounds: valid ? mask.residueBounds : null,
    boundaryUsed: true,
    analysisPerformed: true,
  );
}
