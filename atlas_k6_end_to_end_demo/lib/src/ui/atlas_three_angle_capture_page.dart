import 'dart:async';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';

import '../capture/atlas_three_angle_capture_controller.dart';
import '../capture/atlas_three_angle_capture_models.dart';
import '../integration/atlas_k6_result.dart';
import '../integration/atlas_three_angle_engine_controller.dart';
import '../integration/atlas_three_angle_engine_models.dart';

typedef AtlasThreeAngleCameraLauncher =
    Future<CameraCaptureResult?> Function(
      BuildContext context,
      AtlasCupCaptureRole role,
    );

extension AtlasCupCaptureRolePresentation on AtlasCupCaptureRole {
  String get title => switch (this) {
    AtlasCupCaptureRole.top => 'Üst açı',
    AtlasCupCaptureRole.handleRight => 'Yan açı · Kulp sağda',
    AtlasCupCaptureRole.handleLeft => 'Yan açı · Kulp solda',
  };

  String get shortInstruction => switch (this) {
    AtlasCupCaptureRole.top => 'İç yüzeyi yukarıdan ve ortada göster.',
    AtlasCupCaptureRole.handleRight =>
      'Kulp sağda, fincanın iç yüzeyi görünür kalsın.',
    AtlasCupCaptureRole.handleLeft =>
      'Kulp solda, fincanın iç yüzeyi görünür kalsın.',
  };

  String get captureTitle => '${index + 1} / 3 · $title';

  String get captureInstruction => switch (this) {
    AtlasCupCaptureRole.top =>
      'İç yüzeyi yukarıdan göster; fincanı ve telveyi sabit tut.',
    AtlasCupCaptureRole.handleRight =>
      'Kamerayı hareket ettir; kulp sağda ve iç yüzey görünür kalsın.',
    AtlasCupCaptureRole.handleLeft =>
      'Kamerayı hareket ettir; kulp solda ve iç yüzey görünür kalsın.',
  };

  String get actionLabel => switch (this) {
    AtlasCupCaptureRole.top => 'Üst açıyı çek',
    AtlasCupCaptureRole.handleRight => 'Kulp sağdayken çek',
    AtlasCupCaptureRole.handleLeft => 'Kulp soldayken çek',
  };
}

final class AtlasThreeAngleCaptureHomePage extends StatefulWidget {
  const AtlasThreeAngleCaptureHomePage({
    required this.processSurface,
    required this.cameraLauncher,
    required this.releaseCaptures,
    this.diagnosticModeLabel,
    this.setupErrorMessage,
    super.key,
  });

  final AtlasThreeAngleSurfaceOperation processSurface;
  final AtlasThreeAngleCameraLauncher cameraLauncher;
  final AtlasCaptureRelease releaseCaptures;
  final String? diagnosticModeLabel;
  final String? setupErrorMessage;

  @override
  State<AtlasThreeAngleCaptureHomePage> createState() =>
      _AtlasThreeAngleCaptureHomePageState();
}

class _AtlasThreeAngleCaptureHomePageState
    extends State<AtlasThreeAngleCaptureHomePage> {
  AtlasThreeAngleCupCaptureResult? _result;
  late final AtlasThreeAngleEngineController _engineController =
      AtlasThreeAngleEngineController(
        processSurface: widget.processSurface,
        setupError: widget.setupErrorMessage,
      )..addListener(_onEngineChanged);

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startCapture() async {
    if (_engineController.state.isBusy ||
        _engineController.state.setupError != null) {
      return;
    }
    final next = await Navigator.of(context)
        .push<AtlasThreeAngleCupCaptureResult>(
          MaterialPageRoute(
            builder: (_) => AtlasThreeAngleCapturePage(
              cameraLauncher: widget.cameraLauncher,
              releaseCaptures: widget.releaseCaptures,
            ),
          ),
        );
    if (next == null || !mounted) return;
    final previous = _result;
    _engineController.reset();
    if (previous != null) await widget.releaseCaptures(previous.captures);
    if (mounted) setState(() => _result = next);
  }

  @override
  void dispose() {
    _engineController.removeListener(_onEngineChanged);
    final result = _result;
    unawaited(
      _engineController.close().whenComplete(() async {
        if (result != null) await widget.releaseCaptures(result.captures);
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.diagnosticModeLabel case final label?)
              Container(
                key: const ValueKey('three-angle-diagnostic-banner'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Text(
                  'TEST ONLY · $label',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight > 52
                          ? constraints.maxHeight - 52
                          : 0,
                      maxWidth: 640,
                    ),
                    child: result == null
                        ? _CaptureIntroduction(
                            onStart: _startCapture,
                            setupError: _engineController.state.setupError,
                          )
                        : _CompletedCapture(
                            result: result,
                            engineState: _engineController.state,
                            onAnalyze: () => _engineController.analyze(result),
                            onRetry: _engineController.retry,
                            onStartAgain: _startCapture,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CaptureIntroduction extends StatelessWidget {
  const _CaptureIntroduction({required this.onStart, this.setupError});

  final VoidCallback onStart;
  final String? setupError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.coffee_outlined, color: colors.onPrimaryContainer),
        ),
        const SizedBox(height: 28),
        Text(
          'Fincanını üç açıdan çek',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          'Aynı fincanı ve aynı telveyi kullan. Fincanı oynatmadan kamerayı hareket ettir.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 30),
        for (final role in AtlasCupCaptureRole.values) _IntroStep(role: role),
        if (setupError case final message?) ...[
          const SizedBox(height: 18),
          _CaptureError(message: message),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('start-three-angle-capture'),
            onPressed: setupError == null ? onStart : null,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Çekime başla'),
          ),
        ),
      ],
    );
  }
}

final class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.role});

  final AtlasCupCaptureRole role;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${role.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  role.shortInstruction,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class AtlasThreeAngleCapturePage extends StatefulWidget {
  const AtlasThreeAngleCapturePage({
    required this.cameraLauncher,
    required this.releaseCaptures,
    super.key,
  });

  final AtlasThreeAngleCameraLauncher cameraLauncher;
  final AtlasCaptureRelease releaseCaptures;

  @override
  State<AtlasThreeAngleCapturePage> createState() =>
      _AtlasThreeAngleCapturePageState();
}

class _AtlasThreeAngleCapturePageState
    extends State<AtlasThreeAngleCapturePage> {
  late final AtlasThreeAngleCaptureController _controller =
      AtlasThreeAngleCaptureController(widget.releaseCaptures)
        ..addListener(_onChanged);

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _capture(AtlasCupCaptureRole role) async {
    await _controller.capture(role, () => widget.cameraLauncher(context, role));
  }

  void _finish() {
    final result = _controller.takeCompletedResult();
    Navigator.of(context).pop(result);
  }

  Future<void> _handleBack() async {
    if (_controller.state.isBusy) return;
    if (_controller.state.completedCount == 0) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çekimden çıkılsın mı?'),
        content: const Text(
          'Tamamlanan fotoğraflar bu oturumdan çıkınca silinir.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('keep-capturing'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Çekime dön'),
          ),
          FilledButton(
            key: const ValueKey('discard-captures'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çekimleri sil ve çık'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    await _controller.discard();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final next = state.nextIncompleteRole;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: state.isBusy ? null : _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Fincan çekimi'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  '${state.completedCount} / 3',
                  key: const ValueKey('capture-progress-label'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CaptureProgress(state: state),
                const SizedBox(height: 18),
                Text(
                  state.isComplete ? 'Üç açı hazır' : next!.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.isComplete
                      ? 'Fotoğrafları kontrol edebilir veya istediğin açıyı yeniden çekebilirsin.'
                      : next!.captureInstruction,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  _CaptureError(message: message),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.slots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _CaptureSlotCard(
                      slot: state.slots[index],
                      activeRole: state.activeRole,
                      onRetake: _capture,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('capture-primary-action'),
                    onPressed: state.isBusy
                        ? null
                        : state.isComplete
                        ? _finish
                        : () => _capture(next!),
                    icon: Icon(
                      state.isComplete
                          ? Icons.check_circle_outline
                          : Icons.photo_camera_outlined,
                    ),
                    label: Text(
                      state.isComplete
                          ? 'Çekimleri tamamla'
                          : next!.actionLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({required this.state});

  final AtlasThreeAngleCaptureState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < state.slots.length; index++) ...[
          Expanded(
            child: AnimatedContainer(
              key: ValueKey('capture-progress-$index'),
              duration: const Duration(milliseconds: 180),
              height: 6,
              decoration: BoxDecoration(
                color: index < state.completedCount
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (index != state.slots.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

final class _CaptureSlotCard extends StatelessWidget {
  const _CaptureSlotCard({
    required this.slot,
    required this.activeRole,
    required this.onRetake,
  });

  final AtlasCupCaptureSlot slot;
  final AtlasCupCaptureRole? activeRole;
  final ValueChanged<AtlasCupCaptureRole> onRetake;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = activeRole == slot.role;
    return Card(
      key: ValueKey('capture-slot-${slot.role.name}'),
      color: active ? colors.secondaryContainer.withValues(alpha: 0.45) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox.square(
                dimension: 78,
                child: slot.capture == null
                    ? ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Center(
                          child: active
                              ? const CircularProgressIndicator()
                              : Text(
                                  '${slot.role.index + 1}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                        ),
                      )
                    : Image.file(
                        File(
                          slot.capture!.croppedCupPath ??
                              slot.capture!.filePath,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.role.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    active
                        ? 'Kamera açık'
                        : slot.isComplete
                        ? 'Tamamlandı'
                        : 'Bekliyor',
                    style: TextStyle(
                      color: slot.isComplete ? colors.primary : colors.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (slot.isComplete)
              IconButton(
                key: ValueKey('retake-${slot.role.name}'),
                tooltip: '${slot.role.title} yeniden çek',
                onPressed: activeRole == null
                    ? () => onRetake(slot.role)
                    : null,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}

final class _CaptureError extends StatelessWidget {
  const _CaptureError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CompletedCapture extends StatelessWidget {
  const _CompletedCapture({
    required this.result,
    required this.engineState,
    required this.onAnalyze,
    required this.onRetry,
    required this.onStartAgain,
  });

  final AtlasThreeAngleCupCaptureResult result;
  final AtlasThreeAngleEngineState engineState;
  final Future<bool> Function() onAnalyze;
  final Future<bool> Function(AtlasCupCaptureRole role) onRetry;
  final VoidCallback onStartAgain;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 48, color: colors.primary),
        const SizedBox(height: 22),
        Text(
          'Üç açı hazır',
          key: const ValueKey('three-angle-complete'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Aynı fincanın üç yönlendirilmiş görüntüsü tamamlandı.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < result.slots.length; index++) ...[
              Expanded(child: _CompletedThumbnail(slot: result.slots[index])),
              if (index != result.slots.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 28),
        if (engineState.phase == AtlasThreeAngleEnginePhase.idle)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('analyze-three-angles'),
              onPressed: onAnalyze,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Üç açıyı analiz et'),
            ),
          ),
        if (engineState.phase == AtlasThreeAngleEnginePhase.processing)
          _AnalysisProgress(state: engineState),
        if (engineState.result case final engineResult?)
          _AnalysisResults(result: engineResult, onRetry: onRetry),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('start-new-three-angle-capture'),
            onPressed: engineState.isBusy ? null : onStartAgain,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeni çekim'),
          ),
        ),
      ],
    );
  }
}

final class _AnalysisProgress extends StatelessWidget {
  const _AnalysisProgress({required this.state});

  final AtlasThreeAngleEngineState state;

  @override
  Widget build(BuildContext context) {
    final role = state.activeRole!;
    final retrying =
        state.angleResults.length == AtlasCupCaptureRole.values.length;
    return Semantics(
      label: '${role.title} analiz ediliyor',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                '${role.title} analiz ediliyor',
                key: const ValueKey('three-angle-analysis-progress'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                retrying
                    ? 'Başarılı açı sonuçları korunuyor.'
                    : '${state.angleResults.length} / 3 açı tamamlandı',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AnalysisResults extends StatelessWidget {
  const _AnalysisResults({required this.result, required this.onRetry});

  final AtlasThreeAngleEngineResult result;
  final Future<bool> Function(AtlasCupCaptureRole role) onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('three-angle-analysis-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Açı sonuçları',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${result.matchedRecordCount} fiziksel eşleşme · '
          '${result.symbolCandidateCount} sembol adayı · '
          '${result.technicalErrorCount} teknik hata',
          key: const ValueKey('three-angle-technical-summary'),
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final angle in result.angleResults) ...[
          _AngleResultPanel(angle: angle, onRetry: onRetry),
          if (angle.role != AtlasCupCaptureRole.handleLeft)
            const SizedBox(height: 10),
        ],
      ],
    );
  }
}

final class _AngleResultPanel extends StatelessWidget {
  const _AngleResultPanel({required this.angle, required this.onRetry});

  final AtlasThreeAngleAngleResult angle;
  final Future<bool> Function(AtlasCupCaptureRole role) onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final surface = angle.surfaceResult;
    return DecoratedBox(
      key: ValueKey('angle-result-${angle.role.name}'),
      decoration: BoxDecoration(
        color: angle.isTechnicalError
            ? colors.errorContainer.withValues(alpha: 0.45)
            : colors.surfaceContainerLow,
        border: Border.all(
          color: angle.isTechnicalError ? colors.error : colors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    angle.role.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  angle.outcome.label,
                  key: ValueKey('angle-outcome-${angle.role.name}'),
                  style: TextStyle(
                    color: angle.isTechnicalError
                        ? colors.error
                        : colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (surface != null) ...[
              Text(
                '${surface.patternResult.candidates.length} fiziksel aday · '
                '${surface.matchedRecordCount} eşleşme · '
                '${surface.symbolCandidateCount} sembol adayı',
              ),
              for (final candidate in surface.symbolCandidates)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${candidate.symbolId} · revision '
                    '${candidate.symbolRevision} · candidate '
                    '${candidate.patternCandidateId}',
                  ),
                ),
            ] else ...[
              Text(angle.errorMessage!),
              const SizedBox(height: 8),
              TextButton.icon(
                key: ValueKey('retry-angle-${angle.role.name}'),
                onPressed: () => onRetry(angle.role),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar işle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on AtlasK6AggregateOutcome {
  String get label => switch (this) {
    AtlasK6AggregateOutcome.noMatch => 'Eşleşme yok',
    AtlasK6AggregateOutcome.insufficientSymbolEvidence =>
      'Sembol kanıtı yetersiz',
    AtlasK6AggregateOutcome.symbolCandidatesAvailable => 'Sembol adayı var',
    AtlasK6AggregateOutcome.technicalError => 'Teknik hata',
  };
}

final class _CompletedThumbnail extends StatelessWidget {
  const _CompletedThumbnail({required this.slot});

  final AtlasCupCaptureSlot slot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.file(
              File(slot.capture!.croppedCupPath ?? slot.capture!.filePath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slot.role.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
