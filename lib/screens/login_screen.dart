import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/pinterest_session.dart';

/// Pinterest login inside an embedded WebView.
///
/// No API keys, no OAuth app review — the user just logs in with their real
/// Pinterest account. The session cookies stay in the WebView jar and are
/// reused by the scraper, so the app sees the same home feed as the user.
///
/// Detection is deliberately strict: we only auto-advance once a *profile*
/// element is present AND the login form is gone. The old heuristic
/// (`innerHTML.includes('header')`) fired on the login page itself and skipped
/// login entirely.
class LoginScreen extends StatefulWidget {
  final PinterestSession session;
  const LoginScreen({super.key, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _loginUrl = 'https://www.pinterest.com/login/';

  /// Google refuses embedded WebViews whose UA doesn't look like a real Chrome
  /// ("This browser or app may not be secure"), which surfaces as a blank or
  /// black page. A desktop Chrome UA keeps the OAuth popup usable.
  static const _desktopChromeUA =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  InAppWebViewController? _controller;

  /// Strict logged-in probe → JSON `{loggedIn, username}`.
  static const _detectJs = r'''
(() => {
  const loginForm = document.querySelector(
    'input[name="email"], input#email, [data-test-id="login-email"], input[autocomplete="username"]');
  const profile = document.querySelector(
    '[data-test-id="header-profile"], [data-test-id="profile-avatar"], a[href="/settings/"], a[aria-label*="profile" i]');
  let username = null;
  if (profile && profile.getAttribute) {
    const href = profile.getAttribute('href') || '';
    const m = href.match(/^\/([A-Za-z0-9._-]+)\/?$/);
    if (m && !['login', 'signup', 'settings', 'ideas', 'business'].includes(m[1])) {
      username = m[1];
    }
  }
  return JSON.stringify({ loggedIn: !!profile && !loginForm, username });
})()
''';

  Future<void> _probeIfLoggedIn() async {
    final c = _controller;
    if (c == null) return;
    final url = await c.getUrl();
    if (url == null || !url.host.contains('pinterest.com') || url.path.contains('/login')) return;
    final raw = await c.evaluateJavascript(source: _detectJs);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      if (data['loggedIn'] == true) {
        await widget.session.setLoggedIn(data['username'] as String?);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in! Fetching your feed…')));
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } catch (_) {
      // Non-JSON / page still booting — ignore, the user can tap Continue.
    }
  }

  Future<void> _continueManually() async {
    await widget.session.setLoggedIn(widget.session.username);
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  /// Clears the WebView cookie jar and the stored flag → next login screen is
  /// a fresh account.
  Future<void> _logoutAndSwitch() async {
    await CookieManager.instance().deleteAllCookies();
    await widget.session.logout();
    final c = _controller;
    if (c != null) {
      await c.loadUrl(urlRequest: URLRequest(url: WebUri(_loginUrl)));
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out of Pinterest.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = widget.session.isLoggedIn;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinterest account'),
        actions: [
          if (loggedIn)
            TextButton.icon(
              onPressed: _logoutAndSwitch,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Log out', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: loggedIn ? Colors.green.shade100 : Colors.orange.shade100,
            child: Text(
              loggedIn
                  ? 'Signed in as ${widget.session.username ?? 'your account'}. Log in below to switch accounts.'
                  : 'Not signed in. Log in below — WallPin never sees your password, it only reuses the session to read your own home feed.',
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_loginUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
                userAgent: _desktopChromeUA,
                // "Continue with Google" opens window.open(); without these the
                // popup becomes an invisible window and the page goes black.
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: true,
                useWideViewPort: true,
                mediaPlaybackRequiresUserGesture: false,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
              ),
              onCreateWindow: (controller, createWindowAction) async {
                // Load the popup into this same WebView instead of a separate,
                // unrendered window.
                final url = createWindowAction.request.url;
                if (url != null && url.toString() != 'about:blank') {
                  await controller.loadUrl(urlRequest: URLRequest(url: url));
                }
                return false;
              },
              onWebViewCreated: (c) => _controller = c,
              onLoadStop: (controller, url) async {
                _controller = controller;
                await _probeIfLoggedIn();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _logoutAndSwitch,
                    child: const Text('Log out / switch account'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _continueManually,
                    child: const Text("I'm logged in — continue"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
