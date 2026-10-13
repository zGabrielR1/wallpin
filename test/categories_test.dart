import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpin/services/categories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('category names are unique', () {
    final names = kCategories.map((c) => c.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('every category maps to a non-empty term for each source', () {
    for (final c in kCategories) {
      expect(c.wallhaven, isNotEmpty, reason: '${c.name} wallhaven');
      expect(c.konachan, isNotEmpty, reason: '${c.name} konachan');
      expect(c.openverse, isNotEmpty, reason: '${c.name} openverse');
      expect(c.pinterest, isNotEmpty, reason: '${c.name} pinterest');
    }
  });

  test('selectedCategoryNames parses a comma list', () async {
    SharedPreferences.setMockInitialValues({kCategoriesKey: 'Anime, Cars ,Nature'});
    final prefs = await SharedPreferences.getInstance();
    expect(selectedCategoryNames(prefs), ['Anime', 'Cars', 'Nature']);
  });

  test('randomCategory is null when nothing is selected', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(randomCategory(prefs), isNull);
  });

  test('randomCategory only returns enabled categories', () async {
    SharedPreferences.setMockInitialValues({kCategoriesKey: 'Anime,Cars'});
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 20; i++) {
      final c = randomCategory(prefs, Random(i));
      expect(c, isNotNull);
      expect(['Anime', 'Cars'], contains(c!.name));
    }
  });
}
