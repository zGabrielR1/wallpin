import 'package:shared_preferences/shared_preferences.dart';

/// Holds "am I logged into Pinterest?" state.
///
/// Actual cookies live inside the InAppWebView cookie jar (managed by the
/// OS WebView). We only persist a boolean + username here. All authenticated
/// HTTP calls reuse WebView cookies by injecting `document.cookie` — see
/// [PinterestScraper] — so we never handle the password ourselves.
class PinterestSession extends ChangeNotifierLike {
  static const _kLoggedIn = 'pinterest_logged_in';
  static const _kUsername = 'pinterest_username';

  final SharedPreferences prefs;
  bool isLoggedIn = false;
  String? username;

  final List<void Function()> _listeners = [];

  PinterestSession(this.prefs);

  Future<void> load() async {
    isLoggedIn = prefs.getBool(_kLoggedIn) ?? false;
    username = prefs.getString(_kUsername);
  }

  Future<void> setLoggedIn(String? detectedUsername) async {
    isLoggedIn = true;
    username = detectedUsername;
    await prefs.setBool(_kLoggedIn, true);
    if (detectedUsername != null) {
      await prefs.setString(_kUsername, detectedUsername);
    }
    _notify();
  }

  Future<void> logout() async {
    isLoggedIn = false;
    username = null;
    await prefs.setBool(_kLoggedIn, false);
    await prefs.remove(_kUsername);
    _notify();
  }

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}

/// Minimal ChangeNotifier stand-in so this class has zero Flutter deps.
class ChangeNotifierLike {}
