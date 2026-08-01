import 'dart:async';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:flutter/material.dart';

import '../integration/atlas_k6_controller.dart';
import '../integration/atlas_k6_result.dart';
import '../integration/atlas_k6_state.dart';

typedef AtlasCameraLauncher =
    Future<CoffeeCameraCaptureResult?> Function(BuildContext context);

class AtlasK6HomePage extends StatefulWidget {
  const AtlasK6HomePage({
    required this.controller,
    this.cameraLauncher = _defaultCameraLauncher,
    super.key,
  });

  final AtlasK6Controller controller;
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
  State<AtlasK6HomePage> createState() => _AtlasK6HomePageState();
}

class _AtlasK6HomePageState extends State<AtlasK6HomePage> {
  AtlasK6Controller get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant AtlasK6HomePage oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Atlas K6 End-to-End')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _StatusHeader(state: state),
            const SizedBox(height: 12),
            _DatasetStrip(controller: _controller),
            const SizedBox(height: 16),
            switch (state.phase) {
              AtlasK6Phase.idle => const _IdleContent(),
              AtlasK6Phase.capturing => const _ProgressContent(
                key: ValueKey('capturing-state'),
                icon: Icons.photo_camera_outlined,
                title: 'Kamera akisi acik',
                detail: 'Fincan ve tabak cekimini tamamlayin.',
              ),
              AtlasK6Phase.processingCup => const _ProgressContent(
                key: ValueKey('cup-processing-state'),
                icon: Icons.coffee_outlined,
                title: 'Fincan isleniyor',
                detail: 'Vision, Pattern ve Knowledge sirali calisiyor.',
              ),
              AtlasK6Phase.processingSaucer => _SaucerProgress(state: state),
              AtlasK6Phase.success => _SuccessContent(state: state),
              AtlasK6Phase.failure => _FailureContent(state: state),
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
                onPressed: state.isBusy ? null : _controller.retry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  state.failureStage == AtlasK6FailureStage.saucerProcessing
                      ? 'Tabak islemesini yeniden dene'
                      : 'Islemeyi yeniden dene',
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

  final AtlasK6State state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state.phase) {
      AtlasK6Phase.idle => ('Hazir', const Color(0xFF45514E)),
      AtlasK6Phase.capturing => ('Cekim', const Color(0xFF9A5412)),
      AtlasK6Phase.processingCup => ('Fincan', const Color(0xFF1766A3)),
      AtlasK6Phase.processingSaucer => ('Tabak', const Color(0xFF1766A3)),
      AtlasK6Phase.success => ('Tamamlandi', const Color(0xFF0B6E69)),
      AtlasK6Phase.failure => ('Basarisiz', const Color(0xFFB3261E)),
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

class _DatasetStrip extends StatelessWidget {
  const _DatasetStrip({required this.controller});

  final AtlasK6Controller controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EFEC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${controller.dataset.datasetVersion} research baseline',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text('${controller.dataset.activeRecords.length} kayit'),
        ],
      ),
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
              'Fiziksel zincir dogrulamasi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cekimlerden VisionFeatureSet, PatternCandidate ve fiziksel '
              'Knowledge eslesmeleri sirali olarak uretilir.',
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

class _SaucerProgress extends StatelessWidget {
  const _SaucerProgress({required this.state});

  final AtlasK6State state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ProgressContent(
          key: ValueKey('saucer-processing-state'),
          icon: Icons.circle_outlined,
          title: 'Tabak isleniyor',
          detail: 'Fincan zinciri tamamlandi. Tabak sonucu bekleniyor.',
        ),
        const SizedBox(height: 12),
        _MetricRow(
          label: 'Fincan adaylari',
          value: '${state.cupResult!.patternResult.candidates.length}',
        ),
        _DurationRow(
          label: 'Fincan uc uca sure',
          duration: state.cupResult!.processingDuration,
        ),
      ],
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.state});

  final AtlasK6State state;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    return Column(
      key: const ValueKey('success-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fiziksel zincir tamamlandi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text('Dataset: ${result.datasetVersion}'),
        const SizedBox(height: 18),
        _SurfaceResultSection(
          title: '1/2 Fincan',
          imagePath:
              result.captureResult.cup.croppedCupPath ??
              result.captureResult.cup.filePath,
          result: result.cupResult,
        ),
        const Divider(height: 32),
        _SurfaceResultSection(
          title: '2/2 Tabak',
          imagePath:
              result.captureResult.saucer!.croppedSaucerPath ??
              result.captureResult.saucer!.filePath,
          result: result.saucerResult,
        ),
      ],
    );
  }
}

class _SurfaceResultSection extends StatelessWidget {
  const _SurfaceResultSection({
    required this.title,
    required this.imagePath,
    required this.result,
  });

  final String title;
  final String imagePath;
  final AtlasK6SurfaceResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: Color(0xFFE4E9E7),
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _MetricRow(
          label: 'Pattern adayi',
          value: '${result.patternResult.candidates.length}',
        ),
        _MetricRow(
          label: 'Eslesen kayit',
          value: '${result.matchedRecordCount}',
        ),
        _DurationRow(
          label: 'Uc uca isleme',
          duration: result.processingDuration,
        ),
        const SizedBox(height: 10),
        if (result.candidateResults.isEmpty)
          const Text('Bu yuzey icin Pattern adayi uretilmedi.')
        else
          for (final candidate in result.candidateResults) ...[
            _CandidateCard(result: candidate),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.result});

  final AtlasK6CandidateResult result;

  @override
  Widget build(BuildContext context) {
    final topology = result.candidate.topology;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Candidate ${result.candidate.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  result.matchedRecordCount > 0
                      ? Icons.check_circle
                      : Icons.cancel_outlined,
                  color: result.matchedRecordCount > 0
                      ? const Color(0xFF0B6E69)
                      : const Color(0xFF8B9693),
                ),
              ],
            ),
            if (topology != null) ...[
              const SizedBox(height: 6),
              _MetricRow(label: 'Node', value: '${topology.nodeCount}'),
              _MetricRow(
                label: 'Directed edge',
                value: '${topology.directedEdgeCount}',
              ),
            ],
            const Divider(height: 18),
            for (final match in result.matches) _MatchBlock(match: match),
          ],
        ),
      ),
    );
  }
}

class _MatchBlock extends StatelessWidget {
  const _MatchBlock({required this.match});

  final KnowledgeMatchResult match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                match.recordId,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              match.matched ? 'MATCH' : 'NO MATCH',
              style: TextStyle(
                color: match.matched
                    ? const Color(0xFF0B6E69)
                    : const Color(0xFF7A3430),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final constraint in match.constraintResults)
          _MetricRow(
            label: constraint.constraint.key.name,
            value: '${_observedValue(constraint)} / ${constraint.outcome.name}',
          ),
      ],
    );
  }

  static String _observedValue(ConstraintMatchResult result) {
    final doubleValue = result.observedDouble;
    if (doubleValue != null) return doubleValue.toStringAsFixed(6);
    final integerValue = result.observedInteger;
    if (integerValue != null) return '$integerValue';
    final booleanValue = result.observedBoolean;
    if (booleanValue != null) return '$booleanValue';
    return result.unavailableReason?.name ?? 'unavailable';
  }
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.state});

  final AtlasK6State state;

  @override
  Widget build(BuildContext context) {
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
                        AtlasK6FailureStage.cupProcessing => 'Fincan hatasi',
                        AtlasK6FailureStage.saucerProcessing => 'Tabak hatasi',
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
        if (state.cupResult != null) ...[
          const SizedBox(height: 12),
          _MetricRow(
            label: 'Korunan fincan adayi',
            value: '${state.cupResult!.patternResult.candidates.length}',
          ),
          _MetricRow(
            label: 'Korunan fincan eslesmesi',
            value: '${state.cupResult!.matchedRecordCount}',
          ),
        ],
      ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.label, required this.duration});

  final String label;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final milliseconds = duration.inMicroseconds / 1000;
    return _MetricRow(
      label: label,
      value: '${milliseconds.toStringAsFixed(1)} ms',
    );
  }
}
