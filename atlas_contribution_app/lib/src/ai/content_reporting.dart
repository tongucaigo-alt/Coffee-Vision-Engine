import 'package:flutter/material.dart';
import 'ai_contract.dart';
import 'ai_runtime.dart';
import 'play_access_page.dart';

/// The same in-app, explicitly confirmed report flow covers coffee, direct
/// provider answers, old saved answers and Tarot. No photos/profile are sent.
class ContentReportButton extends StatefulWidget {
  const ContentReportButton({
    required this.runtime,
    required this.sessionId,
    required this.contentId,
    required this.text,
    this.enabled = true,
    super.key,
  });
  final AiRuntime? runtime;
  final String sessionId, contentId, text;
  final bool enabled;
  @override
  State<ContentReportButton> createState() => _ContentReportButtonState();
}

class _ContentReportButtonState extends State<ContentReportButton> {
  bool _busy = false;
  String? _message;
  Future<void> _report() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final runtime = widget.runtime;
      if (runtime == null) {
        throw const AiFailure(
          'Bildirim deposu açılamadı. Kayıtların korunuyor; uygulamayı yeniden açıp deneyebilirsin.',
        );
      }
      var target = (await runtime.store.profiles())
          .where((p) => p.provider == AiProvider.atlas)
          .firstOrNull;
      if (!mounted) return;
      if (target == null) {
        final setup = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bildirim bağlantısı gerekli'),
            content: const Text(
              'Yorum sağlayıcına bildirim gönderilmez. Atlas bildirim hizmetinin adresi ve erişim kodu gerekir; üretim anahtarın kullanılmaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Bağlantıyı Ayarla'),
              ),
            ],
          ),
        );
        if (setup != true || !mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PlayAccessPage(runtime: runtime),
          ),
        );
        target = (await runtime.store.profiles())
            .where((p) => p.provider == AiProvider.atlas)
            .firstOrNull;
        if (!mounted) return;
        if (target == null) {
          throw const AiFailure(
            'Bildirim gönderilmedi. Atlas bağlantısını ayarlayıp yeniden deneyebilirsin.',
          );
        }
      }
      var reason = 'misleading';
      final recipient = Uri.parse(target.url).host;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('Bu yorumu bildir'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Yalnız aşağıdaki yorum ve seçtiğin neden Atlas bildirim hizmetine ($recipient) gönderilecek. Fotoğraf, yaş, burç ve diğer falların eklenmez.',
                  ),
                  DropdownButton<String>(
                    value: reason,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'misleading',
                        child: Text('Yanıltıcı yorum'),
                      ),
                      DropdownMenuItem(
                        value: 'harmful',
                        child: Text('Rahatsız edici içerik'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Diğer')),
                    ],
                    onChanged: (value) => update(() => reason = value!),
                  ),
                  SelectableText(widget.text),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Bildir'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      final delivered = await runtime.submitContentReport(
        target: target,
        sessionId: widget.sessionId,
        contentId: widget.contentId,
        text: widget.text,
        reason: reason,
      );
      if (mounted) {
        setState(
          () => _message = delivered
              ? 'Bildirim iletildi.'
              : 'Bildirim telefonda bekliyor. Bağlantını kontrol edip yeniden gönderebilirsin.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is AiFailure
              ? error.message
              : 'Bildirim kaydedilemedi veya gönderilemedi. Yeniden deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: _busy || !widget.enabled ? null : _report,
        icon: const Icon(Icons.flag_outlined),
        label: Text(_busy ? 'Bildirim işleniyor…' : 'Bu yorumu bildir'),
      ),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
    ],
  );
}
