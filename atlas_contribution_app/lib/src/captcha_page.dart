import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CaptchaPage extends StatefulWidget {
  const CaptchaPage({required this.url, super.key});
  final Uri url;
  @override
  State<CaptchaPage> createState() => _CaptchaPageState();
}

class _CaptchaPageState extends State<CaptchaPage> {
  late final WebViewController _web;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AtlasCaptcha',
        onMessageReceived: (message) {
          if (_finished || !mounted) return;
          try {
            final data = jsonDecode(message.message) as Map;
            if (data['token'] is String &&
                (data['token'] as String).isNotEmpty) {
              _finished = true;
              Navigator.pop(context, data['token']);
            }
          } on FormatException {
            /* Ignore malformed bridge messages. */
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null &&
                    uri.scheme == 'https' &&
                    (uri.host == widget.url.host ||
                        uri.host == 'challenges.cloudflare.com')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giriş kontrolü')),
    body: SafeArea(child: WebViewWidget(controller: _web)),
  );
}
