import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/juz_meta.dart';
import 'package:sheikh_ahmed_app/core/quran/page_starts.dart';
import 'package:sheikh_ahmed_app/core/quran/surah_meta.dart';

void main() {
  group('page starts', () {
    test('the Madani Mus\'haf is 604 pages, numbered straight through', () {
      expect(kPageStarts, hasLength(604));
      for (var i = 0; i < kPageStarts.length; i++) {
        expect(kPageStarts[i].page, i + 1);
      }
    });

    test('they run in recitation order and never go backwards', () {
      for (var i = 1; i < kPageStarts.length; i++) {
        final prev = kPageStarts[i - 1];
        final next = kPageStarts[i];
        final forward = next.surahNumber > prev.surahNumber ||
            (next.surahNumber == prev.surahNumber &&
                next.ayahNumber > prev.ayahNumber);
        expect(forward, isTrue, reason: 'page ${next.page}');
      }
    });

    test('the landmarks a reader would notice are where they should be', () {
      // Al-Kahf begins on page 293, Ya-Sin on 440, al-Mulk on 562.
      expect(pageForAyah(18, 1), 293);
      expect(pageForAyah(36, 1), 440);
      expect(pageForAyah(67, 1), 562);
      expect(pageForAyah(112, 1), 604);
    });

    test('beginning on a page is not the same as opening it', () {
      // The distinction the whole surah-heading rule rests on. Al-Kahf
      // *begins* on page 293, but that page *opens* with the tail of
      // al-Isra — so the page's own header names al-Isra, and the heading
      // for al-Kahf is drawn partway down.
      expect(pageForAyah(18, 1), 293);
      expect(pageStartFor(293)!.surahNumber, 17);
      expect(pageStartFor(293)!.ayahNumber, 105);

      // Al-Mulk is the other case: it both begins on page 562 and opens it.
      expect(pageStartFor(562)!.surahNumber, 67);
      expect(pageStartFor(562)!.ayahNumber, 1);
    });

    test('every surah opens on a page, and no page names a surah that is not one', () {
      for (final p in kPageStarts) {
        expect(p.surahNumber, inInclusiveRange(1, 114));
        final surah = surahByNumber(p.surahNumber);
        expect(p.ayahNumber, inInclusiveRange(1, surah.ayahCount));
      }
    });

    test('a page outside the Mus\'haf resolves to nothing', () {
      expect(pageStartFor(0), isNull);
      expect(pageStartFor(605), isNull);
      expect(pageStartFor(-3), isNull);
    });

    test('a verse resolves to the page it is printed on', () {
      expect(pageForAyah(1, 1), 1);
      expect(pageForAyah(2, 1), 2);
      // One verse before a page break is still on the earlier page.
      expect(pageForAyah(2, 5), 2);
      expect(pageForAyah(2, 6), 3);
      expect(pageForAyah(114, 6), 604);
    });

    test('the page and juz tables agree about where a juz begins', () {
      // Two tables generated from the same source, cross-checked against
      // each other: a juz start must land on the page that reports it.
      for (final juz in kJuzStarts) {
        final page = pageForAyah(juz.surahNumber, juz.ayahNumber);
        expect(page, isNotNull, reason: 'juz ${juz.number}');
        final start = pageStartFor(page!)!;
        final atOrBefore = start.surahNumber < juz.surahNumber ||
            (start.surahNumber == juz.surahNumber &&
                start.ayahNumber <= juz.ayahNumber);
        expect(atOrBefore, isTrue, reason: 'juz ${juz.number} on page $page');
      }
    });

    test('juz 1 and juz 16 land on the pages a printed copy prints them on', () {
      // Spot values a reader can check against paper: juz 2 opens page 22,
      // juz 16 opens page 302, juz 30 opens page 582.
      expect(pageForAyah(2, 142), 22);
      expect(pageForAyah(18, 75), 302);
      expect(pageForAyah(78, 1), 582);
    });
  });
}
