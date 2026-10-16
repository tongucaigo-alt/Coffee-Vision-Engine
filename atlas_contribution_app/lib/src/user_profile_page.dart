import 'package:flutter/material.dart';

import 'atlas_design.dart';
import 'theme.dart';
import 'user_profile_store.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({required this.store, super.key});
  final UserProfileStore store;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _name = TextEditingController();
  ZodiacSign? _zodiac;
  bool _useZodiacInReading = false;
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.store.read();
      if (!mounted) return;
      _name.text = profile.addressName;
      _zodiac = profile.zodiac;
      _useZodiacInReading = profile.useZodiacInReading;
    } catch (_) {
      if (mounted) {
        _error = 'Bilgilerin okunamadı. Yeniden deneyebilir veya silebilirsin.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_loading || _busy || _error != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.store.save(
        UserProfile(
          addressName: _name.text,
          zodiac: _zodiac,
          useZodiacInReading: _useZodiacInReading,
        ),
      );
      if (mounted) {
        _name.text = _name.text.trim();
        showNotice(context, 'Bilgilerin bu cihaza kaydedildi.');
      }
    } catch (_) {
      if (mounted) showNotice(context, 'Kaydedilemedi. Tekrar deneyebilirsin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_loading || _busy) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilgilerin silinsin mi?'),
        content: const Text('Hitap adın ve burcun bu cihazdan silinir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      if (confirmed != true) return;
      await widget.store.delete();
      if (!mounted) return;
      setState(() {
        _name.clear();
        _zodiac = null;
        _useZodiacInReading = false;
        _error = null;
      });
      showNotice(context, 'Bilgilerin silindi.');
    } catch (_) {
      if (mounted) showNotice(context, 'Silinemedi. Tekrar deneyebilirsin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Bilgilerim')),
      body: PageBody(
        children: [
          const Text(
            'Sana nasıl seslenelim?',
            style: TextStyle(fontFamily: 'Literata', fontSize: 24),
          ),
          const SizedBox(height: 12),
          const Text(
            'İstersen doldur, istersen boş bırak. Falına her zamanki gibi devam edebilirsin.',
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_error != null) ...[
              AtlasNotice(_error!),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Yeniden dene'),
              ),
            ],
            TextField(
              key: const ValueKey('profile-name'),
              controller: _name,
              enabled: !_busy && _error == null,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Hitap adı (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                enabled: !_busy && _error == null,
                title: const Text('Burç (isteğe bağlı)'),
                subtitle: Text(
                  _zodiac?.label ?? 'Bilmiyorum / Belirtmek istemiyorum',
                ),
                trailing: const Icon(Icons.expand_more),
                onTap: _chooseZodiac,
              ),
            ),
            const SizedBox(height: 24),
            const AtlasNotice(
              'Hitap adın bu cihazda kalır. Burcunu seçip kaydedersen yeni fal isteğinde yorum hizmetine gönderilir. Eski seçimin kendiliğinden kullanılmaz. Bilmiyorum / Belirtmek istemiyorum seçimi bu kullanımı kapatır.',
            ),
            const SizedBox(height: 24),
            AtlasPrimaryButton(
              onPressed: _busy || _error != null ? null : _save,
              child: Text(_busy ? 'İşleniyor…' : 'Kaydet'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Bilgilerimi sil'),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _chooseZodiac() async {
    if (_busy || _error != null) return;
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .75,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Burcun',
                style: TextStyle(fontFamily: 'Literata', fontSize: 22),
              ),
            ),
            for (final sign in <ZodiacSign?>[null, ...ZodiacSign.values])
              ListTile(
                title: Text(
                  sign?.label ?? 'Bilmiyorum / Belirtmek istemiyorum',
                ),
                trailing: sign == _zodiac
                    ? const Icon(Icons.check, color: atlasSageInk)
                    : null,
                onTap: () =>
                    Navigator.pop(context, sign?.name ?? 'unspecified'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() {
      _zodiac = ZodiacSign.values
          .where((sign) => sign.name == choice)
          .firstOrNull;
      _useZodiacInReading = _zodiac != null;
    });
  }
}
