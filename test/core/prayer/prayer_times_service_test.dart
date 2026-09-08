import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_times_service.dart';

void main() {
  const service = PrayerTimesService();

  // Cairo, a fixed mid-year date — avoids polar/equinox edge cases while
  // still exercising a real astronomical calculation end to end.
  final cairo = const Coordinates(30.0444, 31.2357);
  final date = DateTime(2026, 6, 15);

  group('PrayerTimesService.calculate', () {
    test('returns the five prayers in correct chronological order', () {
      final times = service.calculate(
        date: date,
        coordinates: cairo,
        method: CalculationMethod.egyptian,
        madhab: Madhab.shafi,
      );

      expect(times.fajr.isBefore(times.dhuhr), isTrue);
      expect(times.dhuhr.isBefore(times.asr), isTrue);
      expect(times.asr.isBefore(times.maghrib), isTrue);
      expect(times.maghrib.isBefore(times.isha), isTrue);
    });

    test('returns times in local time, not UTC', () {
      final times = service.calculate(
        date: date,
        coordinates: cairo,
        method: CalculationMethod.egyptian,
        madhab: Madhab.shafi,
      );

      // adhan_dart computes in UTC internally — the service must convert
      // before handing times back, otherwise every displayed clock is
      // wrong by the local UTC offset.
      expect(times.fajr.isUtc, isFalse);
      expect(times.dhuhr.isUtc, isFalse);
    });

    test(
      'produces a full-day spread of plausible prayer times for Cairo in June',
      () {
        final times = service.calculate(
          date: date,
          coordinates: cairo,
          method: CalculationMethod.egyptian,
          madhab: Madhab.shafi,
        );

        // Sanity bounds, not exact values — protects against a badly wired
        // calculation (e.g. wrong angle, wrong coordinate order) without
        // hardcoding a fragile golden time that library updates could break.
        expect(times.fajr.hour, inInclusiveRange(2, 5));
        expect(times.dhuhr.hour, inInclusiveRange(11, 13));
        expect(times.maghrib.hour, inInclusiveRange(18, 20));
        expect(times.isha.hour, inInclusiveRange(19, 22));
      },
    );

    test('ordered exposes fajr..isha in the same order as labelKeys', () {
      final times = service.calculate(
        date: date,
        coordinates: cairo,
        method: CalculationMethod.egyptian,
        madhab: Madhab.shafi,
      );

      expect(times.ordered, [
        times.fajr,
        times.dhuhr,
        times.asr,
        times.maghrib,
        times.isha,
      ]);
      expect(DailyPrayerTimes.labelKeys, [
        'prayers.fajr',
        'prayers.dhuhr',
        'prayers.asr',
        'prayers.maghrib',
        'prayers.isha',
      ]);
    });

    test(
      'Hanafi madhab yields a later (or equal) Asr than Shafi for the same inputs',
      () {
        final shafi = service.calculate(
          date: date,
          coordinates: cairo,
          method: CalculationMethod.egyptian,
          madhab: Madhab.shafi,
        );
        final hanafi = service.calculate(
          date: date,
          coordinates: cairo,
          method: CalculationMethod.egyptian,
          madhab: Madhab.hanafi,
        );

        expect(
          hanafi.asr.isAfter(shafi.asr) ||
              hanafi.asr.isAtSameMomentAs(shafi.asr),
          isTrue,
        );
      },
    );

    test(
      'different calculation methods produce different Fajr/Isha angles (different results)',
      () {
        final mwl = service.calculate(
          date: date,
          coordinates: cairo,
          method: CalculationMethod.muslimWorldLeague,
          madhab: Madhab.shafi,
        );
        final ummAlQura = service.calculate(
          date: date,
          coordinates: cairo,
          method: CalculationMethod.ummAlQura,
          madhab: Madhab.shafi,
        );

        // Muslim World League (17°) vs Umm al-Qura (fixed 90min interval)
        // use different conventions for Isha — they should not coincide.
        expect(mwl.isha.isAtSameMomentAs(ummAlQura.isha), isFalse);
      },
    );

    test('every supported CalculationMethod computes without throwing', () {
      for (final method in CalculationMethod.values) {
        expect(
          () => service.calculate(
            date: date,
            coordinates: cairo,
            method: method,
            madhab: Madhab.shafi,
          ),
          returnsNormally,
          reason: 'CalculationMethod.${method.name} should not throw',
        );
      }
    });
  });
}
