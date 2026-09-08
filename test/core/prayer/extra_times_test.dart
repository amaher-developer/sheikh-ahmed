import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_times_service.dart';

void main() {
  // Cairo, a clear summer day.
  final times = const PrayerTimesService().calculate(
    date: DateTime(2026, 6, 15),
    coordinates: adhan.Coordinates(30.0444, 31.2357),
    method: adhan.CalculationMethod.egyptian,
    madhab: adhan.Madhab.shafi,
  );

  test('the five prayers stay the only entries in `ordered`', () {
    // This is the invariant that keeps the extra times safe to add. `ordered`
    // drives the adhan alarms, the notification slots, the home countdown and
    // the widget — letting sunrise or midnight in would call the adhan at
    // sunrise and again at 2am.
    expect(times.ordered, hasLength(5));
    expect(times.ordered, isNot(contains(times.sunrise)));
    expect(times.ordered, isNot(contains(times.midnight)));
    expect(times.ordered, isNot(contains(times.lastThird)));
    expect(times.ordered, isNot(contains(times.imsak)));
  });

  test('sunrise falls between fajr and dhuhr', () {
    expect(times.sunrise.isAfter(times.fajr), isTrue);
    expect(times.sunrise.isBefore(times.dhuhr), isTrue);
  });

  test('imsak precedes fajr by the stated offset', () {
    expect(
      times.fajr.difference(times.imsak),
      DailyPrayerTimes.imsakOffset,
    );
  });

  test('midnight and the last third fall inside the night', () {
    // Measured maghrib -> next fajr, so both land after maghrib, and the last
    // third comes after the midpoint. A naive same-day halfway point between
    // isha and fajr would put them before maghrib and fail here.
    expect(times.midnight.isAfter(times.maghrib), isTrue);
    expect(times.lastThird.isAfter(times.midnight), isTrue);
    expect(
      times.lastThird.isBefore(times.fajr.add(const Duration(days: 1))),
      isTrue,
    );
  });
}
