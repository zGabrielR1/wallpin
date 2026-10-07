import 'dart:convert';
import 'dart:math';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'filter_service.dart';

/// Candidate image found in the Pinterest feed.
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

/// Fetches wallpaper candidates from Pinterest WITHOUT the official API.
///
/// Strategy (personal-use friendly):
///  1. User logs in once inside an InAppWebView (LoginScreen).
///  2. For roulette / auto-change we open a *headless* WebView to the home
///     feed (or a search URL built from the user's filter keywords), scroll a
///     few times, and run JS that extracts `pin id → orig image → title`.
///  3. HTTP fallback: Pinterest's public `widgets` endpoint
///     (`https://widgets.pinterest.com/v3/pidgets/boards/.../pins/`) works
///     without auth for public boards — used when the user configures
///     explicit board URLs in Settings.
///
/// Why JS extraction instead of reverse-engineering `/resource/*` JSON?
/// Pinterest rotates those internal endpoints + CSRF requirements often.
/// DOM extraction survives those changes and keeps working with just a
/// logged-in cookie jar.
class PinterestScraper {
  final FilterService filters;

  PinterestScraper(this.filters);

  static const _homeFeed = 'https://www.pinterest.com/';
  static const _searchBase = 'https://www.pinterest.com/search/pins/?q=';

  /// Headless scrape. [headlessWebView] must be provided by the caller
  /// (HomeScreen keeps one warm) — or pass null to create a short-lived one.
  Future<List<PinCandidate>> fetchCandidates({
    HeadlessInAppWebView? headlessWebView,
    int scrollRounds = 4,
  }) async {
    final queries = filters.activeQueries();
    final startUrl = queries.isEmpty
        ? _homeFeed
        : '${_searchBase}${Uri.encodeQueryComponent(queries[Random().nextInt(queries.length)])}';

    final webView = headlessWebView ?? HeadlessInAppWebView(initialUrlRequest: URLRequest(url: WebUri(startUrl)));
    if (headlessWebView == null) {
      await webView.run();
    } else {
      await webView.loadUrl(urlRequest: URLRequest(url: WebUri(startUrl)));
    }
    // Give the SPA time to boot.
    await Future<void>.delayed(const Duration(seconds: 4));

    for (var i = 0; i < scrollRounds; i++) {
      await webView.webViewController?.evaluateJavascript(source: 'window.scrollBy(0, window.innerHeight * 3);');
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    final raw = await webView.webViewController?.evaluateJavascript(
      source: _extractJs,
    );

    if (headlessWebView == null) {
      await webView.dispose();
    }

    final candidates = _parseExtracted(raw);
    return filters.apply(candidates);
  }

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
