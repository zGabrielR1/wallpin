import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wallpin/services/openverse_source.dart';

/// Shape-accurate Openverse `/v1/images/` response: one titled result and one
/// with no title (title must fall back to the creator).
const _fixture = '''
{
  "result_count": 240,
  "results": [
    {
      "id": "4c66d9ae-6115-47d2-8f1f-9af0f15bcba4",
      "title": "Nature Landscape",
      "url": "https://upload.wikimedia.org/a/b/landscape.jpg",
      "width": 3456,
      "height": 4608,
      "foreign_landing_url": "https://commons.wikimedia.org/w/index.php?curid=1",
      "license": "cc0",
      "creator": "Daderot"
    },
    {
      "id": "2547be2c-8ef3-4387-ae2e-bee0b3cff29a",
      "title": "",
      "url": "https://upload.wikimedia.org/c/d/untitled.png",
      "width": 1080,
      "height": 1920,
      "foreign_landing_url": "https://example.com/landing",
      "creator": "Photographer"
    }
  ]
}
''';

void main() {
  test('parseResults maps fields and prefixes ids', () {
    final out = OpenverseSource.parseResults(jsonDecode(_fixture));
    expect(out, hasLength(2));

    final a = out[0];
    expect(a.pinId, 'ov_4c66d9ae-6115-47d2-8f1f-9af0f15bcba4');
    expect(a.pageUrl, 'https://commons.wikimedia.org/w/index.php?curid=1');
    expect(a.imageUrl, 'https://upload.wikimedia.org/a/b/landscape.jpg');
    expect(a.width, 3456);
    expect(a.height, 4608);
    expect(a.title, 'Nature Landscape');

    expect(out[1].pinId, 'ov_2547be2c-8ef3-4387-ae2e-bee0b3cff29a');
    expect(out[1].title, 'Photographer'); // empty title -> creator
  });

  test('parseResults tolerates malformed payloads', () {
    expect(OpenverseSource.parseResults(null), isEmpty);
    expect(OpenverseSource.parseResults('nope'), isEmpty);
    expect(OpenverseSource.parseResults({'results': 'x'}), isEmpty);
    expect(OpenverseSource.parseResults(jsonDecode('{"results":[{"id":"x"}]}')), isEmpty); // no url
  });

  test('searchUri adds tall aspect for portrait and a default query', () {
    final uri = OpenverseSource(query: 'nature landscape').searchUri();
    expect(uri.host, 'api.openverse.org');
    expect(uri.path, '/v1/images/');
    expect(uri.queryParameters['q'], 'nature landscape');
    expect(uri.queryParameters['aspect_ratio'], 'tall');
    expect(uri.queryParameters['size'], 'large');
  });

  test('searchUri drops tall and falls back to wallpaper', () {
    final uri = OpenverseSource(portraitOnly: false).searchUri();
    expect(uri.queryParameters['q'], 'wallpaper');
    expect(uri.queryParameters.containsKey('aspect_ratio'), isFalse);
  });

  test('fetch sends the bearer token when a key is set', () async {
    String? auth;
    final client = MockClient((req) async {
      auth = req.headers['authorization'];
      return http.Response(_fixture, 200);
    });
    final out = await OpenverseSource(apiKey: 'TOKEN', client: client).fetch();
    expect(out, hasLength(2));
    expect(auth, 'Bearer TOKEN');
  });

  test('fetch throws on a non-200 response', () {
    final client = MockClient((_) async => http.Response('rate limited', 429));
    expect(OpenverseSource(client: client).fetch(), throwsA(isA<Exception>()));
  });
}
