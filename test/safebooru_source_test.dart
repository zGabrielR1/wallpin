import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wallpin/services/safebooru_source.dart';

/// Shape-accurate Safebooru `/dapi/post/` array: one portrait post and one
/// with no owner (title must fall back to null).
const _fixture = '''
[
  {
    "id": 3805844,
    "file_url": "https://safebooru.org/images/3640/9b9b47acce65957da29c1a599473ad4873739402.jpg",
    "sample_url": "https://safebooru.org/samples/3640/sample_9b9b47acce65957da29c1a599473ad4873739402.jpg",
    "width": 1599,
    "height": 2048,
    "rating": "safe",
    "owner": "danbooru",
    "tags": "1girl landscape scenery"
  },
  {
    "id": 42,
    "file_url": "https://safebooru.org/images/1/abc.png",
    "width": 1080,
    "height": 1920,
    "rating": "safe",
    "owner": ""
  }
]
''';

void main() {
  test('parsePosts maps fields and prefixes ids', () {
    final out = SafebooruSource.parsePosts(jsonDecode(_fixture));
    expect(out, hasLength(2));

    final a = out[0];
    expect(a.pinId, 'sb_3805844');
    expect(a.pageUrl, 'https://safebooru.org/index.php?page=post&s=view&id=3805844');
    expect(a.imageUrl, 'https://safebooru.org/images/3640/9b9b47acce65957da29c1a599473ad4873739402.jpg');
    expect(a.width, 1599);
    expect(a.height, 2048);
    expect(a.title, 'danbooru');

    expect(out[1].pinId, 'sb_42');
    expect(out[1].title, isNull); // empty owner -> null, not ''
  });

  test('parsePosts tolerates malformed payloads', () {
    expect(SafebooruSource.parsePosts(null), isEmpty);
    expect(SafebooruSource.parsePosts('nope'), isEmpty);
    expect(SafebooruSource.parsePosts(jsonDecode('[{"id":1}]')), isEmpty); // no url
  });

  test('searchUri is the dapi JSON endpoint with sort:random and tags', () {
    final uri = SafebooruSource(tags: 'scenery landscape').searchUri();
    expect(uri.host, 'safebooru.org');
    expect(uri.path, '/index.php');
    expect(uri.queryParameters['page'], 'dapi');
    expect(uri.queryParameters['s'], 'post');
    expect(uri.queryParameters['q'], 'index');
    expect(uri.queryParameters['json'], '1');
    final tags = uri.queryParameters['tags']!;
    expect(tags, contains('sort:random'));
    expect(tags, contains('scenery landscape'));
    expect(uri.queryParameters['limit'], '24');
  });

  test('searchUri still sorts randomly with no tags', () {
    expect(SafebooruSource().searchUri().queryParameters['tags'], 'sort:random');
  });

  test('fetch parses an injected 200 response', () async {
    final client = MockClient((_) async => http.Response(_fixture, 200));
    final out = await SafebooruSource(client: client).fetch();
    expect(out, hasLength(2));
    expect(out.first.pinId, 'sb_3805844');
  });

  test('fetch throws on a non-200 response', () {
    final client = MockClient((_) async => http.Response('blocked', 403));
    expect(SafebooruSource(client: client).fetch(), throwsA(isA<Exception>()));
  });
}
