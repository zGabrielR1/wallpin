/// Shared wallpaper-source contract.
///
/// A "source" turns some upstream feed (Pinterest, Wallhaven, ...) into a list
/// of [PinCandidate]s the roulette picks from. Both the contract and the
/// candidate type live here, deliberately free of any Flutter import, so that
/// network-only sources (e.g. Wallhaven) stay unit-testable and the queue JSON
/// written by PrefetchService stays source-agnostic.
library;

/// Candidate image found in an upstream feed.
///
/// The name follows Pinterest's "pin" historically; every source produces it.
/// `pinId` must be globally unique across sources (prefix it, e.g. `wh_<id>`)
/// because it keys both the download cache file and the prefetch queue.
class PinCandidate {
  final String pinId;
  final String pageUrl;
  final String imageUrl;
  final String? title;
  final int? width;
  final int? height;

  PinCandidate({
    required this.pinId,
    required this.pageUrl,
    required this.imageUrl,
    this.title,
    this.width,
    this.height,
  });
}

/// A wallpaper feed.
///
/// Implementations are cheap to construct and hold no session/WebView state
/// beyond what they are given at construction. [fetch] returns *raw*
/// candidates — keyword/orientation filtering is applied once by the caller
/// (HomeScreen / PrefetchService) so every source is filtered identically.
abstract class WallpaperSource {
  /// Human-readable name, shown in status text.
  String get name;

  /// Fetch candidates. Sources that need a rendered browser (Pinterest) use a
  /// WebView handed in at construction; API sources ignore [scrollRounds].
  Future<List<PinCandidate>> fetch({int scrollRounds = 4});
}
