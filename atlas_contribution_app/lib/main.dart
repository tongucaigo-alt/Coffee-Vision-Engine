import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/captcha_page.dart';
import 'src/client_config.dart';
import 'src/contribution_home.dart';
import 'src/local_store.dart';
import 'src/secure_session.dart';
import 'src/service.dart';
import 'src/theme.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const captchaUrl = String.fromEnvironment('CAPTCHA_URL');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Widget home;
  try {
    if (!supabaseUrl.startsWith('https://') ||
        !isPublicClientKey(supabaseAnonKey) ||
        !captchaUrl.startsWith('https://')) {
      home = const ConfigurationPage();
    } else {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
        ),
      );
      final store = DraftStore(
        Directory(
          '${(await getApplicationSupportDirectory()).path}/contributions',
        ),
      );
      await store.initialize();
      home = InvitePage(
        store: store,
        service: ContributionService(Supabase.instance.client),
      );
    }
  } catch (_) {
    home = const ConfigurationPage();
  }
  runApp(
    MaterialApp(
      title: 'Atlas Katkı',
      debugShowCheckedModeBanner: false,
      theme: contributionTheme(),
      home: home,
    ),
  );
}

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atlas Katkı')),
    body: const PageBody(
      children: [
        Icon(LucideIcons.coffee, size: 64),
        SizedBox(height: 24),
        Text(
          'Bu kurulum henüz hazır değil.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'Güncel uygulama için seni davet eden kişiye ulaş. Fotoğraf gönderilmedi.',
        ),
      ],
    ),
  );
}

class InvitePage extends StatefulWidget {
  const InvitePage({required this.store, required this.service, super.key});
  final DraftStore store;
  final ContributionService service;
  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  static const _storage = FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    _resume();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _resume() async {
    final id = widget.service.client.auth.currentUser?.id;
    if (id != null &&
        await _storage.read(key: 'enrolled-$id') == 'yes' &&
        mounted) {
      _enter();
    }
  }

  void _enter() => Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          ContributionHome(store: widget.store, service: widget.service),
    ),
  );
  Future<void> _join() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.service.client.auth.currentUser == null) {
        final token = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => CaptchaPage(url: Uri.parse(captchaUrl)),
          ),
        );
        if (token == null) return;
        await widget.service.client.auth.signInAnonymously(captchaToken: token);
      }
      await widget.service.enroll(
        _code.text.trim().toUpperCase().replaceAll(' ', ''),
      );
      await _storage.write(
        key: 'enrolled-${widget.service.client.auth.currentUser!.id}',
        value: 'yes',
      );
      if (mounted) _enter();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ContributionFailure
              ? e.message
              : 'Giriş tamamlanamadı. İnternetini ve davet kodunu kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atlas Katkı')),
    body: PageBody(
      children: [
        const SizedBox(height: 24),
        const Icon(LucideIcons.coffee, size: 72, color: Color(0xff186354)),
        const SizedBox(height: 24),
        Text('Hoş geldin', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('Sana verilen davet koduyla başlayabilirsin.'),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 16,
          decoration: const InputDecoration(labelText: 'Davet kodu'),
          onSubmitted: (_) => _join(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _join,
          child: Text(_busy ? 'Giriş yapılıyor…' : 'Başla'),
        ),
      ],
    ),
  );
}
