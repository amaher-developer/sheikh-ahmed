import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/hizb_meta.dart';
import 'package:sheikh_ahmed_app/core/quran/juz_meta.dart';

void main() {
  group('hizb quarters', () {
    test('the Mus\'haf is 240 quarters, numbered straight through', () {
      expect(kHizbQuarters, hasLength(240));
      for (var i = 0; i < kHizbQuarters.length; i++) {
        expect(kHizbQuarters[i].index, i + 1);
      }
    });

    test('they run in recitation order and never go backwards', () {
      for (var i = 1; i < kHizbQuarters.length; i++) {
        final prev = kHizbQuarters[i - 1];
        final next = kHizbQuarters[i];
        final forward = next.surahNumber > prev.surahNumber ||
            (next.surahNumber == prev.surahNumber &&
                next.ayahNumber > prev.ayahNumber);
        expect(forward, isTrue, reason: 'quarter ${next.index}');
      }
    });

    test('every odd hizb opens a juz', () {
      // Half a juz is a hizb, so juz n opens hizb 2n-1 — quarter 4(2n-2)+1.
      // If the table were shifted by one entry this is what would catch it.
      for (final juz in kJuzStarts) {
        final quarter = kHizbQuarters[(2 * juz.number - 2) * 4];
        expect(quarter.hizb, 2 * juz.number - 1, reason: 'juz ${juz.number}');
        expect(quarter.quarter, 0);
        expect(quarter.surahNumber, juz.surahNumber);
        expect(quarter.ayahNumber, juz.ayahNumber);
      }
    });

    test('hizb and quarter are derived, not stored off by one', () {
      expect(kHizbQuarters.first.hizb, 1);
      expect(kHizbQuarters.first.quarter, 0);
      expect(kHizbQuarters[3].hizb, 1);
      expect(kHizbQuarters[3].quarter, 3);
      expect(kHizbQuarters[4].hizb, 2);
      expect(kHizbQuarters[4].quarter, 0);
      expect(kHizbQuarters.last.hizb, 60);
      expect(kHizbQuarters.last.quarter, 3);
    });

    test('an ayah resolves to the quarter it is inside, not the next one', () {
      // Hizb 2 opens at al-Baqara 75.
      expect(hizbQuarterFor(2, 75)!.hizb, 2);
      expect(hizbQuarterFor(2, 75)!.quarter, 0);
      // One ayah earlier is still the previous quarter.
      expect(hizbQuarterFor(2, 74)!.index, 4);
      // The very first ayah of the Mus'haf.
      expect(hizbQuarterFor(1, 1)!.index, 1);
      // The last quarter runs to the end of the Mus'haf.
      expect(hizbQuarterFor(114, 6)!.index, 240);
    });
  });

  group('sajda spots', () {
    test('Hafs marks fifteen', () {
      expect(kSajdaSpots, hasLength(15));
    });

    test('al-Hajj carries two, which a de-duplicating table would lose', () {
      final hajj = kSajdaSpots.where((s) => s.surahNumber == 22).toList();
      expect(hajj.map((s) => s.ayahNumber).toList(), [18, 77]);
    });

    test('a verse is a sajda spot only at its exact ayah', () {
      expect(isSajdaAyah(32, 15), isTrue);
      expect(isSajdaAyah(32, 14), isFalse);
      expect(isSajdaAyah(96, 19), isTrue);
      expect(isSajdaAyah(2, 15), isFalse);
    });

    test('the عزائم are exactly the four the source marks', () {
      final obligatory = kSajdaSpots
          .where((s) => s.obligatory)
          .map((s) => '${s.surahNumber}:${s.ayahNumber}')
          .toList();
      expect(obligatory, ['32:15', '41:38', '53:62', '96:19']);
    });
  });
}
