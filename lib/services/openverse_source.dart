import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wallpaper_source.dart';

/// Wallpaper source backed by the Openverse API
/// (`https://api.openverse.org/v1/images/`) — a large index of
/// Creative-Commons photos and art (Flickr, Wikimedia, museums, …).
///
/// Keyless and generous with filters: `aspect_ratio=tall` + `size=large` gives
/// real portrait wallpapers, and results carry dimensions so the shared
/// portrait filter works untouched. Anonymous quota is 20/min + 200/day;
/// passing an [apiKey] (an Openverse bearer token) raises it.
class OpenverseSource implements WallpaperSource {
  /// Free-text query. Falls back to `wallpaper` when empty.
  final String query;

  /// Adds `aspect_ratio=tall` (portrait).
  final bool portraitOnly;

  /// Optional Openverse bearer token (`Authorization: Bearer …`).
  final String? apiKey;

  final int limit;
  final http.Client _client;

  OpenverseSource({
    this.query = '',
    this.portraitOnly = true,
    this.apiKey,
    this.limit = 20,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Openverse';

  /// Builds the search URL. Exposed for tests.
  Uri searchUri({int page = 1}) {
    final q = query.trim();
    final params = <String, String>{
      'q': q.isEmpty ? 'wallpaper' : q,
      'page_size': '$limit',
      'page': '$page',
      'size': 'large',
    };
    if (portraitOnly) params['aspect_ratio'] = 'tall';
    return Uri.https('api.openverse.org', '/v1/images/', params);
  }

  @override
  Future<List<PinCandidate>> fetch({int scrollRounds = 4}) async {
    final headers = <String, String>{
      'User-Agent': 'WallPin/0.1 (personal wallpaper roulette)',
      if (apiKey != null && apiKey!.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };
    final resp = await _client.get(searchUri(), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Openverse search failed: HTTP ${resp.statusCode}');
    }
    return parseResults(jsonDecode(resp.body));
  }

  /// Maps an Openverse `/v1/images/` response onto [PinCandidate]s. Pure and
  /// network-free so it can be unit-tested against a saved fixture.
  static List<PinCandidate> parseResults(Object? body) {
    if (body is! Map) return const [];
    final results = body['results'];
    if (results is! List) return const [];
    final out = <PinCandidate>[];
    for (final e in results) {
      if (e is! Map) continue;
      final id = e['id']?.toString();
      final url = e['url'] as String?;
      if (id == null || url == null || url.isEmpty) continue;
      final title = e['title'] as String?;
      final creator = e['creator'] as String?;
      out.add(PinCandidate(
        // Prefix keeps ids unique against the other sources in the shared
        // prefetch queue and download cache.
        pinId: 'ov_$id',
        pageUrl: (e['foreign_landing_url'] as String?) ?? url,
        imageUrl: url,
        title: (title == null || title.isEmpty)
            ? (creator == null || creator.isEmpty ? null : creator)
            : title,
        width: (e['width'] as num?)?.toInt(),
        height: (e['height'] as num?)?.toInt(),
      ));
    }
    return out;
  }
}
