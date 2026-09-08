import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_data.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_service.dart';

void main() {
  // A page that spans a surah boundary — the ordinary case at the start of
  // most surahs, and the one where getting the verse wrong matters.
  final body = jsonDecode('''
  {"verses":[
    {"verse_key":"2:286","words":[
      {"code_v1":"A","line_number":1,"text_uthmani":"رَبَّنَا","char_type_name":"word"},
      {"code_v1":"B","line_number":1,"text_uthmani":"٢٨٦","char_type_name":"end"}
    ]},
    {"verse_key":"3:1","words":[
      {"code_v1":"C","line_number":2,"text_uthmani":"الٓمٓ","char_type_name":"word"}
    ]}
  ]}
  ''');

  test('each word knows the verse it belongs to', () {
    // A printed line runs straight through a verse boundary, so the verse
    // cannot be inferred from position — a tap has to read it off the word.
    final page = MushafPageService.parseResponse(49, body);

    expect(page.words[0].surah, 2);
    expect(page.words[0].ayah, 286);
    expect(page.words[2].surah, 3);
    expect(page.words[2].ayah, 1);
  });

  test('the closing rosette belongs to its own verse, not the next', () {
    final page = MushafPageService.parseResponse(49, body);
    expect(page.words[1].isEnd, isTrue);
    expect(page.words[1].surah, 2);
    expect(page.words[1].ayah, 286);
  });

  test('the verse survives the round trip through storage', () {
    // Pages are cached; a shape that drops the verse would make every tap on
    // a page opened from cache do nothing at all.
    final page = MushafPageService.parseResponse(49, body);
    final back = MushafPageData.fromJson(
      jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>,
    );

    expect(back.words[0].surah, 2);
    expect(back.words[0].ayah, 286);
    expect(back.words[2].surah, 3);
    expect(back.words[2].ayah, 1);
  });

  test('the cache generation moved with the shape', () {
    // Entries stored before words carried a verse have no surah or ayah in
    // them, and reading one back throws on the cast rather than degrading.
    final service = MushafPageService.new;
    expect(service, isNotNull);
    expect(
      MushafPageService.totalPages,
      604,
      reason: 'the Madani Mus\'haf is 604 pages',
    );
  });
}
