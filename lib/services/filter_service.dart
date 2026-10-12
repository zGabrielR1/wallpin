import 'package:shared_preferences/shared_preferences.dart';

import 'wallpaper_source.dart';

/// Include/exclude keyword filtering + portrait-orientation preference.
///
/// The feed is still *your* Pinterest home feed (or Pinterest search scoped
/// to your taste when keywords are set). We just drop obvious non-wallpapers
/// (memes, quotes, screenshots) before the roulette picks one.
class FilterService {
  static const _kInclude = 'filter_include'; // comma-separated
  static const _kExclude = 'filter_exclude';
  static const _kPortraitOnly = 'filter_portrait_only';
  static const _kMinHeight = 'filter_min_height';

  final SharedPreferences prefs;

  FilterService(this.prefs);

  List<String> get includeKeywords => _split(prefs.getString(_kInclude));
  List<String> get excludeKeywords => _split(prefs.getString(_kExclude));
  bool get portraitOnly => prefs.getBool(_kPortraitOnly) ?? true;
  int get minHeight => prefs.getInt(_kMinHeight) ?? 1000;

  Future<void> save({List<String>? include, List<String>? exclude, bool? portraitOnly, int? minHeight}) async {
    if (include != null) await prefs.setString(_kInclude, include.join(', '));
    if (exclude != null) await prefs.setString(_kExclude, exclude.join(', '));
    if (portraitOnly != null) await prefs.setBool(_kPortraitOnly, portraitOnly);
    if (minHeight != null) await prefs.setInt(_kMinHeight, minHeight);
  }

  /// Search terms to scope the feed. Empty = raw home feed.
  List<String> activeQueries() => includeKeywords;

  static const _defaultExclude = [
    'meme',
    'funny',
    'quote',
    'screenshot',
    'infographic',
    'chart',
    'tutorial makeup',
  ];

  List<PinCandidate> apply(List<PinCandidate> input) {
    final exclude = {..._defaultExclude, ...excludeKeywords}.map((e) => e.toLowerCase()).toList();
    final include = includeKeywords.map((e) => e.toLowerCase()).toList();

    return input.where((c) {
      final hay = '${c.title ?? ''} ${c.pinId}'.toLowerCase();
      if (exclude.any((k) => k.isNotEmpty && hay.contains(k))) return false;
      if (portraitOnly && c.width != null && c.height != null) {
        if (c.height! < c.width!) return false; // landscape → skip
        if (c.height! < minHeight) return false;
      }
      if (include.isNotEmpty) {
        // When include terms exist we searched for one already; keep anything
        // that isn't excluded. (Title matching is best-effort — Pinterest
        // search already scoped the results.)
        return true;
      }
      return true;
    }).toList();
  }

  static List<String> _split(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
