import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_text_service.dart';

/// Verse text exactly as api.alquran.cloud returns it (Uthmani script),
/// captured from live responses — the Basmala is prefixed onto ayah 1 of
/// every surah except At-Tawbah, which the reader must not render twice.
const _baqarahAyah1 =
    'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ الۤمۤ';
const _falaqAyah1 =
    'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ قُلۡ أَعُوذُ بِرَبِّ ٱلۡفَلَقِ';
const _ikhlasAyah1 =
    'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ قُلۡ هُوَ ٱللَّهُ أَحَدٌ';
const _fatihaAyah1 = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ';
const _tawbahAyah1 =
    'بَرَاۤءَةࣱ مِّنَ ٱللَّهِ وَرَسُولِهِۦۤ إِلَى ٱلَّذِینَ عَـٰهَدتُّم';

void main() {
  group('QuranTextService.parseAyahs', () {
    test('strips the prefixed Basmala from ayah 1 of an ordinary surah', () {
      final ayahs = QuranTextService.parseAyahs(2, [
        {'numberInSurah': 1, 'text': _baqarahAyah1, 'juz': 1},
      ]);
      expect(ayahs.single.text, 'الۤمۤ');
    });

    test('strips the Basmala for the short muawwidhat surahs too', () {
      final falaq = QuranTextService.parseAyahs(113, [
        {'numberInSurah': 1, 'text': _falaqAyah1, 'juz': 30},
      ]);
      expect(falaq.single.text, 'قُلۡ أَعُوذُ بِرَبِّ ٱلۡفَلَقِ');

      final ikhlas = QuranTextService.parseAyahs(112, [
        {'numberInSurah': 1, 'text': _ikhlasAyah1, 'juz': 30},
      ]);
      expect(ikhlas.single.text, 'قُلۡ هُوَ ٱللَّهُ أَحَدٌ');
    });

    test('keeps Al-Fatihah ayah 1 intact — the Basmala is the verse', () {
      final ayahs = QuranTextService.parseAyahs(1, [
        {'numberInSurah': 1, 'text': _fatihaAyah1, 'juz': 1},
      ]);
      expect(ayahs.single.text, _fatihaAyah1);
    });

    test('leaves At-Tawbah ayah 1 intact — it has no Basmala', () {
      final ayahs = QuranTextService.parseAyahs(9, [
        {'numberInSurah': 1, 'text': _tawbahAyah1, 'juz': 10},
      ]);
      expect(ayahs.single.text, _tawbahAyah1);
    });

    test('never touches ayahs after the first', () {
      final ayahs = QuranTextService.parseAyahs(2, [
        {'numberInSurah': 1, 'text': _baqarahAyah1, 'juz': 1},
        {'numberInSurah': 2, 'text': 'ذَ ٰلِكَ ٱلۡكِتَـٰبُ', 'juz': 1},
      ]);
      expect(ayahs[1].text, 'ذَ ٰلِكَ ٱلۡكِتَـٰبُ');
    });

    group('with a translation edition', () {
      test('pairs each ayah with its translation by index', () {
        final ayahs = QuranTextService.parseAyahs(
          112,
          [
            {'numberInSurah': 1, 'text': _ikhlasAyah1, 'juz': 30},
            {'numberInSurah': 2, 'text': 'ٱللَّهُ ٱلصَّمَدُ', 'juz': 30},
          ],
          translationJson: [
            {'text': 'Say, "He is Allah, [who is] One,'},
            {'text': 'Allah, the Eternal Refuge.'},
          ],
        );

        expect(ayahs[0].translation, 'Say, "He is Allah, [who is] One,');
        expect(ayahs[1].translation, 'Allah, the Eternal Refuge.');
      });

      test('still strips the Basmala from the Arabic side only', () {
        final ayahs = QuranTextService.parseAyahs(
          112,
          [
            {'numberInSurah': 1, 'text': _ikhlasAyah1, 'juz': 30},
          ],
          translationJson: [
            {'text': 'Say, "He is Allah, [who is] One,'},
          ],
        );

        expect(ayahs.single.text, 'قُلۡ هُوَ ٱللَّهُ أَحَدٌ');
        expect(ayahs.single.translation, 'Say, "He is Allah, [who is] One,');
      });

      test('is null when no translationJson is given', () {
        final ayahs = QuranTextService.parseAyahs(112, [
          {'numberInSurah': 1, 'text': _ikhlasAyah1, 'juz': 30},
        ]);
        expect(ayahs.single.translation, isNull);
      });
    });
  });
}
