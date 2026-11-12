import '../umay_guide_catalog.dart';
import '../umay_guide_scope.dart';
import 'package:flutter/material.dart';
import 'ai_contract.dart';
import 'ai_runtime.dart';

/// Closed-test access only; no personal provider/model controls.
class PlayAccessPage extends StatefulWidget {
  const PlayAccessPage({required this.runtime, super.key});
  final AiRuntime runtime;
  @override
  State<PlayAccessPage> createState() => _PlayAccessPageState();
}

class _PlayAccessPageState extends State<PlayAccessPage> {
  final _address = TextEditingController();
  final _code = TextEditingController();
  bool _busy = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profiles = await widget.runtime.store.profiles();
      if (!mounted) return;
      final current = profiles
          .where((p) => p.id == 'atlas-closed-test')
          .firstOrNull;
      if (current != null) _address.text = current.url;
    } catch (_) {
      _message = 'Bağlantı bilgisi okunamadı. Yeniden deneyebilirsin.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final profile = AiProfile(
        id: 'atlas-closed-test',
        name: 'Atlas',
        url: _address.text.trim().replaceFirst(RegExp(r'/$'), ''),
        model: 'atlas',
        provider: AiProvider.atlas,
      );
      validateAiUrl(profile.url, allowLan: false);
      if (!RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(_code.text.trim())) {
        throw const AiFailure('Test yöneticisinin verdiği erişim kodunu gir.');
      }
      await widget.runtime.saveProfile(profile, _code.text.trim());
      _code.clear();
      if (mounted) {
        setState(
          () =>
              _message = 'Test bağlantısı kaydedildi. Falını oluşturabilirsin.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is AiFailure
              ? e.message
              : e is FormatException
              ? e.message
              : 'Bağlantı kaydedilemedi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      final count = await widget.runtime.sendPendingReports();
      if (mounted) {
        setState(
          () => _message = count == 0
              ? 'Bekleyen bildirim yok.'
              : '$count bildirim telefonda bekliyor. Test saatlerinde yeniden deneyebilirsin.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Bildirimler gönderilemedi; kayıtların korunuyor.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UmayGuideOnce(
    id: 'connection',
    steps: umayAccessSteps,
    ready: !_busy,
    child: _buildAccess(context),
  );

  Widget _buildAccess(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atlas Test Bağlantısı')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Fal hizmeti test yöneticisinin bildirdiği saatlerde açıktır. Hizmet kapalıyken fotoğrafların ve kayıtlı falların telefonda kalır.',
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('access-address'),
          controller: _address,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          onChanged: (_) => _code.clear(),
          decoration: const InputDecoration(labelText: 'HTTPS test adresi'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('access-code'),
          controller: _code,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Sana özel erişim kodu'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('access-save'),
          onPressed: _busy ? null : _save,
          child: const Text('Bağlantıyı Kaydet'),
        ),
        TextButton(
          onPressed: _busy ? null : _retry,
          child: const Text('Bekleyen bildirimleri gönder'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_message!, semanticsLabel: _message),
          ),
        const Divider(),
        const Text(
          'Atlas eğlence amaçlı AI yorumları üretir; kesin öngörü veya uzman tavsiyesi sunmaz. Fotoğraflar telefonda işlenir. Fal hizmetine yalnız semboller ve fiziksel dağılımın metinsel özeti gönderilir.',
        ),
      ],
    ),
  );
}
