import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'categories.dart';
import 'filter_service.dart';
import 'konachan_source.dart';
import 'openverse_source.dart';
import 'pinterest_scraper.dart';
import 'safebooru_source.dart';
import 'wallhaven_source.dart';
import 'wallpaper_source.dart';

/// Builds the enabled wallpaper sources from saved settings.
///
/// Pinterest is always on (it is the app's original feed). Wallhaven defaults
/// on (keyless, general). Konachan defaults off (anime-focused). Signed-in
/// Pinterest needs the warm [headless] WebView; the API sources ignore it.
///
/// When [category] is given (the roulette picks one enabled category per
/// roll), its per-source terms override the user's own tags/queries.
List<WallpaperSource> buildSources(
  SharedPreferences prefs, {
  HeadlessInAppWebView? headless,
  WallpaperCategory? category,
}) {
  final filters = FilterService(prefs);
  return [
    if (prefs.getBool('wallhaven_enabled') ?? true) wallhavenFromPrefs(prefs, filters, category),
    if (prefs.getBool('konachan_enabled') ?? false) konachanFromPrefs(prefs, category),
    if (prefs.getBool('safebooru_enabled') ?? true) safebooruFromPrefs(prefs, category),
    if (prefs.getBool('openverse_enabled') ?? false) openverseFromPrefs(prefs, filters, category),
    PinterestScraper(filters, headlessWebView: headless, queryOverride: category?.pinterest),
  ];
}

/// Reads the Wallhaven knobs persisted by SettingsScreen.
WallhavenSource wallhavenFromPrefs(SharedPreferences prefs, FilterService filters, [WallpaperCategory? category]) {
  final key = (prefs.getString('wallhaven_apikey') ?? '').trim();
  return WallhavenSource(
    query: category?.wallhaven ?? prefs.getString('wallhaven_query') ?? '',
    categories: prefs.getString('wallhaven_categories') ?? '111',
    purity: prefs.getString('wallhaven_purity') ?? '100',
    sorting: prefs.getString('wallhaven_sorting') ?? 'random',
    apiKey: key.isEmpty ? null : key,
    portraitOnly: filters.portraitOnly,
  );
}

/// Reads the Safebooru knobs persisted by SettingsScreen. Reuses the category's
/// booru tag terms — Safebooru shares the Danbooru/Moebooru tag language.
SafebooruSource safebooruFromPrefs(SharedPreferences prefs, [WallpaperCategory? category]) {
  return SafebooruSource(
    tags: category?.konachan ?? prefs.getString('safebooru_tags') ?? '',
  );
}

/// Reads the Openverse knobs persisted by SettingsScreen.
OpenverseSource openverseFromPrefs(SharedPreferences prefs, FilterService filters, [WallpaperCategory? category]) {
  final key = (prefs.getString('openverse_apikey') ?? '').trim();
  return OpenverseSource(
    query: category?.openverse ?? prefs.getString('openverse_query') ?? '',
    portraitOnly: filters.portraitOnly,
    apiKey: key.isEmpty ? null : key,
  );
}

/// Reads the Konachan knobs persisted by SettingsScreen.
KonachanSource konachanFromPrefs(SharedPreferences prefs, [WallpaperCategory? category]) {
  final safeOnly = prefs.getBool('konachan_safe') ?? true;
  return KonachanSource(
    host: safeOnly ? 'konachan.net' : 'konachan.com',
    tags: category?.konachan ?? prefs.getString('konachan_tags') ?? '',
    safeOnly: safeOnly,
  );
}
