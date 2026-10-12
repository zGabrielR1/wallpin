import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wallpin/services/wallhaven_source.dart';

/// Trimmed but shape-accurate Wallhaven `/search` response (two results: a
/// general wallpaper with no source, and an anime one with a source URL).
const _fixture = '''
{
  "data": [
    {
      "id": "94x3yo",
      "url": "https://wallhaven.cc/w/94x3yo",
      "dimension_x": 1920,
      "dimension_y": 1080,
      "category": "general",
      "purity": "sfw",
      "path": "https://w.wallhaven.cc/full/94/wallhaven-94x3yo.jpg",
      "source": "",
      "thumbs": {"small": "s.jpg", "original": "o.jpg", "large": "l.jpg"}
    },
    {
      "id": "abc123",
      "url": "https://wallhaven.cc/w/abc123",
      "dimension_x": 1080,
      "dimension_y": 1920,
      "category": "anime",
      "purity": "sfw",
      "path": "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg",
      "source": "https://www.pixiv.net/en/artworks/1"
    }
  ],
  "meta": {"current_page": 1, "last_page": 100}
}
''';

void main() {
  test('parseSearch maps fields and prefixes ids to stay globally unique', () {
    final out = WallhavenSource.parseSearch(jsonDecode(_fixture));
    expect(out, hasLength(2));

    final a = out[0];
    expect(a.pinId, 'wh_94x3yo');
    expect(a.pageUrl, 'https://wallhaven.cc/w/94x3yo');
    expect(a.imageUrl, 'https://w.wallhaven.cc/full/94/wallhaven-94x3yo.jpg');
    expect(a.width, 1920);
    expect(a.height, 1080);
    expect(a.title, isNull); // empty source -> null, not ''

    expect(out[1].pinId, 'wh_abc123');
    expect(out[1].title, 'https://www.pixiv.net/en/artworks/1');
  });

  test('parseSearch tolerates malformed payloads without throwing', () {
    expect(WallhavenSource.parseSearch(null), isEmpty);
    expect(WallhavenSource.parseSearch('not a map'), isEmpty);
    expect(WallhavenSource.parseSearch({'data': 'nope'}), isEmpty);
    // an entry missing `path` is skipped, not emitted half-formed
    expect(WallhavenSource.parseSearch(jsonDecode('{"data":[{"id":"x"}]}')), isEmpty);
  });

  test('searchUri carries query, ratios, key and page', () {
    final s = WallhavenSource(
      query: 'anime nature',
      apiKey: 'KEY123',
      sorting: 'toplist',
      categories: '010',
      purity: '111',
    );
    final uri = s.searchUri(page: 2);
    expect(uri.host, 'wallhaven.cc');
    expect(uri.path, '/api/v1/search');
    expect(uri.queryParameters['q'], 'anime nature');
    expect(uri.queryParameters['apikey'], 'KEY123');
    expect(uri.queryParameters['sorting'], 'toplist');
    expect(uri.queryParameters['categories'], '010');
    expect(uri.queryParameters['purity'], '111');
    expect(uri.queryParameters['ratios'], 'portrait');
    expect(uri.queryParameters['page'], '2');
  });

  test('searchUri omits q/apikey/ratios when unset', () {
    final uri = WallhavenSource(portraitOnly: false).searchUri();
    expect(uri.queryParameters.containsKey('q'), isFalse);
    expect(uri.queryParameters.containsKey('apikey'), isFalse);
    expect(uri.queryParameters.containsKey('ratios'), isFalse);
    expect(uri.queryParameters['sorting'], 'random'); // roulette default
  });

  test('fetch parses an injected 200 response into candidates', () async {
    final client = MockClient((_) async => http.Response(_fixture, 200));
    final out = await WallhavenSource(client: client).fetch();
    expect(out, hasLength(2));
    expect(out.first.pinId, 'wh_94x3yo');
  });

  test('fetch throws on a non-200 response', () {
    final client = MockClient((_) async => http.Response('rate limited', 429));
    expect(WallhavenSource(client: client).fetch(), throwsA(isA<Exception>()));
  });
}
