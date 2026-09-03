import 'package:flutter/material.dart';

import '../analysis/debug_analysis_settings.dart';

Future<void> showDebugAnalysisPanel({
  required BuildContext context,
  required DebugAnalysisSettings initialValue,
  required ValueChanged<DebugAnalysisSettings> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF171B20),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _DebugAnalysisPanel(initialValue: initialValue, onChanged: onChanged),
  );
}

class _DebugAnalysisPanel extends StatefulWidget {
  const _DebugAnalysisPanel({
    required this.initialValue,
    required this.onChanged,
  });

  final DebugAnalysisSettings initialValue;
  final ValueChanged<DebugAnalysisSettings> onChanged;

  @override
  State<_DebugAnalysisPanel> createState() => _DebugAnalysisPanelState();
}

class _DebugAnalysisPanelState extends State<_DebugAnalysisPanel> {
  late DebugAnalysisSettings _value = widget.initialValue;

  void _update(DebugAnalysisSettings next) {
    setState(() => _value = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Analiz testi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _toggle(
              'Test analizini kullan',
              _value.enabled,
              (value) => _value.copyWith(enabled: value),
            ),
            const Divider(),
            _toggle(
              'Fincan algılandı',
              _value.cupDetected,
              (value) => _value.copyWith(cupDetected: value),
            ),
            _toggle(
              'Merkezde',
              _value.centered,
              (value) => _value.copyWith(centered: value),
            ),
            _toggle(
              'Doğru boyutta',
              _value.rightSize,
              (value) => _value.copyWith(rightSize: value),
            ),
            _toggle(
              'Işık yeterli',
              _value.lightEnough,
              (value) => _value.copyWith(lightEnough: value),
            ),
            _toggle(
              'Net',
              _value.sharp,
              (value) => _value.copyWith(sharp: value),
            ),
            _toggle(
              'Telefon sabit',
              _value.stable,
              (value) => _value.copyWith(stable: value),
            ),
            _toggle(
              'Açı uygun',
              _value.angleOk,
              (value) => _value.copyWith(angleOk: value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(
    String label,
    bool value,
    DebugAnalysisSettings Function(bool value) update,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (next) => _update(update(next)),
    );
  }
}
