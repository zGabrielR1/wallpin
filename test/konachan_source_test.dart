import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wallpin/services/konachan_source.dart';

/// Shape-accurate Moebooru `/post.json` array: one full post and one with a
/// missing author (title must fall back to null, not '').
const _fixture = '''
[
  {
    "id": 187317,
    "file_url": "https://konachan.net/image/abc/Konachan.com%20-%20187317.jpg",
    "jpeg_url": "https://konachan.net/jpeg/abc/187317.jpg",
    "sample_url": "https://konachan.net/sample/abc/187317.jpg",
    "preview_url": "https://konachan.net/data/preview/ab/c/abc.jpg",
    "width": 1200,
    "height": 848,
    "rating": "s",
    "author": "FormX",
    "tags": "scenery water"
  },
  {
    "id": 42,
    "file_url": "https://konachan.net/image/def/42.png",
    "width": 1080,
    "height": 1920,
    "rating": "s"
  }
]
''';

void main() {
  test('parsePosts maps fields and prefixes ids', () {
    final out = KonachanSource.parsePosts(jsonDecode(_fixture));
    expect(out, hasLength(2));

    final a = out[0];
    expect(a.pinId, 'kc_187317');
    expect(a.pageUrl, 'https://konachan.com/post/show/187317');
    expect(a.imageUrl, 'https://konachan.net/image/abc/Konachan.com%20-%20187317.jpg');
    expect(a.width, 1200);
    expect(a.height, 848);
    expect(a.title, 'FormX');

    expect(out[1].pinId, 'kc_42');
    expect(out[1].title, isNull);
    expect(out[1].imageUrl, 'https://konachan.net/image/def/42.png');
  });

  test('parsePosts tolerates malformed payloads', () {
    expect(KonachanSource.parsePosts(null), isEmpty);
    expect(KonachanSource.parsePosts('nope'), isEmpty);
    expect(KonachanSource.parsePosts(jsonDecode('[{"id":1}]')), isEmpty); // no url
  });

  test('searchUri adds rating:safe, order:random and tags', () {
    final uri = KonachanSource(tags: 'scenery city').searchUri();
    expect(uri.host, 'konachan.net');
    expect(uri.path, '/post.json');
    final tags = uri.queryParameters['tags']!;
    expect(tags, contains('rating:safe'));
    expect(tags, contains('order:random'));
    expect(tags, contains('scenery city'));
    expect(uri.queryParameters['limit'], '24');
  });

  test('safeOnly=false drops rating:safe and uses the given host', () {
    final uri = KonachanSource(host: 'konachan.com', safeOnly: false).searchUri();
    expect(uri.host, 'konachan.com');
    expect(uri.queryParameters['tags'], isNot(contains('rating:safe')));
  });

  test('fetch parses an injected 200 response', () async {
    final client = MockClient((_) async => http.Response(_fixture, 200));
    final out = await KonachanSource(client: client).fetch();
    expect(out, hasLength(2));
    expect(out.first.pinId, 'kc_187317');
  });

  test('fetch throws on a non-200 response', () {
    final client = MockClient((_) async => http.Response('blocked', 403));
    expect(KonachanSource(client: client).fetch(), throwsA(isA<Exception>()));
  });
}
