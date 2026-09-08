import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/home/weekly_mission_data.dart';
import 'package:sheikh_ahmed_app/core/ramadan/ramadan_status.dart';

void main() {
  group('ramadan detection', () {
    test('1 Ramadan 1447 is 18 February 2026', () {
      final s = ramadanStatusFor(DateTime(2026, 2, 18));
      expect(s.isRamadan, isTrue);
      expect(s.day, 1);
      expect(s.hijriYear, 1447);
    });

    test('the month ends and Shawwal is not Ramadan', () {
      expect(ramadanStatusFor(DateTime(2026, 3, 20)).isRamadan, isFalse);
    });

    test('an ordinary day in Rabi al-Awwal is not Ramadan', () {
      final s = ramadanStatusFor(DateTime(2026, 9, 6));
      expect(s.isRamadan, isFalse);
      expect(s.day, 0);
    });

    test('the offset shifts the month, for a local moonsighting', () {
      // The conversion is arithmetic while the month starts on a sighting, so
      // a country beginning a day early is ordinary, not an edge case.
      expect(ramadanStatusFor(DateTime(2026, 2, 17)).isRamadan, isFalse);
      expect(
        ramadanStatusFor(DateTime(2026, 2, 17), offsetDays: 1).isRamadan,
        isTrue,
      );
    });

    test('the last ten nights, and the odd ones among them', () {
      expect(ramadanStatusFor(DateTime(2026, 3, 10)).day, 21);
      expect(ramadanStatusFor(DateTime(2026, 3, 10)).isLastTen, isTrue);
      expect(ramadanStatusFor(DateTime(2026, 3, 10)).isOddNightOfLastTen, isTrue);
      // Night 22 is in the last ten but not an odd night.
      expect(ramadanStatusFor(DateTime(2026, 3, 11)).isOddNightOfLastTen, isFalse);
      // Day 12 is inside Ramadan but well before them.
      expect(ramadanStatusFor(DateTime(2026, 3, 1)).isLastTen, isFalse);
    });
  });

  group('missions', () {
    test('outside Ramadan the yearly list is used', () {
      final date = DateTime(2026, 9, 6);
      expect(missionFor(date, ramadan: false), weeklyMission(date));
    });

    test('inside Ramadan the Ramadan list is used', () {
      final m = missionFor(DateTime(2026, 3, 1), ramadan: true, day: 12);
      expect(kRamadanMissions.contains(m), isTrue);
      expect(m.titleKey.startsWith('weekly_mission.'), isTrue);
    });

    test('the mission advances once a week through the month', () {
      // Ramadan is about four and a half weeks, indexed by week of the month
      // rather than the year-wide counter — otherwise the month would open on
      // whichever entry the yearly cycle happened to reach.
      final week1 = missionFor(DateTime(2026, 2, 18), ramadan: true, day: 1);
      final alsoWeek1 = missionFor(DateTime(2026, 2, 24), ramadan: true, day: 7);
      final week2 = missionFor(DateTime(2026, 2, 25), ramadan: true, day: 8);
      expect(alsoWeek1, same(week1));
      expect(week2, isNot(same(week1)));
    });

    test('the storage key changes exactly when the mission does', () {
      String key(int day) =>
          missionKeyFor(DateTime(2026, 3, 1), ramadan: true, day: day);
      expect(key(1), key(7));
      expect(key(8), isNot(key(7)));
    });

    test('every Ramadan mission has both of its strings', () {
      for (final m in kRamadanMissions) {
        expect(m.titleKey.endsWith('_title'), isTrue, reason: m.titleKey);
        expect(m.detailKey.endsWith('_detail'), isTrue, reason: m.detailKey);
      }
    });
  });
}
