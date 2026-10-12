import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/history_store.dart';
import 'services/pinterest_session.dart';
import 'services/scheduler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final session = PinterestSession(prefs);
  await session.load();
  final history = HistoryStore(prefs);
  await history.load();
  // Pick up wallpapers the native worker set while the app was closed.
  await history.importPending();

  // Idempotent: (re)applies the saved auto-change schedule to the native
  // WorkManager (UPDATE policy — never duplicates).
  await SchedulerService.apply(prefs);

  runApp(WallPinApp(session: session, history: history));
}

class WallPinApp extends StatelessWidget {
  final PinterestSession session;
  final HistoryStore history;

  const WallPinApp({super.key, required this.session, required this.history});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WallPin',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      darkTheme: ThemeData.dark(useMaterial3: true),
      initialRoute: session.isLoggedIn ? '/' : '/login',
      routes: {
        '/': (_) => HomeScreen(session: session, history: history),
        '/login': (_) => LoginScreen(session: session),
        '/history': (_) => HistoryScreen(history: history),
        '/settings': (_) => SettingsScreen(session: session),
      },
    );
  }
}
