import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground API for the native auto-change scheduler.
///
/// The actual periodic work is a pure-native Android Worker
/// ([WallpaperWorker] in Kotlin): no Dart runs in the background, so there
/// are no background-isolate plugin or WebView problems, and it survives
/// app kills and reboots. These methods just (re)configure it.
///
/// Feed-based variety reaches the background via `wallpin_queue.json`,
/// refilled by [PrefetchService] while the app is open.
class SchedulerService {
  static const _channel = MethodChannel('wallpin/scheduler');
  static const _kEnabled = 'auto_enabled';
  static const _kHours = 'auto_hours';

  static bool isEnabled(SharedPreferences p) => p.getBool(_kEnabled) ?? true;
  static int intervalHours(SharedPreferences p) => p.getInt(_kHours) ?? 24;

  static Future<void> save(SharedPreferences p, {bool? enabled, int? hours}) async {
    if (enabled != null) await p.setBool(_kEnabled, enabled);
    if (hours != null) await p.setInt(_kHours, hours.clamp(1, 24 * 30));
    await apply(p);
  }

  /// (Re)applies the saved schedule to the native WorkManager. Idempotent —
  /// called on every app launch so updates/reboots never lose the schedule
  /// (the native side also uses UPDATE policy, so this never duplicates).
  static Future<void> apply(SharedPreferences p) async {
    try {
      if (!isEnabled(p)) {
        await _channel.invokeMethod('cancel');
        return;
      }
      await _channel.invokeMethod('schedule', {
        'hours': intervalHours(p),
        'maxEntries': p.getInt('history_max_entries') ?? 10,
        'retentionDays': p.getInt('history_retention_days') ?? 30,
      });
    } catch (_) {
      // Non-Android (or channel missing) → foreground-only mode, no crash.
    }
  }

  /// Triggers one background change right now (Settings "test" button).
  static Future<void> runNow(SharedPreferences p) async {
    try {
      await _channel.invokeMethod('runNow', {
        'maxEntries': p.getInt('history_max_entries') ?? 10,
        'retentionDays': p.getInt('history_retention_days') ?? 30,
      });
    } catch (_) {}
  }
}
