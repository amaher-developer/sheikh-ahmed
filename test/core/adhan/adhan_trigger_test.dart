import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/prayer/next_prayer.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_times_service.dart';

/// The adhan watcher decides *which* prayer just became due from
/// [NextPrayerResult]. `prayerTime` is always in the future, so the prayer
/// that just passed is `windowStart`, at index `prayerIndex - 1` wrapping
/// round to Isha. These tests pin that arithmetic down.
int justPassedIndex(NextPrayerResult next) =>
    (next.prayerIndex - 1 + DailyPrayerTimes.labelKeys.length) %
    DailyPrayerTimes.labelKeys.length;

DailyPrayerTimes _day(DateTime date) => DailyPrayerTimes(
  fajr: DateTime(date.year, date.month, date.day, 5, 0),
  dhuhr: DateTime(date.year, date.month, date.day, 12, 0),
  asr: DateTime(date.year, date.month, date.day, 15, 30),
  maghrib: DateTime(date.year, date.month, date.day, 18, 15),
  isha: DateTime(date.year, date.month, date.day, 19, 45),
  // Not prayers, and kept out of `ordered` — the adhan must never fire for
  // sunrise or in the middle of the night.
  sunrise: DateTime(date.year, date.month, date.day, 6, 20),
  midnight: DateTime(date.year, date.month, date.day, 23, 40),
  lastThird: DateTime(date.year, date.month, date.day, 1, 30),
  imsak: DateTime(date.year, date.month, date.day, 4, 50),
);

NextPrayerResult _at(DateTime now) {
  final today = _day(now);
  return computeNextPrayer(
    now: now,
    today: today,
    computeYesterday: () => _day(now.subtract(const Duration(days: 1))),
    computeTomorrow: () => _day(now.add(const Duration(days: 1))),
  );
}

void main() {
  final date = DateTime(2026, 8, 25);

  group('which prayer just became due', () {
    test('just after Fajr, the passed prayer is Fajr (not Dhuhr)', () {
      final next = _at(DateTime(date.year, date.month, date.day, 5, 0, 20));
      expect(next.prayerIndex, 1, reason: 'next is Dhuhr');
      expect(justPassedIndex(next), 0);
      expect(DailyPrayerTimes.labelKeys[justPassedIndex(next)], 'prayers.fajr');
    });

    test('just after Maghrib, the passed prayer is Maghrib', () {
      final next = _at(DateTime(date.year, date.month, date.day, 18, 15, 30));
      expect(justPassedIndex(next), 3);
      expect(
        DailyPrayerTimes.labelKeys[justPassedIndex(next)],
        'prayers.maghrib',
      );
    });

    test('after Isha the index wraps to Isha, not out of range', () {
      final next = _at(DateTime(date.year, date.month, date.day, 19, 46));
      expect(next.prayerIndex, 0, reason: 'next is tomorrow Fajr');
      expect(justPassedIndex(next), 4);
      expect(DailyPrayerTimes.labelKeys[justPassedIndex(next)], 'prayers.isha');
    });

    test('index is always within range across the whole day', () {
      for (var minute = 0; minute < 24 * 60; minute += 7) {
        final now = DateTime(
          date.year,
          date.month,
          date.day,
        ).add(Duration(minutes: minute));
        final i = justPassedIndex(_at(now));
        expect(i, inInclusiveRange(0, DailyPrayerTimes.labelKeys.length - 1));
      }
    });
  });

  group('the just-due window', () {
    // The watcher only sounds the adhan when `now - windowStart` is within
    // two minutes, so opening the app hours later stays silent.
    bool justDue(NextPrayerResult next) {
      final since = next.now.difference(next.windowStart);
      return !since.isNegative && since < const Duration(minutes: 2);
    }

    test('fires within two minutes of the prayer', () {
      expect(
        justDue(_at(DateTime(date.year, date.month, date.day, 12, 0, 30))),
        isTrue,
      );
    });

    test('does not fire long after the prayer', () {
      expect(
        justDue(_at(DateTime(date.year, date.month, date.day, 13, 30))),
        isFalse,
      );
    });

    test('does not fire before the prayer', () {
      expect(
        justDue(_at(DateTime(date.year, date.month, date.day, 11, 59))),
        isFalse,
      );
    });
  });
}
