import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/prayer/next_prayer.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_times_service.dart';

void main() {
  // Fixed, controlled fixture — independent of the real astronomical
  // calculation so these tests exercise only the pure next-prayer logic.
  final today = DailyPrayerTimes(
    fajr: DateTime(2026, 6, 15, 4, 0),
    dhuhr: DateTime(2026, 6, 15, 12, 0),
    asr: DateTime(2026, 6, 15, 15, 30),
    maghrib: DateTime(2026, 6, 15, 19, 0),
    isha: DateTime(2026, 6, 15, 20, 30),
    sunrise: DateTime(2026, 6, 15, 5, 30),
    midnight: DateTime(2026, 6, 15, 23, 30),
    lastThird: DateTime(2026, 6, 15, 1, 20),
    imsak: DateTime(2026, 6, 15, 3, 50),
  );

  final yesterday = DailyPrayerTimes(
    fajr: DateTime(2026, 6, 14, 4, 0),
    dhuhr: DateTime(2026, 6, 14, 12, 0),
    asr: DateTime(2026, 6, 14, 15, 30),
    maghrib: DateTime(2026, 6, 14, 19, 0),
    isha: DateTime(2026, 6, 14, 20, 30),
    sunrise: DateTime(2026, 6, 14, 5, 30),
    midnight: DateTime(2026, 6, 14, 23, 30),
    lastThird: DateTime(2026, 6, 14, 1, 20),
    imsak: DateTime(2026, 6, 14, 3, 50),
  );

  final tomorrow = DailyPrayerTimes(
    fajr: DateTime(2026, 6, 16, 4, 0),
    dhuhr: DateTime(2026, 6, 16, 12, 0),
    asr: DateTime(2026, 6, 16, 15, 30),
    maghrib: DateTime(2026, 6, 16, 19, 0),
    isha: DateTime(2026, 6, 16, 20, 30),
    sunrise: DateTime(2026, 6, 16, 5, 30),
    midnight: DateTime(2026, 6, 16, 23, 30),
    lastThird: DateTime(2026, 6, 16, 1, 20),
    imsak: DateTime(2026, 6, 16, 3, 50),
  );

  NextPrayerResult compute(DateTime now) => computeNextPrayer(
    now: now,
    today: today,
    computeYesterday: () => yesterday,
    computeTomorrow: () => tomorrow,
  );

  group('computeNextPrayer — mid-day windows', () {
    test('between Fajr and Dhuhr, next is Dhuhr (index 1)', () {
      final result = compute(DateTime(2026, 6, 15, 8, 0));
      expect(result.prayerIndex, 1);
      expect(result.prayerTime, today.dhuhr);
      expect(result.windowStart, today.fajr);
    });

    test('between Dhuhr and Asr, next is Asr (index 2)', () {
      final result = compute(DateTime(2026, 6, 15, 13, 0));
      expect(result.prayerIndex, 2);
      expect(result.prayerTime, today.asr);
      expect(result.windowStart, today.dhuhr);
    });

    test('between Asr and Maghrib, next is Maghrib (index 3)', () {
      final result = compute(DateTime(2026, 6, 15, 17, 0));
      expect(result.prayerIndex, 3);
      expect(result.prayerTime, today.maghrib);
      expect(result.windowStart, today.asr);
    });

    test('between Maghrib and Isha, next is Isha (index 4)', () {
      final result = compute(DateTime(2026, 6, 15, 19, 30));
      expect(result.prayerIndex, 4);
      expect(result.prayerTime, today.isha);
      expect(result.windowStart, today.maghrib);
    });
  });

  group('computeNextPrayer — day boundaries', () {
    test(
      'before Fajr, next is today\'s Fajr (index 0) with window from yesterday\'s Isha',
      () {
        final result = compute(DateTime(2026, 6, 15, 2, 0));
        expect(result.prayerIndex, 0);
        expect(result.prayerTime, today.fajr);
        expect(result.windowStart, yesterday.isha);
      },
    );

    test(
      'after Isha, next is tomorrow\'s Fajr (index 0) with window from today\'s Isha',
      () {
        final result = compute(DateTime(2026, 6, 15, 22, 0));
        expect(result.prayerIndex, 0);
        expect(result.prayerTime, tomorrow.fajr);
        expect(result.windowStart, today.isha);
      },
    );

    test(
      'exactly at a prayer time, that prayer is no longer "next" (isBefore is strict)',
      () {
        final result = compute(today.dhuhr);
        // now == dhuhr is not before dhuhr, so it rolls to asr
        expect(result.prayerIndex, 2);
        expect(result.prayerTime, today.asr);
      },
    );
  });

  group('NextPrayerResult.countdown', () {
    test('is the difference between now and the target prayer time', () {
      final now = DateTime(2026, 6, 15, 11, 0);
      final result = compute(now);
      expect(result.countdown, const Duration(hours: 1));
    });
  });

  group('NextPrayerResult.progress', () {
    test('is 0 at the exact start of the window', () {
      final result = compute(today.fajr);
      // now == fajr means we've rolled forward to the Fajr->Dhuhr window
      expect(result.windowStart, today.fajr);
      expect(result.progress, 0);
    });

    test('is 0.5 exactly halfway through the window', () {
      // Fajr..Dhuhr window is 8 hours (04:00 -> 12:00); halfway is 08:00
      final result = compute(DateTime(2026, 6, 15, 8, 0));
      expect(result.progress, closeTo(0.5, 0.001));
    });

    test(
      'is clamped to 1 and never throws when now is past the target (defensive)',
      () {
        // windowStart == prayerTime would divide by zero without the guard;
        // exercise the clamp path directly via a manufactured degenerate case.
        final result = NextPrayerResult(
          prayerIndex: 0,
          prayerTime: DateTime(2026, 6, 15, 12, 0),
          windowStart: DateTime(2026, 6, 15, 12, 0),
          now: DateTime(2026, 6, 15, 12, 0),
        );
        expect(result.progress, 1);
      },
    );

    test('labelKey matches prayerIndex', () {
      final result = compute(
        DateTime(2026, 6, 15, 17, 0),
      ); // -> maghrib, index 3
      expect(result.labelKey, 'prayers.maghrib');
    });
  });
}
