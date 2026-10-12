import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wallpaper_source.dart';

/// Wallpaper source backed by the public Wallhaven JSON API
/// (`https://wallhaven.cc/api/v1/search`).
///
/// Unlike Pinterest this needs no WebView and no login — but an optional API
/// key unlocks NSFW/sketchy results and higher rate limits. Search returns
/// full-resolution `path` URLs directly, so the downloader's Pinterest
/// `/originals/` upgrade is a harmless no-op here.
///
/// Configurable knobs mirror the API query params documented at
/// https://wallhaven.cc/help/api :
///  - [query]      → `q` (space-separated tags; empty = browse)
///  - [categories] → `categories` bitmask general|anime|people (e.g. `111`)
///  - [purity]     → `purity` bitmask sfw|sketchy|nsfw (e.g. `100`)
///  - [sorting]    → `date_added|relevance|random|views|favorites|toplist`
///  - [portraitOnly] → adds `ratios=portrait`
class WallhavenSource implements WallpaperSource {
  final String query;
  final String categories;
  final String purity;
  final String sorting;
  final String? apiKey;
  final bool portraitOnly;
  final http.Client _client;

  WallhavenSource({
    this.query = '',
    this.categories = '111',
    this.purity = '100',
    this.sorting = 'random',
    this.apiKey,
    this.portraitOnly = true,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Wallhaven';

  /// Builds the search URL. Exposed for tests.
  Uri searchUri({int page = 1}) {
    final params = <String, String>{
      'categories': categories,
      'purity': purity,
      'sorting': sorting,
      'page': '$page',
    };
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (portraitOnly) params['ratios'] = 'portrait';
    if (apiKey != null && apiKey!.isNotEmpty) params['apikey'] = apiKey!;
    return Uri.https('wallhaven.cc', '/api/v1/search', params);
  }

  @override
  Future<List<PinCandidate>> fetch({int scrollRounds = 4}) async {
    final resp = await _client.get(searchUri());
    if (resp.statusCode != 200) {
      throw Exception('Wallhaven search failed: HTTP ${resp.statusCode}');
    }
    return parseSearch(jsonDecode(resp.body));
  }

  /// Maps a Wallhaven `/search` response body onto [PinCandidate]s.
  /// Pure and network-free so it can be unit-tested against a saved fixture.
  static List<PinCandidate> parseSearch(Object? body) {
    if (body is! Map) return const [];
    final data = body['data'];
    if (data is! List) return const [];
    final out = <PinCandidate>[];
    for (final e in data) {
      if (e is! Map) continue;
      final id = e['id']?.toString();
      final path = e['path'] as String?;
      if (id == null || path == null || path.isEmpty) continue;
      final source = e['source'] as String?;
      out.add(PinCandidate(
        // Prefix keeps ids unique against Pinterest's numeric pin ids in the
        // shared prefetch queue and download cache.
        pinId: 'wh_$id',
        pageUrl: (e['url'] as String?) ?? 'https://wallhaven.cc/w/$id',
        imageUrl: path,
        title: (source == null || source.isEmpty) ? null : source,
        width: (e['dimension_x'] as num?)?.toInt(),
        height: (e['dimension_y'] as num?)?.toInt(),
      ));
    }
    return out;
  }
}
