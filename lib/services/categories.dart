import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A preset wallpaper category and how it maps onto each source's query
/// language. The roulette picks one enabled category per roll, so a single
/// "Cars" tag can mean a Wallhaven `q`, a Konachan tag set, and a Pinterest
/// search phrase at the same time.
class WallpaperCategory {
  final String name;

  /// Wallhaven `q` (free-text search).
  final String wallhaven;

  /// Konachan/Moebooru tag query (space-separated = AND).
  final String konachan;

  /// Pinterest include-keywords (scopes the headless search / feed).
  final String pinterest;

  const WallpaperCategory(this.name, {required this.wallhaven, required this.konachan, required this.pinterest});
}

/// The curated set shown as chips in Settings. Keep the per-source terms short
/// — they are combined with the source's own safety/sort params, not raw URLs.
const List<WallpaperCategory> kCategories = [
  WallpaperCategory('Anime', wallhaven: 'anime', konachan: 'anime', pinterest: 'anime wallpaper'),
  WallpaperCategory('Nature', wallhaven: 'nature', konachan: 'scenery nature', pinterest: 'nature wallpaper'),
  WallpaperCategory('Cars', wallhaven: 'cars', konachan: 'car', pinterest: 'cars wallpaper'),
  WallpaperCategory('Abstract', wallhaven: 'abstract', konachan: 'abstract', pinterest: 'abstract wallpaper'),
  WallpaperCategory('Art', wallhaven: 'art', konachan: 'art', pinterest: 'art wallpaper'),
  WallpaperCategory('Space', wallhaven: 'space', konachan: 'space', pinterest: 'space wallpaper'),
  WallpaperCategory('City', wallhaven: 'cityscape', konachan: 'city', pinterest: 'city wallpaper'),
  WallpaperCategory('Minimal', wallhaven: 'minimalism', konachan: 'minimalistic', pinterest: 'minimal wallpaper'),
  WallpaperCategory('Fantasy', wallhaven: 'fantasy', konachan: 'fantasy', pinterest: 'fantasy wallpaper'),
  WallpaperCategory('Games', wallhaven: 'video games', konachan: 'game cg', pinterest: 'game wallpaper'),
  WallpaperCategory('Sci-Fi', wallhaven: 'sci-fi', konachan: 'sci-fi', pinterest: 'sci-fi wallpaper'),
  WallpaperCategory('Flowers', wallhaven: 'flowers', konachan: 'flowers', pinterest: 'flowers wallpaper'),
];

const kCategoriesKey = 'categories';

/// Names of the categories the user enabled (empty = no category scoping).
List<String> selectedCategoryNames(SharedPreferences prefs) => (prefs.getString(kCategoriesKey) ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// One enabled category, chosen at random — or null when none are enabled
/// (the sources then fall back to the user's own tags/queries).
WallpaperCategory? randomCategory(SharedPreferences prefs, [Random? rng]) {
  final names = selectedCategoryNames(prefs);
  if (names.isEmpty) return null;
  final matches = kCategories.where((c) => names.contains(c.name)).toList();
  if (matches.isEmpty) return null;
  return matches[(rng ?? Random()).nextInt(matches.length)];
}
