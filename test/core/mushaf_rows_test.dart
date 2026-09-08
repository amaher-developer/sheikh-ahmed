import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_data.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_service.dart';
import 'package:sheikh_ahmed_app/core/quran/tajweed.dart';

/// A page whose words sit on [lines], with the first verse of [surah] starting
/// on the first of them.
dynamic pageBody(List<int> lines, {int surah = 2, int firstAyah = 1}) {
  final verses = <String>[];
  for (var i = 0; i < lines.length; i++) {
    verses.add(
      '{"verse_key":"$surah:${firstAyah + i}","juz_number":1,"words":['
      '{"code_v1":"g$i","line_number":${lines[i]},'
      '"text_uthmani":"كلمة","char_type_name":"word"}]}',
    );
  }
  return jsonDecode('{"verses":[${verses.join(',')}]}');
}

void main() {
  group('printed line numbers', () {
    test('a page reports the lines its words are on, gaps included', () {
      // Page 106: an-Nisa ends on line 5, al-Maida opens on line 8. The blank
      // 6 and 7 are the heading and its basmala, and they are only visible as
      // an absence.
      final page = MushafPageService.parseResponse(
        106,
        pageBody([1, 2, 3, 4, 5, 8, 9]),
      );

      expect(page.linesByNumber.keys.toList()..sort(), [1, 2, 3, 4, 5, 8, 9]);
      expect(page.linesByNumber[6], isNull);
      expect(page.linesByNumber[7], isNull);
    });

    test('a surah is reported only where its first verse begins', () {
      // Page 187 opens at line 2 with at-Tawbah 9:1 — one blank line above.
      final opening = MushafPageService.parseResponse(
        187,
        pageBody([2, 3, 4], surah: 9),
      );
      expect(opening.surahBeginningOn(2), 9);

      // A surah merely continuing onto the page took no heading with it.
      final continuing = MushafPageService.parseResponse(
        3,
        pageBody([1, 2, 3], surah: 2, firstAyah: 6),
      );
      expect(continuing.surahBeginningOn(1), isNull);
    });
  });

  group('printed rows', () {
    test('a page with no gaps is fifteen lines and nothing else', () {
      final page = MushafPageService.parseResponse(
        50,
        pageBody(List.generate(15, (i) => i + 1), firstAyah: 20),
      );
      final rows = page.rows;
      expect(rows, hasLength(15));
      expect(rows.every((r) => r.words != null), isTrue);
    });

    test('two blank lines print a heading and its basmala', () {
      // Page 106: al-Maida opens on line 8 behind two blanks.
      final page = MushafPageService.parseResponse(
        106,
        pageBody([1, 2, 3, 4, 5, 8, 9], surah: 4),
      );
      // The verses after the gap belong to the new surah, not to an-Nisa.
      final maida = MushafPageService.parseResponse(
        106,
        pageBody(List.generate(8, (i) => i + 8), surah: 5),
      );
      final merged = MushafPageData(
        page: 106,
        juz: 6,
        verseKeys: const [],
        words: [
          ...page.words.where((w) => w.line <= 5),
          ...maida.words,
        ],
      );

      final rows = merged.rows;
      expect(rows, hasLength(kLinesPerPage));
      expect(rows.take(7).map((r) => r.words != null).toList(), [
        true, true, true, true, true, // an-Nisa, lines 1..5
        false, false, // heading, basmala
      ]);
      expect(rows[5].surahHeading, 5);
      expect(rows[6].isBasmala, isTrue);
      expect(rows.skip(7).every((r) => r.words != null), isTrue);
    });

    test('one blank line prints the heading alone', () {
      // At-Tawbah, page 187: the only surah with no basmala, and the page
      // leaves exactly one line for it.
      final page = MushafPageService.parseResponse(
        187,
        pageBody(List.generate(14, (i) => i + 2), surah: 9),
      );

      final rows = page.rows;
      expect(rows.first.surahHeading, 9);
      expect(rows.any((r) => r.isBasmala), isFalse);
      expect(rows, hasLength(kLinesPerPage));
    });

    test('a blank line that opens no surah stays a blank line', () {
      // A gap mid-page with the same surah continuing after it is not a
      // heading — printing one there would invent a surah break. It is
      // still a line of the page, though, and closing it up would slide
      // everything below it a line out of place.
      final page = MushafPageService.parseResponse(
        3,
        pageBody([1, 2, 5, 6], surah: 2, firstAyah: 6),
      );

      final rows = page.rows;
      expect(rows, hasLength(kLinesPerPage));
      expect(rows.any((r) => r.surahHeading != null), isFalse);
      expect(rows.any((r) => r.isBasmala), isFalse);
      // Lines 3 and 4 are blank, and so are 7..15.
      expect(rows[2].isBlank, isTrue);
      expect(rows[3].isBlank, isTrue);
      expect(rows[4].words, isNotNull);
      expect(rows.where((r) => r.isBlank), hasLength(11));
    });

    test('a page ending early keeps its empty last lines', () {
      // Page 594: al-Balad ends on line 14 and line 15 is left blank.
      // Dropping it left fourteen rows, which read as a short page and
      // got centred — the text pushed down from the top with a band of
      // white above it. That is the page that looked wrong on the phone.
      final page = MushafPageService.parseResponse(
        594,
        pageBody(List.generate(14, (i) => i + 1), surah: 90, firstAyah: 2),
      );

      final rows = page.rows;
      expect(rows, hasLength(kLinesPerPage));
      expect(rows.last.isBlank, isTrue);
      expect(rows.take(14).every((r) => r.words != null), isTrue);
    });

    test('the first two pages keep their own shorter frame', () {
      // Al-Fatiha sits in a decorative frame of eight lines, not on the
      // fifteen-line grid. Padding it out would put seven empty lines
      // underneath it.
      final page = MushafPageService.parseResponse(
        1,
        pageBody(List.generate(7, (i) => i + 2), surah: 1),
      );

      final rows = page.rows;
      expect(rows, hasLength(8));
      expect(rows.first.surahHeading, 1);
      expect(rows.any((r) => r.isBlank), isFalse);
    });

    test('a page that opens a surah on its first line still gets a heading', () {
      // Al-Fatiha, page 1: one blank line above, and its basmala is verse 1
      // so it is already among the words.
      final page = MushafPageService.parseResponse(
        1,
        pageBody([2, 3, 4, 5, 6], surah: 1),
      );

      final rows = page.rows;
      expect(rows.first.surahHeading, 1);
      expect(rows.any((r) => r.isBasmala), isFalse);
    });

    test('an empty page yields no rows rather than throwing', () {
      final page = MushafPageService.parseResponse(9, pageBody([]));
      expect(page.rows, isEmpty);
    });
  });

  group('tajweed markup', () {
    test('splits a verse into plain and ruled runs', () {
      final spans = parseTajweed(
        'ذ<tajweed class=madda_normal>َٲ</tajweed>لِكَ '
        '<tajweed class=ham_wasl>ٱ</tajweed>لْكِتَٰبُ',
      );

      expect(spans.map((s) => s.rule).toList(), [
        null,
        'madda_normal',
        null,
        'ham_wasl',
        null,
      ]);
      expect(spans.map((s) => s.text).join(), contains('لِكَ'));
    });

    test('the ayah marker is not treated as a rule', () {
      // The source wraps it like one. Colouring it would put a tajweed colour
      // on a verse number.
      final spans = parseTajweed('نَاسِ <tajweed class=end>٦</tajweed>');
      expect(spans.every((s) => s.rule == null), isTrue);
      expect(spans.map((s) => s.text).join(), contains('٦'));
    });

    test('no markup at all is a single plain run', () {
      final spans = parseTajweed('قُلْ هُوَ ٱللَّهُ أَحَدٌ');
      expect(spans, hasLength(1));
      expect(spans.single.rule, isNull);
    });

    test('the legend lists only the rules this verse uses, once each', () {
      final spans = parseTajweed(
        '<tajweed class=ghunnah>م</tajweed>ا'
        '<tajweed class=qalaqah>ق</tajweed>ب'
        '<tajweed class=ghunnah>ن</tajweed>',
      );
      expect(rulesIn(spans), ['ghunnah', 'qalaqah']);
    });

    test('every rule the source emits has a colour and a name', () {
      // A rule with no entry would render in the ordinary ink and quietly
      // look like plain text — the reader would never know it was missed.
      const seenInTheQuran = [
        'ham_wasl',
        'madda_normal',
        'slnt',
        'ghunnah',
        'madda_obligatory',
        'qalaqah',
        'ikhafa',
        'madda_permissible',
        'laam_shamsiyah',
        'idgham_ghunnah',
        'idgham_wo_ghunnah',
        'iqlab',
        'madda_necessary',
        'idgham_shafawi',
        'ikhafa_shafawi',
      ];
      for (final rule in seenInTheQuran) {
        expect(kTajweedRules.containsKey(rule), isTrue, reason: rule);
        expect(kTajweedRules[rule]!.nameKey.startsWith('tajweed.'), isTrue);
      }
    });

    test('stray markup never reaches the screen', () {
      // A tag shape the pattern does not know must not render as literal
      // angle brackets in the middle of a verse.
      final spans = parseTajweed('ا<b>ب</b>ج');
      expect(spans.map((s) => s.text).join().contains('<'), isFalse);
    });
  });
}
