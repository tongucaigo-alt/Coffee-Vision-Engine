import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/admin_workspace.dart';
import 'src/client_config.dart';
import 'src/service.dart';
import 'src/theme.dart';

@JS('atlasCaptcha')
external JSPromise<JSString> _captcha();
@JS('atlasDownload')
external void _download(JSString value, JSString name);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (!url.startsWith('https://') || !isPublicClientKey(key)) {
    runApp(
      MaterialApp(
        theme: contributionTheme(),
        home: const Scaffold(
          body: Center(child: Text('Yönetim kurulumu henüz tamamlanmadı.')),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: url, publishableKey: key);
  runApp(
    MaterialApp(
      title: 'Atlas Katkı Yönetimi',
      debugShowCheckedModeBanner: false,
      theme: contributionTheme(),
      home: const AdminGate(),
    ),
  );
}

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final email = TextEditingController(), code = TextEditingController();
  bool busy = false, sent = false;
  String? error;
  final client = Supabase.instance.client;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!sent) {
        final token = (await _captcha().toDart).toDart;
        await client.auth.signInWithOtp(
          email: email.text.trim(),
          shouldCreateUser: false,
          captchaToken: token,
        );
        sent = true;
      } else {
        await client.auth.verifyOTP(
          email: email.text.trim(),
          token: code.text.trim(),
          type: OtpType.email,
        );
      }
    } catch (_) {
      error =
          'Giriş tamamlanamadı. E-posta, kod ve yönetici davetini kontrol et.';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: client.auth.onAuthStateChange,
    builder: (_, _) {
      if (client.auth.currentSession != null) {
        return AdminWorkspace(
          service: ContributionService(client),
          onExport: (text, name) => _download(text.toJS, name.toJS),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Atlas Katkı Yönetimi')),
        body: PageBody(
          children: [
            Text(
              'Yönetici girişi',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: email,
              enabled: !busy && !sent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            if (sent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'E-postadaki giriş kodu',
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error!),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(sent ? 'Giriş yap' : 'Giriş kodu gönder'),
            ),
            if (sent)
              TextButton(
                onPressed: busy ? null : () => setState(() => sent = false),
                child: const Text('Başka e-posta'),
              ),
          ],
        ),
      );
    },
  );
}
