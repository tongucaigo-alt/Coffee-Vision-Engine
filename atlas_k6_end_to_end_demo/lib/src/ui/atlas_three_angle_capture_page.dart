import 'dart:async';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter/material.dart';

import '../capture/atlas_three_angle_capture_controller.dart';
import '../capture/atlas_three_angle_capture_models.dart';

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
    required this.cameraLauncher,
    required this.releaseCaptures,
    super.key,
  });

  final AtlasThreeAngleCameraLauncher cameraLauncher;
  final AtlasCaptureRelease releaseCaptures;

  @override
  State<AtlasThreeAngleCaptureHomePage> createState() =>
      _AtlasThreeAngleCaptureHomePageState();
}

class _AtlasThreeAngleCaptureHomePageState
    extends State<AtlasThreeAngleCaptureHomePage> {
  AtlasThreeAngleCupCaptureResult? _result;

  Future<void> _startCapture() async {
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
    if (previous != null) await widget.releaseCaptures(previous.captures);
    if (mounted) setState(() => _result = next);
  }

  @override
  void dispose() {
    final result = _result;
    if (result != null) unawaited(widget.releaseCaptures(result.captures));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      body: SafeArea(
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
                  ? _CaptureIntroduction(onStart: _startCapture)
                  : _CompletedCapture(
                      result: result,
                      onStartAgain: _startCapture,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _CaptureIntroduction extends StatelessWidget {
  const _CaptureIntroduction({required this.onStart});

  final VoidCallback onStart;

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
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('start-three-angle-capture'),
            onPressed: onStart,
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
  const _CompletedCapture({required this.result, required this.onStartAgain});

  final AtlasThreeAngleCupCaptureResult result;
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
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('start-new-three-angle-capture'),
            onPressed: onStartAgain,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeni çekim'),
          ),
        ),
      ],
    );
  }
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
