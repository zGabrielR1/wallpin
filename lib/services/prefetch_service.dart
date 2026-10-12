import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'categories.dart';
import 'filter_service.dart';
import 'source_registry.dart';
import 'wallpaper_source.dart';

/// Foreground refill for the background worker's queue.
///
/// The native WallpaperWorker can't render Pinterest's JS feed (no WebView
/// in the background), so while the app is open we scrape candidates here
/// and stash URLs in `wallpin_queue.json` (same cache dir the worker reads).
/// Schema (shared with WallpaperWorker.kt — keep in sync):
/// ```json
/// {"urls": [{"id","pageUrl","imageUrl","title"}], "boards": ["https://..."]}
/// ```
class PrefetchService {
  static const _target = 15;
  static const _max = 30;

  static Future<int> queueSize() async {
    try {
      final f = await _file();
      if (!await f.exists()) return 0;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (j['urls'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Scrapes fresh candidates from every enabled source and merges them into
  /// the queue. No-op when the queue is already full enough.
  static Future<void> topUp({HeadlessInAppWebView? headless}) async {
    if (await queueSize() >= _target) return;
    final prefs = await SharedPreferences.getInstance();
    final fresh = <PinCandidate>[];
    for (final source in buildSources(prefs, headless: headless, category: randomCategory(prefs))) {
      try {
        fresh.addAll(await source.fetch(scrollRounds: 3));
      } catch (_) {}
    }
    final filtered = FilterService(prefs).apply(fresh);
    if (filtered.isEmpty) return;
    filtered.shuffle();

    final f = await _file();
    Map<String, dynamic> json = {'urls': [], 'boards': extraBoards(prefs)};
    try {
      if (await f.exists()) {
        json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    final urls = (json['urls'] as List? ?? []).whereType<Map>().toList();
    final seen = urls.map((e) => e['id']).toSet();
    for (final c in filtered) {
      if (seen.add(c.pinId)) {
        urls.add({'id': c.pinId, 'pageUrl': c.pageUrl, 'imageUrl': c.imageUrl, 'title': c.title});
      }
      if (urls.length >= _max) break;
    }
    json['urls'] = urls;
    json['boards'] = extraBoards(prefs);
    await f.writeAsString(jsonEncode(json));
  }

  static List<String> extraBoards(SharedPreferences prefs) => (prefs.getString('extra_boards') ?? '')
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static Future<File> _file() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/wallpin_queue.json');
  }
}
