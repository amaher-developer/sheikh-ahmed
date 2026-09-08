import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/adhan/adhan_scheduler.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_times_service.dart';

DailyPrayerTimes _fixedTimes(DateTime date) => DailyPrayerTimes(
  fajr: DateTime(date.year, date.month, date.day, 5),
  dhuhr: DateTime(date.year, date.month, date.day, 12),
  asr: DateTime(date.year, date.month, date.day, 15),
  maghrib: DateTime(date.year, date.month, date.day, 18),
  isha: DateTime(date.year, date.month, date.day, 20),
  // Present so the object is valid, and deliberately absent from `ordered`:
  // these are not prayers and must never become adhan alarm slots.
  sunrise: DateTime(date.year, date.month, date.day, 6),
  midnight: DateTime(date.year, date.month, date.day, 23, 30),
  lastThird: DateTime(date.year, date.month, date.day, 1, 30),
  imsak: DateTime(date.year, date.month, date.day, 4, 50),
);

void main() {
  test('lists every future prayer across the window, in order', () {
    final now = DateTime(2026, 9, 1, 0, 1);
    final list = upcomingPrayerInstants(timesForDay: _fixedTimes, now: now);

    expect(list, hasLength(7 * 5));
    // Strictly increasing — the native side registers one alarm per slot in
    // this order.
    for (var i = 1; i < list.length; i++) {
      expect(list[i].at.isAfter(list[i - 1].at), isTrue);
    }
    expect(list.first.labelKey, DailyPrayerTimes.labelKeys.first);
  });

  test('skips instants already past, which would fire immediately', () {
    // Mid-afternoon: today's Fajr and Dhuhr are gone, Asr onward remain.
    final now = DateTime(2026, 9, 1, 13, 0);
    final list = upcomingPrayerInstants(timesForDay: _fixedTimes, now: now);

    expect(list, hasLength(7 * 5 - 2));
    expect(list.every((p) => p.at.isAfter(now)), isTrue);
    expect(list.first.at, DateTime(2026, 9, 1, 15));
  });

  test('reserves exactly the slot count the native side clears', () {
    final now = DateTime(2026, 9, 1, 0, 1);
    final list = upcomingPrayerInstants(timesForDay: _fixedTimes, now: now);
    // A mismatch here would leave orphaned alarms behind when the schedule
    // shrinks, or cancel slots that were never set.
    expect(list.length, lessThanOrEqualTo(kAdhanAlarmSlots));
  });
}
