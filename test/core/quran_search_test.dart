import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_search_service.dart';

void main() {
  test('maps hits to surah and ayah', () {
    final body = jsonDecode('''
    {"search":{"query":"الرحمن","total_results":45,"results":[
      {"verse_key":"1:3","text":"<em>ٱلرَّحْمَـٰنِ</em> ٱلرَّحِيمِ"},
      {"verse_key":"19:45","text":"عَذَابٌ مِّنَ <em>ٱلرَّحْمَـٰنِ</em>"}
    ]}}
    ''');

    final hits = QuranSearchService.parseResults(body);
    expect(hits, hasLength(2));
    expect(hits[0].surah, 1);
    expect(hits[0].ayah, 3);
    expect(hits[1].surah, 19);
    expect(hits[1].ayah, 45);
    expect(hits[0].verseKey, '1:3');
  });

  test('the highlight markup is stripped from the text', () {
    // The API wraps the match in <em>. Rendering that raw would put literal
    // angle brackets in the middle of a verse.
    final body = jsonDecode('''
    {"search":{"results":[
      {"verse_key":"1:3","text":"<em>ٱلرَّحْمَـٰنِ</em> ٱلرَّحِيمِ"}
    ]}}
    ''');

    final text = QuranSearchService.parseResults(body).single.text;
    expect(text.contains('<'), isFalse);
    expect(text.contains('em>'), isFalse);
    expect(text.startsWith('ٱلرَّحْمَـٰنِ'), isTrue);
  });

  test('a malformed row is skipped, not fatal', () {
    // One bad entry must not cost the reader the other thirty-nine.
    final body = jsonDecode('''
    {"search":{"results":[
      {"verse_key":"1:3","text":"ok"},
      {"text":"no key"},
      {"verse_key":"nonsense","text":"bad key"},
      {"verse_key":"2:255","text":"also ok"}
    ]}}
    ''');

    final hits = QuranSearchService.parseResults(body);
    expect(hits.map((h) => h.verseKey), ['1:3', '2:255']);
  });

  test('no results is an empty list, not an error', () {
    final body = jsonDecode('{"search":{"results":[]}}');
    expect(QuranSearchService.parseResults(body), isEmpty);
  });

  test('an empty query never reaches the network', () async {
    // Guarded before the request so a cleared search box does not fire one.
    expect(await const QuranSearchService().search('   '), isEmpty);
  });
}
