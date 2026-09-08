import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_data.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_service.dart';
import 'package:sheikh_ahmed_app/core/quran/surah_meta.dart';

void main() {
  // Page 42 opens in juz 3 while the page before it is still in juz 2, so a
  // page that took its juz from the wrong verse would be wrong here.
  final body = jsonDecode('''
  {"verses":[
    {"verse_key":"2:253","juz_number":3,"words":[
      {"code_v1":"A","line_number":1,"text_uthmani":"تِلْكَ","char_type_name":"word"}
    ]},
    {"verse_key":"2:254","juz_number":3,"words":[
      {"code_v1":"B","line_number":2,"text_uthmani":"يَٰٓأَيُّهَا","char_type_name":"word"}
    ]}
  ]}
  ''');

  test('the page carries the juz it opens in', () {
    final page = MushafPageService.parseResponse(42, body);
    expect(page.juz, 3);
  });

  test('a page crossing a juz boundary is labelled by where it starts', () {
    // The printed header names one juz, not both — and it is the one the page
    // opens in, matching the paper page.
    final crossing = jsonDecode('''
    {"verses":[
      {"verse_key":"2:141","juz_number":1,"words":[
        {"code_v1":"A","line_number":1,"text_uthmani":"تِلْكَ","char_type_name":"word"}
      ]},
      {"verse_key":"2:142","juz_number":2,"words":[
        {"code_v1":"B","line_number":8,"text_uthmani":"سَيَقُولُ","char_type_name":"word"}
      ]}
    ]}
    ''');
    expect(MushafPageService.parseResponse(21, crossing).juz, 1);
  });

  test('the juz survives the round trip through storage', () {
    final page = MushafPageService.parseResponse(42, body);
    final back = MushafPageData.fromJson(
      jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>,
    );
    expect(back.juz, 3);
  });

  test('an entry stored before pages had a juz reads back as unknown', () {
    // Not a crash. The header simply omits it, and the page refetches under
    // the new cache generation.
    final legacy = MushafPageData.fromJson({
      'p': 42,
      'k': ['2:253'],
      'w': [
        {'g': 'A', 'l': 1, 's': 2, 'a': 253},
      ],
    });
    expect(legacy.juz, 0);
  });

  test('every surah knows whether it is Makki or Madani', () {
    // The header prints it, so a gap would show as a blank on the page.
    expect(kAllSurahs, hasLength(114));
    expect(surahByNumber(1).meccan, isTrue);
    expect(surahByNumber(2).meccan, isFalse);
    // Al-Muddaththir is Makki; An-Nur is Madani — two the header will show.
    expect(surahByNumber(74).meccan, isTrue);
    expect(surahByNumber(24).meccan, isFalse);
  });

  test('the page prints surah, place and juz, and the number below', () {
    final view = File(
      'lib/features/quran/presentation/mushaf_page_view.dart',
    ).readAsStringSync();

    expect(view.contains('_PageHeader'), isTrue);
    expect(view.contains('quran_screen.meccan'), isTrue);
    expect(view.contains('quran_screen.medinan'), isTrue);
    expect(view.contains('quran_screen.juz_n'), isTrue);
    // The header is pinned RTL: the surah belongs on the right and the juz on
    // the left whatever language the interface is in.
    expect(view.contains('material.TextDirection.rtl'), isTrue);
  });

  test('panning is only enabled once zoomed in', () {
    // At rest the page has to hand its horizontal drags to the PageView, or
    // turning the page stops working.
    final reader = File(
      'lib/features/quran/presentation/surah_reader_screen.dart',
    ).readAsStringSync();
    expect(reader.contains('panEnabled: _zoomed'), isTrue);
  });

  test('only a full page is spread to fill the height', () {
    // The vertical twin of the justification rule. Pages 1 and 2 sit in a
    // narrow frame and carry a handful of lines; spacing those evenly down a
    // phone screen left gaps between them you could park a line in.
    final view = File(
      'lib/features/quran/presentation/mushaf_page_view.dart',
    ).readAsStringSync();

    // Counted in printed slots, not lines of verse: a page that opens a
    // surah gives two of its fifteen to the heading and the basmala, and
    // counting only its thirteen lines called a full page a short one.
    expect(view.contains('rows.length >= kLinesPerPage'), isTrue);
    expect(view.contains('lines.length >= kLinesPerPage'), isFalse);
    expect(view.contains('MainAxisAlignment.spaceEvenly'), isTrue);
    expect(view.contains('MainAxisAlignment.center'), isTrue);
    expect(
      File('lib/core/quran/mushaf_page_data.dart')
          .readAsStringSync()
          .contains('const kLinesPerPage = 15'),
      isTrue,
    );
  });


  group('magnification', () {
    final reader = File(
      'lib/features/quran/presentation/surah_reader_screen.dart',
    ).readAsStringSync();

    test('zoom is pinch and nothing else', () {
      // The saved zoom and its buttons were removed on the phone they were
      // made for. Applied to every page, they left no page un-magnified —
      // and a magnified page pans instead of turning, so page turning
      // stopped working with no obvious way to get it back.
      final providers = File(
        'lib/core/quran/quran_providers.dart',
      ).readAsStringSync();

      expect(reader.contains('mushafZoomProvider'), isFalse);
      expect(reader.contains('_ZoomControls'), isFalse);
      expect(reader.contains('_ZoomButton'), isFalse);
      expect(providers.contains('MushafZoomNotifier'), isFalse);
      expect(providers.contains('kMaxMushafZoom'), isFalse);

      expect(reader.contains('InteractiveViewer('), isTrue);
    });

    test('panning is only on once the page is magnified', () {
      // At rest the page has to hand its horizontal drags to the pager
      // underneath, or the InteractiveViewer swallows them and the page
      // never turns.
      expect(reader.contains('panEnabled: _zoomed'), isTrue);
    });

    test('a page magnified and swiped away does not stay magnified', () {
      // Coming back to a page still zoomed in, the reader could not swipe
      // off it again — the pan had the gesture.
      expect(
        reader.contains('if (old.isCurrent && !widget.isCurrent && _zoomed)'),
        isTrue,
      );
    });

    test('the two-page spread is gone', () {
      // Removed on the phone it was made for: two pages side by side on a
      // handset halves the text, which is the opposite of what a reader
      // reaching for the zoom wants.
      expect(reader.contains('twoPageSpreadProvider'), isFalse);
      expect(reader.contains("value: 'spread'"), isFalse);

      final providers = File(
        'lib/core/quran/quran_providers.dart',
      ).readAsStringSync();
      expect(providers.contains('TwoPageSpread'), isFalse);
    });
  });
}
