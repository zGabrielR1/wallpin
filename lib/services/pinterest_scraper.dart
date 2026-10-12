import 'dart:convert';
import 'dart:math';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'filter_service.dart';
import 'wallpaper_source.dart';

/// Fetches wallpaper candidates from Pinterest WITHOUT the official API.
///
/// Strategy (personal-use friendly):
///  1. User logs in once inside an InAppWebView (LoginScreen).
///  2. For roulette / auto-change we open a *headless* WebView to the home
///     feed (or a search URL built from the user's filter keywords), scroll a
///     few times, and run JS that extracts `pin id → orig image → title`.
///  3. HTTP fallback: Pinterest's public `widgets` endpoint
///     (`https://widgets.pinterest.com/v3/pidgets/boards/.../pins/`) works
///     without auth for public boards — used for the explicit board URLs the
///     user configures in Settings (mixed in by [fetch]).
///
/// Why JS extraction instead of reverse-engineering `/resource/*` JSON?
/// Pinterest rotates those internal endpoints + CSRF requirements often.
/// DOM extraction survives those changes and keeps working with just a
/// logged-in cookie jar.
class PinterestScraper implements WallpaperSource {
  final FilterService filters;
  final HeadlessInAppWebView? _headless;

  /// When set (e.g. from an enabled category), scopes the headless search to
  /// this phrase instead of the user's own include-keywords.
  final String? queryOverride;

  PinterestScraper(this.filters, {HeadlessInAppWebView? headlessWebView, this.queryOverride})
      : _headless = headlessWebView;

  static const _homeFeed = 'https://www.pinterest.com/';
  static const _searchBase = 'https://www.pinterest.com/search/pins/?q=';

  @override
  String get name => 'Pinterest';

  /// Feed (or keyword-scoped search) plus up to [maxBoards] public boards from
  /// Settings. Returns raw candidates; filtering happens in the caller.
  @override
  Future<List<PinCandidate>> fetch({int scrollRounds = 4, int maxBoards = 3}) async {
    final out = <PinCandidate>[];
    // A dead feed (logged out / markup change) must not take down the other
    // sources, so boards are still attempted after a feed failure.
    try {
      out.addAll(await _fetchFeed(scrollRounds: scrollRounds));
    } catch (_) {}
    for (final b in _extraBoards().take(maxBoards)) {
      try {
        out.addAll(await fetchBoardPins(b));
      } catch (_) {}
    }
    return out;
  }

  /// Headless scrape of the home feed or a keyword search. Uses the WebView
  /// handed in at construction, or a short-lived one when none was given.
  Future<List<PinCandidate>> _fetchFeed({int scrollRounds = 4}) async {
    final queries = queryOverride != null ? [queryOverride!] : filters.activeQueries();
    final startUrl = queries.isEmpty
        ? _homeFeed
        : '$_searchBase${Uri.encodeQueryComponent(queries[Random().nextInt(queries.length)])}';

    final webView = _headless ?? HeadlessInAppWebView(initialUrlRequest: URLRequest(url: WebUri(startUrl)));
    if (_headless == null) {
      await webView.run();
    } else {
      await webView.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(startUrl)));
    }
    // Give the SPA time to boot.
    await Future<void>.delayed(const Duration(seconds: 4));

    for (var i = 0; i < scrollRounds; i++) {
      await webView.webViewController?.evaluateJavascript(source: 'window.scrollBy(0, window.innerHeight * 3);');
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    final raw = await webView.webViewController?.evaluateJavascript(source: _extractJs);

    if (_headless == null) {
      await webView.dispose();
    }

    return _parseExtracted(raw);
  }

  List<String> _extraBoards() => (filters.prefs.getString('extra_boards') ?? '')
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Public boards need no login. Used for explicit board URLs in Settings.
  /// Example board: `https://www.pinterest.com/username/board-slug/`
  Future<List<PinCandidate>> fetchBoardPins(String boardUrl) async {
    final m = RegExp(r'pinterest\.com\/([^\/]+)\/([^\/\?]+)').firstMatch(boardUrl);
    if (m == null) return [];
    final user = m.group(1)!;
    final slug = m.group(2)!;
    final uri = Uri.parse('https://widgets.pinterest.com/v3/pidgets/boards/$user/$slug/pins/');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final pins = (data['data']?['pins'] as List?) ?? [];
    // Live quirk (verified 2026-10-07): the pidgets endpoint returns 50 pins
    // with image keys '236x'/'237x'/'564x' — there is NO 'orig' key. Full-res
    // is derived by swapping the size prefix for '/originals/' (HTTP 200;
    // '/orig/' returns 403).
    final out = [
      for (final p in pins)
        if (p is Map && p['id'] != null && p['is_video'] != true)
          PinCandidate(
            pinId: p['id'].toString(),
            pageUrl: 'https://www.pinterest.com/pin/${p['id']}/',
            // Best thumbnail as-is; WallpaperService tries the
            // '/originals/' upgrade first and falls back to this.
            imageUrl: ((p['images']?['564x']?['url'] ??
                    p['images']?['237x']?['url'] ??
                    p['images']?['236x']?['url']) as String?) ??
                '',
            title: p['description'] as String?,
          ),
    ];
    out.removeWhere((c) => c.imageUrl.isEmpty);
    return out;
  }

  // ---------------------------------------------------------------- JS ---

  /// Extracts [{id, img, title, w, h}] from the rendered Pinterest DOM.
  /// Pins render as <a href="/pin/<id>/"> containing an <img srcset="...">.
  static const _extractJs = r'''
(() => {
  const out = [];
  const seen = new Set();
  document.querySelectorAll('a[href*="/pin/"]').forEach(a => {
    const m = a.href.match(/\/pin\/(\d+)/);
    if (!m) return;
    const id = m[1];
    if (seen.has(id)) return;
    seen.add(id);
    const img = a.querySelector('img');
    if (!img) return;
    let src = img.currentSrc || img.src || '';
    // NOTE: keep the RAW thumbnail URL here (currentSrc is already the best
    // size the feed served, often 736x). The originals-upgrade happens in
    // WallpaperService with fallback: '/originals/' 403s for ~25% of pins
    // (verified live 2026-10-07), so the downloader tries originals first
    // and falls back to this thumbnail on failure.
    const title = img.alt || '';
    out.push({id, img: src, title, w: img.naturalWidth || 0, h: img.naturalHeight || 0});
  });
  return JSON.stringify(out);
})()
''';

  List<PinCandidate> _parseExtracted(Object? raw) {
    try {
      final text = raw?.toString() ?? '[]';
      final list = jsonDecode(text) as List;
      return [
        for (final e in list)
          if (e is Map && (e['img'] as String?)?.isNotEmpty == true)
            PinCandidate(
              pinId: e['id'].toString(),
              pageUrl: 'https://www.pinterest.com/pin/${e['id']}/',
              imageUrl: e['img'] as String,
              title: (e['title'] as String?)?.isEmpty == true ? null : e['title'] as String?,
              width: (e['w'] as num?)?.toInt(),
              height: (e['h'] as num?)?.toInt(),
            ),
      ];
    } catch (_) {
      return [];
    }
  }
}
