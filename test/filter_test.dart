import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpin/services/filter_service.dart';
import 'package:wallpin/services/wallpaper_source.dart';

PinCandidate _c(String id, {String? title, int? w, int? h}) => PinCandidate(
      pinId: id,
      pageUrl: 'https://example.com/$id',
      imageUrl: 'https://example.com/$id.jpg',
      title: title,
      width: w,
      height: h,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('apply drops default junk keywords (meme/quote/...)', () async {
    SharedPreferences.setMockInitialValues({});
    final f = FilterService(await SharedPreferences.getInstance());
    final out = f.apply([
      _c('1', title: 'funny meme'),
      _c('2', title: 'mountain sunset'),
      _c('3', title: 'motivational quote'),
    ]);
    expect(out.map((c) => c.pinId), ['2']);
  });

  test('apply honors a custom exclude keyword', () async {
    SharedPreferences.setMockInitialValues({'filter_exclude': 'cars'});
    final f = FilterService(await SharedPreferences.getInstance());
    final out = f.apply([_c('1', title: 'red cars'), _c('2', title: 'forest')]);
    expect(out.map((c) => c.pinId), ['2']);
  });

  test('portrait-only drops landscape and below-min-height images', () async {
    SharedPreferences.setMockInitialValues({'filter_portrait_only': true});
    final f = FilterService(await SharedPreferences.getInstance());
    final out = f.apply([
      _c('land', w: 1920, h: 1080), // landscape -> drop
      _c('short', w: 800, h: 900), // under minHeight (1000) -> drop
      _c('good', w: 1080, h: 1920), // keep
      _c('unknown'), // no dimensions -> kept (can't judge)
    ]);
    expect(out.map((c) => c.pinId), ['good', 'unknown']);
  });

  test('portrait-only off keeps landscape', () async {
    SharedPreferences.setMockInitialValues({'filter_portrait_only': false});
    final f = FilterService(await SharedPreferences.getInstance());
    final out = f.apply([_c('land', w: 1920, h: 1080)]);
    expect(out.map((c) => c.pinId), ['land']);
  });
}
