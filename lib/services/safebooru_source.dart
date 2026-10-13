import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wallpaper_source.dart';

/// Wallpaper source backed by the Safebooru JSON API
/// (`https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1`).
///
/// Same flavour as Konachan — a tag-driven anime/illustration booru — but a
/// different, larger catalog and SFW-only by design (no purity toggle needed).
/// Keyless, `sort:random` gives a fresh set every roll, and each post carries
/// real `width`/`height` so the shared portrait filter works untouched.
///
/// Tag syntax is the Danbooru/Moebooru family, so it reuses the same per-category
/// tag terms as [KonachanSource].
class SafebooruSource implements WallpaperSource {
  /// Space-separated tags, e.g. `scenery landscape`. Empty = everything.
  final String tags;

  final int limit;
  final http.Client _client;

  SafebooruSource({
    this.tags = '',
    this.limit = 24,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Safebooru';

  /// Builds the search URL with `sort:random` so each roll differs. Exposed
  /// for tests.
  Uri searchUri() {
    final parts = <String>[
      'sort:random',
      if (tags.trim().isNotEmpty) tags.trim(),
    ];
    return Uri.https('safebooru.org', '/index.php', {
      'page': 'dapi',
      's': 'post',
      'q': 'index',
      'json': '1',
      'limit': '$limit',
      'tags': parts.join(' '),
    });
  }

  @override
  Future<List<PinCandidate>> fetch({int scrollRounds = 4}) async {
    final resp = await _client.get(searchUri(), headers: {
      // Safebooru 403s the default Dart/curl UA.
      'User-Agent': 'WallPin/0.1 (personal wallpaper roulette)',
    });
    if (resp.statusCode != 200) {
      throw Exception('Safebooru search failed: HTTP ${resp.statusCode}');
    }
    return parsePosts(jsonDecode(resp.body));
  }

  /// Maps a Safebooru `/dapi/post/` array onto [PinCandidate]s. Pure and
  /// network-free so it can be unit-tested against a saved fixture.
  static List<PinCandidate> parsePosts(Object? body) {
    if (body is! List) return const [];
    final out = <PinCandidate>[];
    for (final e in body) {
      if (e is! Map) continue;
      final id = e['id']?.toString();
      final url = e['file_url'] as String?;
      if (id == null || url == null || url.isEmpty) continue;
      final owner = e['owner'] as String?;
      out.add(PinCandidate(
        // Prefix keeps ids unique against the other sources in the shared
        // prefetch queue and download cache.
        pinId: 'sb_$id',
        pageUrl: 'https://safebooru.org/index.php?page=post&s=view&id=$id',
        imageUrl: url,
        title: (owner == null || owner.isEmpty) ? null : owner,
        width: (e['width'] as num?)?.toInt(),
        height: (e['height'] as num?)?.toInt(),
      ));
    }
    return out;
  }
}
