import 'package:flutter/material.dart';

import 'src/capture/atlas_three_angle_capture_app.dart';
import 'src/diagnostic/atlas_three_angle_diagnostic_fixture.dart';

const _scenarioName = String.fromEnvironment(
  'ATLAS_THREE_ANGLE_DIAGNOSTIC_SCENARIO',
  defaultValue: 'disabled',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final scenario = switch (_scenarioName) {
    'mixed-outcomes' => AtlasThreeAngleDiagnosticScenario.mixedOutcomes,
    'technical-retry' => AtlasThreeAngleDiagnosticScenario.technicalRetry,
    _ => null,
  };
  if (scenario == null) {
    runApp(const _DiagnosticDisabledApp());
    return;
  }
  final fixture = AtlasThreeAngleDiagnosticFixture(scenario);
  runApp(
    AtlasThreeAngleCaptureApp(
      processSurface: fixture.process,
      diagnosticModeLabel: fixture.label,
    ),
  );
}

final class _DiagnosticDisabledApp extends StatelessWidget {
  const _DiagnosticDisabledApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'TEST ONLY diagnostic kapalı. '
              'Geçerli bir ATLAS_THREE_ANGLE_DIAGNOSTIC_SCENARIO seçin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
