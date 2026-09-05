import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_models.dart';
import 'package:atlas_k6_end_to_end_demo/src/diagnostic/atlas_three_angle_diagnostic_fixture.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_result.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_surface_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mixed diagnostic preserves three distinct angle outcomes', () async {
    final fixture = AtlasThreeAngleDiagnosticFixture(
      AtlasThreeAngleDiagnosticScenario.mixedOutcomes,
    );

    final top = await fixture.process(
      role: AtlasCupCaptureRole.top,
      path: 'ignored-top.jpg',
    );
    final right = await fixture.process(
      role: AtlasCupCaptureRole.handleRight,
      path: 'ignored-right.jpg',
    );
    final left = await fixture.process(
      role: AtlasCupCaptureRole.handleLeft,
      path: 'ignored-left.jpg',
    );

    expect(top.outcome, AtlasK6AggregateOutcome.noMatch);
    expect(right.outcome, AtlasK6AggregateOutcome.insufficientSymbolEvidence);
    expect(left.outcome, AtlasK6AggregateOutcome.symbolCandidatesAvailable);
    expect(left.symbolCandidates.single.symbolId, 'test-diagnostic-symbol-001');
  });

  test('technical diagnostic fails once and then succeeds on retry', () async {
    final fixture = AtlasThreeAngleDiagnosticFixture(
      AtlasThreeAngleDiagnosticScenario.technicalRetry,
    );

    await expectLater(
      fixture.process(
        role: AtlasCupCaptureRole.handleRight,
        path: 'ignored-right.jpg',
      ),
      throwsA(
        isA<AtlasSurfaceProcessingException>().having(
          (error) => error.stage,
          'stage',
          AtlasSurfaceProcessingStage.pattern,
        ),
      ),
    );
    final retried = await fixture.process(
      role: AtlasCupCaptureRole.handleRight,
      path: 'ignored-right.jpg',
    );

    expect(retried.outcome, AtlasK6AggregateOutcome.symbolCandidatesAvailable);
    expect(retried.symbolCandidates.single.symbolId, startsWith('test-'));
  });
}
