import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallpaper_entry.dart';

/// Local cache of recently applied wallpapers.
///
/// - Keeps at most [maxEntries] (user-configurable, default 10).
/// - Drops entries older than [retention] (user-configurable, default 30d).
/// - Files live in the app cache dir; deleting the entry deletes the file.
class HistoryStore {
  static const _kJson = 'history_json';
  static const _kMax = 'history_max_entries';
  static const _kRetentionDays = 'history_retention_days';

  final SharedPreferences prefs;
  final List<WallpaperEntry> entries = [];

  HistoryStore(this.prefs);

  int get maxEntries => prefs.getInt(_kMax) ?? 10;
  int get retentionDays => prefs.getInt(_kRetentionDays) ?? 30;

  Future<void> setConfig({int? maxEntries, int? retentionDays}) async {
    if (maxEntries != null) await prefs.setInt(_kMax, maxEntries.clamp(1, 100));
    if (retentionDays != null) await prefs.setInt(_kRetentionDays, retentionDays.clamp(1, 365));
    await prune();
  }

  Future<void> load() async {
    entries.clear();
    final raw = prefs.getString(_kJson);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      entries.addAll(list.whereType<Map<String, dynamic>>().map(WallpaperEntry.fromJson));
    } catch (_) {
      // Corrupt cache → start fresh.
    }
    await prune();
  }

  Future<void> add(WallpaperEntry entry) async {
    entries.insert(0, entry);
    await prune();
    await save();
  }

  /// Imports records left by the native WallpaperWorker
  /// (`wallpin_pending_history.json` in the cache dir) into the history.
  /// Returns how many were imported. Idempotent by pin id.
  Future<int> importPending() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/wallpin_pending_history.json');
    if (!await f.exists()) return 0;
    var added = 0;
    try {
      final list = jsonDecode(await f.readAsString()) as List;
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        final id = e['id'] as String?;
        final localPath = e['localPath'] as String?;
        if (id == null || id.isEmpty || localPath == null) continue;
        if (entries.any((x) => x.id == id)) continue;
        if (!await File(localPath).exists()) continue;
        entries.insert(
          0,
          WallpaperEntry(
            id: id,
            pageUrl: e['pageUrl'] as String? ?? '',
            imageUrl: e['imageUrl'] as String? ?? '',
            title: e['title'] as String?,
            savedAt: DateTime.fromMillisecondsSinceEpoch(
              (e['savedAtMillis'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
            ),
            localPath: localPath,
          ),
        );
        added++;
      }
      await prune();
      await save();
    } catch (_) {
      // Half-written handoff file → ignore; worker rewrites atomically.
    }
    try {
      await f.delete();
    } catch (_) {}
    return added;
  }

  /// Delete expired / over-limit entries (and their files).
  Future<void> prune() async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    entries.removeWhere((e) => e.savedAt.isBefore(cutoff));
    while (entries.length > maxEntries) {
      final removed = entries.removeLast();
      try {
        final f = File(removed.localPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    // Persist a copy of the *cache dir* too: move temp downloads into the
    // persistent cache dir so the OS doesn't wipe them early.
    await save();
  }

  Future<File> persistTempFile(File temp, String pinId) async {
    final dir = await getApplicationCacheDirectory();
    final dest = File('${dir.path}/wallpin_$pinId.jpg');
    if (temp.path != dest.path) {
      await temp.copy(dest.path);
    }
    return dest;
  }

  Future<void> save() async {
    await prefs.setString(_kJson, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}
