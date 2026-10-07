import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/pinterest_session.dart';

/// Pinterest login inside an embedded WebView.
///
/// No API keys, no OAuth app review — the user just logs in with their real
/// Pinterest account. The session cookies stay in the WebView jar and are
/// reused by the scraper, so the app sees the same home feed as the user.
class LoginScreen extends StatefulWidget {
  final PinterestSession session;
  const LoginScreen({super.key, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final InAppWebViewController? _ctrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in with Pinterest')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Log in below with your Pinterest account. WallPin never sees your password — '
              'it only reuses this logged-in session to read your own home feed.',
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://www.pinterest.com/login/')),
              initialSettings: InAppWebViewSettings(javaScriptEnabled: true, thirdPartyCookiesEnabled: true),
              onWebViewCreated: (c) => _ctrl = c,
              onLoadStop: (controller, url) async {
                // Heuristic: user avatar / header appears once logged in.
                final marker = await controller.evaluateJavascript(
                  source: "document.documentElement.innerHTML.includes('header') && document.cookie.includes('csrftoken')",
                );
                if (marker == true && (url?.host.contains('pinterest.com') ?? false)) {
                  final username = await controller.evaluateJavascript(
                    source: "document.documentElement.innerHTML.match(/\\/([^\\/\\\"]+)\\/pins\\//)?.[1] ?? null",
                  );
                  await widget.session.setLoggedIn(username?.toString());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in! Fetching your feed…')));
                    Navigator.pushReplacementNamed(context, '/');
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: () async {
                // Manual "I'm logged in" escape hatch if auto-detect misses.
                await widget.session.setLoggedIn(null);
                if (context.mounted) Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text("I've logged in — continue"),
            ),
          ),
        ],
      ),
    );
  }
}
