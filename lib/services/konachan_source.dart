import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wallpaper_source.dart';

/// Wallpaper source backed by the Moebooru JSON API used by Konachan
/// (`https://konachan.net/post.json` — the SFW-only mirror; `konachan.com`
/// also serves NSFW when not tag-filtered).
///
/// Keyless and abundant: `order:random` returns a fresh set every roll, and
/// the API gives full-resolution `file_url`s plus real dimensions, so the
/// shared portrait filter works untouched.
class KonachanSource implements WallpaperSource {
  /// `net` = SFW mirror, `com` = includes questionable/explicit unless
  /// [safeOnly] filters them by tag.
  final String host;

  /// Space-separated tags, e.g. `scenery landscape`. Empty = everything.
  final String tags;

  /// Appends `rating:safe` to the tag query.
  final bool safeOnly;

  final int limit;
  final http.Client _client;

  KonachanSource({
    this.host = 'konachan.net',
    this.tags = '',
    this.safeOnly = true,
    this.limit = 24,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Konachan';

  /// Builds the search URL with `order:random` so each roll differs.
  /// Exposed for tests.
  Uri searchUri() {
    final parts = <String>[
      if (safeOnly) 'rating:safe',
      'order:random',
      if (tags.trim().isNotEmpty) tags.trim(),
    ];
    return Uri.https(host, '/post.json', {
      'tags': parts.join(' '),
      'limit': '$limit',
    });
  }

  @override
  Future<List<PinCandidate>> fetch({int scrollRounds = 4}) async {
    final resp = await _client.get(searchUri(), headers: {
      // Konachan 403s the default Dart/curl UA.
      'User-Agent': 'WallPin/0.1 (personal wallpaper roulette)',
    });
    if (resp.statusCode != 200) {
      throw Exception('Konachan search failed: HTTP ${resp.statusCode}');
    }
    return parsePosts(jsonDecode(resp.body));
  }

  /// Maps a Moebooru `/post.json` array onto [PinCandidate]s. Pure and
  /// network-free so it can be unit-tested against a saved fixture.
  static List<PinCandidate> parsePosts(Object? body) {
    if (body is! List) return const [];
    final out = <PinCandidate>[];
    for (final e in body) {
      if (e is! Map) continue;
      final id = e['id']?.toString();
      final url = (e['file_url'] ?? e['jpeg_url'] ?? e['sample_url']) as String?;
      if (id == null || url == null || url.isEmpty) continue;
      final author = e['author'] as String?;
      out.add(PinCandidate(
        // Prefix keeps ids unique against the other sources in the shared
        // prefetch queue and download cache.
        pinId: 'kc_$id',
        pageUrl: 'https://konachan.com/post/show/$id',
        imageUrl: url,
        title: (author == null || author.isEmpty) ? null : author,
        width: (e['width'] as num?)?.toInt(),
        height: (e['height'] as num?)?.toInt(),
      ));
    }
    return out;
  }
}
