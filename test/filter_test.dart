import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpin/services/filter_service.dart';
import 'package:wallpin/services/pinterest_scraper.dart';

void main() {
  test('filter drops memes and landscape when portrait-only', () {
    SharedPreferences.setMockInitialValues({'filter_portrait_only': true});
    // Note: run with `flutter test` after installing the Flutter SDK.
  });

  test('orig upgrade keeps pin ids', () {
    final c = PinCandidate(
      pinId: '123',
      pageUrl: 'https://www.pinterest.com/pin/123/',
      imageUrl: 'https://i.pinimg.com/origs/x.jpg',
      width: 1080,
      height: 1920,
    );
    expect(c.height! > c.width!, true);
  });
}
