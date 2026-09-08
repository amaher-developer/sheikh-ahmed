import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/ayah_position.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_text_service.dart';

List<Ayah> _ayahs(List<int> lengths) => [
  for (var i = 0; i < lengths.length; i++)
    Ayah(numberInSurah: i + 1, text: 'x' * lengths[i], juz: 1, page: 1 + i ~/ 8),
];

void main() {
  group('fractionForAyah', () {
    test('ayah 1 is always fraction 0 — the top of the surah', () {
      final ayahs = _ayahs([10, 20, 30]);
      expect(fractionForAyah(ayahs, 1), 0);
    });

    test('the last ayah starts near, but not at, fraction 1', () {
      final ayahs = _ayahs([10, 10, 10, 10]);
      final f = fractionForAyah(ayahs, 4);
      expect(f, greaterThan(0.5));
      expect(f, lessThan(1));
    });

    test('splits proportionally to character length, not ayah count', () {
      // Ayah 2 is 9x longer than ayah 1, so ayah 3 should start much
      // further through the surah than "2 of 3" (~0.67) would suggest.
      final ayahs = _ayahs([10, 90, 10]);
      final f = fractionForAyah(ayahs, 3);
      expect(f, greaterThan(0.85));
    });

    test('an ayah number not in the surah falls back to the top', () {
      final ayahs = _ayahs([10, 10, 10]);
      expect(fractionForAyah(ayahs, 999), 0);
    });

    test('an empty ayah list is a degenerate case, not a crash', () {
      expect(fractionForAyah(const [], 5), 0);
    });
  });

  group('ayahForFraction', () {
    test('fraction 0 is ayah 1', () {
      final ayahs = _ayahs([10, 10, 10]);
      expect(ayahForFraction(ayahs, 0), 1);
    });

    test('fraction 1 is the last ayah', () {
      final ayahs = _ayahs([10, 10, 10]);
      expect(ayahForFraction(ayahs, 1), 3);
    });

    test('a fraction inside a long ayah resolves to that ayah', () {
      final ayahs = _ayahs([10, 80, 10]); // total 100
      // 50% through is well inside the 80-char second ayah (10..90).
      expect(ayahForFraction(ayahs, 0.5), 2);
    });
  });

  group('round trip', () {
    test('fractionForAyah -> ayahForFraction recovers the same ayah', () {
      final ayahs = _ayahs([15, 42, 7, 63, 20]);
      for (final ayah in ayahs) {
        final f = fractionForAyah(ayahs, ayah.numberInSurah);
        // Nudge slightly forward so we land inside the ayah's own span
        // rather than exactly on the boundary with the previous one.
        expect(ayahForFraction(ayahs, f + 0.001), ayah.numberInSurah);
      }
    });
  });
}
