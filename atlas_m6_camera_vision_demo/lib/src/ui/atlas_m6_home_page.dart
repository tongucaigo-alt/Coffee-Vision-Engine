import 'dart:async';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/material.dart';

import '../integration/atlas_m6_controller.dart';
import '../integration/atlas_m6_state.dart';

typedef AtlasCameraLauncher =
    Future<CoffeeCameraCaptureResult?> Function(BuildContext context);

class AtlasM6HomePage extends StatefulWidget {
  const AtlasM6HomePage({
    required this.controller,
    this.cameraLauncher = _defaultCameraLauncher,
    super.key,
  });

  final AtlasM6Controller controller;
  final AtlasCameraLauncher cameraLauncher;

  static Future<CoffeeCameraCaptureResult?> _defaultCameraLauncher(
    BuildContext context,
  ) {
    return showCoffeeCameraFlow(
      context,
      config: const CoffeeCameraConfig(requireSaucerCapture: true),
    );
  }

  @override
  State<AtlasM6HomePage> createState() => _AtlasM6HomePageState();
}

class _AtlasM6HomePageState extends State<AtlasM6HomePage> {
  AtlasM6Controller get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant AtlasM6HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onStateChanged);
    unawaited(oldWidget.controller.close());
    _controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    unawaited(_controller.close());
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startCapture() async {
    await _controller.startCapture(() => widget.cameraLauncher(context));
  }

  Future<void> _retry() async {
    await _controller.retry();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas M6 Camera + Vision'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusHeader(state: state),
            const SizedBox(height: 16),
            switch (state.phase) {
              AtlasM6Phase.idle => const _IdleContent(),
              AtlasM6Phase.capturing => const _ProgressContent(
                key: ValueKey('capturing-state'),
                icon: Icons.photo_camera_outlined,
                title: 'Kamera akisi acik',
                detail: '1/2 fincan ve 2/2 tabak cekimini tamamlayin.',
              ),
              AtlasM6Phase.analyzingCup => const _ProgressContent(
                key: ValueKey('cup-analysis-state'),
                icon: Icons.coffee_outlined,
                title: 'Fincan analiz ediliyor',
                detail: 'Coffee Vision fincan goruntusunu isliyor.',
              ),
              AtlasM6Phase.analyzingSaucer => _SaucerProgressContent(
                state: state,
              ),
              AtlasM6Phase.success => _SuccessContent(state: state),
              AtlasM6Phase.failure => _FailureContent(state: state),
            },
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('capture-button'),
              onPressed: state.isBusy ? null : _startCapture,
              icon: const Icon(Icons.photo_camera),
              label: Text(
                state.captureResult == null
                    ? 'Fincan ve tabak cek'
                    : 'Yeni cekim yap',
              ),
            ),
            if (state.canRetry) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('retry-button'),
                onPressed: state.isBusy ? null : _retry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  state.failureStage == AtlasM6FailureStage.saucerAnalysis
                      ? 'Tabak analizini yeniden dene'
                      : 'Analizi yeniden dene',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.state});

  final AtlasM6State state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state.phase) {
      AtlasM6Phase.idle => ('Hazir', const Color(0xFF3F4A46)),
      AtlasM6Phase.capturing => ('Cekim', const Color(0xFFB05B11)),
      AtlasM6Phase.analyzingCup => ('Fincan analizi', const Color(0xFF2367A6)),
      AtlasM6Phase.analyzingSaucer => (
        'Tabak analizi',
        const Color(0xFF2367A6),
      ),
      AtlasM6Phase.success => ('Basarili', const Color(0xFF147D64)),
      AtlasM6Phase.failure => ('Basarisiz', const Color(0xFFB3261E)),
    };
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _IdleContent extends StatelessWidget {
  const _IdleContent();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('idle-state'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Iki asamali dogrulama',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Once fincan, sonra tabak cekilir. Goruntuler mevcut '
              'Coffee Vision pipeline ile sirali olarak analiz edilir.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.icon,
    required this.title,
    required this.detail,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(detail, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SaucerProgressContent extends StatelessWidget {
  const _SaucerProgressContent({required this.state});

  final AtlasM6State state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressContent(
          key: const ValueKey('saucer-analysis-state'),
          icon: Icons.circle_outlined,
          title: 'Tabak analiz ediliyor',
          detail: 'Fincan analizi tamamlandi. Tabak sonucu bekleniyor.',
        ),
        const SizedBox(height: 12),
        _DurationRow(
          label: 'Fincan analiz suresi',
          duration: state.cupAnalysisDuration,
        ),
      ],
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.state});

  final AtlasM6State state;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    return Column(
      key: const ValueKey('success-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Iki analiz tamamlandi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _VisionResultCard(
          title: '1/2 Fincan',
          imagePath:
              result.captureResult.cup.croppedCupPath ??
              result.captureResult.cup.filePath,
          visionResult: result.cupVisionResult,
          duration: result.cupAnalysisDuration,
        ),
        const SizedBox(height: 12),
        _VisionResultCard(
          title: '2/2 Tabak',
          imagePath:
              result.captureResult.saucer!.croppedSaucerPath ??
              result.captureResult.saucer!.filePath,
          visionResult: result.saucerVisionResult,
          duration: result.saucerAnalysisDuration,
        ),
      ],
    );
  }
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.state});

  final AtlasM6State state;

  @override
  Widget build(BuildContext context) {
    final isSaucerFailure =
        state.failureStage == AtlasM6FailureStage.saucerAnalysis;
    return Column(
      key: const ValueKey('failure-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(switch (state.failureStage) {
                        AtlasM6FailureStage.cupAnalysis => 'Fincan hatasi',
                        AtlasM6FailureStage.saucerAnalysis => 'Tabak hatasi',
                        _ => 'Cekim hatasi',
                      }, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(state.errorMessage ?? 'Islem tamamlanamadi.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isSaucerFailure && state.cupVisionResult != null) ...[
          const SizedBox(height: 12),
          _VisionResultCard(
            key: const ValueKey('preserved-cup-result'),
            title: 'Korunan fincan sonucu',
            imagePath:
                state.captureResult!.cup.croppedCupPath ??
                state.captureResult!.cup.filePath,
            visionResult: state.cupVisionResult!,
            duration: state.cupAnalysisDuration!,
          ),
          const SizedBox(height: 8),
          _DurationRow(
            label: 'Basarisiz tabak denemesi',
            duration: state.saucerAnalysisDuration,
          ),
        ],
      ],
    );
  }
}

class _VisionResultCard extends StatelessWidget {
  const _VisionResultCard({
    required this.title,
    required this.imagePath,
    required this.visionResult,
    required this.duration,
    super.key,
  });

  final String title;
  final String imagePath;
  final VisionPipelineResult visionResult;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final source = visionResult.workingImage.sourceMetadata;
    final working = visionResult.workingImage.workingMetadata;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Color(0xFFE7ECEA),
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _MetricRow(label: 'Yuzey', value: visionResult.surfaceType.name),
            _MetricRow(
              label: 'Kaynak',
              value: '${source.width} x ${source.height}',
            ),
            _MetricRow(
              label: 'Working image',
              value: '${working.width} x ${working.height}',
            ),
            _MetricRow(
              label: 'Residue orani',
              value: visionResult.residueMask.residueRatio.toStringAsFixed(4),
            ),
            _MetricRow(
              label: 'Component',
              value: '${visionResult.componentResult.componentCount}',
            ),
            _MetricRow(
              label: 'Secili edge',
              value:
                  '${visionResult.edgeSelectionResult.selectedRelations.length}',
            ),
            _MetricRow(
              label: 'Structure',
              value: '${visionResult.connectedStructureResult.structureCount}',
            ),
            _DurationRow(label: 'Analiz suresi', duration: duration),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.label, required this.duration});

  final String label;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final milliseconds = duration?.inMicroseconds ?? 0;
    final value = '${(milliseconds / 1000).toStringAsFixed(1)} ms';
    return _MetricRow(label: label, value: value);
  }
}
