import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/adhan/adhan_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/surah_meta.dart';

void main() {
  group('surahOfTheDay', () {
    test('is deterministic for the same calendar date', () {
      final date = DateTime(2026, 8, 25);
      final a = surahOfTheDay(date);
      final b = surahOfTheDay(DateTime(2026, 8, 25, 14, 30)); // same day, different time
      expect(a.number, b.number);
    });

    test('is always a real surah number', () {
      for (final date in [
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 15),
        DateTime(2027, 12, 31),
      ]) {
        final surah = surahOfTheDay(date);
        expect(surah.number, inInclusiveRange(1, 114));
        expect(kAllSurahs, contains(surah));
      }
    });

    test('varies across different dates', () {
      // Not a strict guarantee for any two arbitrary dates, but across 30
      // consecutive days we should see more than one distinct surah.
      final picks = <int>{};
      for (var d = 1; d <= 30; d++) {
        picks.add(surahOfTheDay(DateTime(2026, 3, d)).number);
      }
      expect(picks.length, greaterThan(1));
    });
  });
}
