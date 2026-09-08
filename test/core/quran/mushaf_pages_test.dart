import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_pages.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_text_service.dart';

Ayah _ayah(int n, int page) =>
    Ayah(numberInSurah: n, text: 'آية $n', juz: 1, page: page);

void main() {
  test('splits at the printed Mus\'haf page boundaries', () {
    final pages = splitIntoMushafPages([
      _ayah(1, 2),
      _ayah(2, 2),
      _ayah(3, 3),
      _ayah(4, 3),
      _ayah(5, 3),
      _ayah(6, 4),
    ]);

    expect(pages.map((p) => p.number), [2, 3, 4]);
    expect(pages.map((p) => p.ayahs.length), [2, 3, 1]);
    // Every ayah lands on exactly one page — none dropped, none duplicated.
    expect(
      pages.expand((p) => p.ayahs).map((a) => a.numberInSurah),
      [1, 2, 3, 4, 5, 6],
    );
  });

  test('only the page opening the surah is marked as such', () {
    final pages = splitIntoMushafPages([
      _ayah(1, 2),
      _ayah(2, 3),
    ]);

    expect(pages.first.startsSurah, isTrue);
    expect(pages.last.startsSurah, isFalse);
  });

  test('a surah starting mid-page still opens on its first page', () {
    // Ad-Duha begins partway down page 596; its first ayah is still ayah 1.
    final pages = splitIntoMushafPages([_ayah(1, 596), _ayah(2, 596)]);
    expect(pages, hasLength(1));
    expect(pages.single.number, 596);
    expect(pages.single.startsSurah, isTrue);
  });

  test('collapses to one page when the edition reports no page numbers', () {
    // page 0 is the documented fallback in QuranTextService.parseAyahs —
    // pagination is lost but the text must still render.
    final pages = splitIntoMushafPages([_ayah(1, 0), _ayah(2, 0)]);
    expect(pages, hasLength(1));
    expect(pages.single.ayahs, hasLength(2));
  });

  test('empty input yields no pages rather than one empty page', () {
    expect(splitIntoMushafPages([]), isEmpty);
  });

  test('finds the page holding a given ayah, defaulting to the first', () {
    final pages = splitIntoMushafPages([
      _ayah(1, 2),
      _ayah(2, 3),
      _ayah(3, 3),
    ]);

    expect(mushafPageIndexForAyah(pages, 1), 0);
    expect(mushafPageIndexForAyah(pages, 3), 1);
    expect(mushafPageIndexForAyah(pages, 99), 0);
  });
}
