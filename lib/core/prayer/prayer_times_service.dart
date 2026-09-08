import 'package:adhan_dart/adhan_dart.dart' as adhan;

/// The five daily obligatory prayer times for one calendar date, already
/// converted to local time. Deliberately excludes sunrise/ishaBefore/
/// fajrAfter — the UI only ever shows the five.
class DailyPrayerTimes {
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// Times that are *not* prayers, and deliberately kept out of [ordered].
  ///
  /// Sunrise ends the Fajr window, midnight and the last third mark the
  /// night for qiyam, and imsak is the Ramadan cut-off for eating. None of
  /// them takes an adhan, and [ordered] drives the adhan alarms, the widget,
  /// the countdown and the notification slots — adding them there would call
  /// the adhan at sunrise and at 2am.
  final DateTime sunrise;
  final DateTime midnight;
  final DateTime lastThird;

  /// Fajr minus [imsakOffset]. Convention rather than astronomy: the fast
  /// begins at Fajr, and the offset is the customary caution before it.
  final DateTime imsak;

  static const imsakOffset = Duration(minutes: 10);

  const DailyPrayerTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.sunrise,
    required this.midnight,
    required this.lastThird,
    required this.imsak,
  });

  /// Fajr..Isha in daily order — index N here matches [labelKeys][N].
  List<DateTime> get ordered => [fajr, dhuhr, asr, maghrib, isha];

  static const labelKeys = [
    'prayers.fajr',
    'prayers.dhuhr',
    'prayers.asr',
    'prayers.maghrib',
    'prayers.isha',
  ];
}

/// Wraps `adhan_dart`'s astronomical calculation behind our own small,
/// stable API — pure computation, no I/O, works fully offline.
class PrayerTimesService {
  const PrayerTimesService();

  DailyPrayerTimes calculate({
    required DateTime date,
    required adhan.Coordinates coordinates,
    required adhan.CalculationMethod method,
    required adhan.Madhab madhab,
  }) {
    final params = _paramsFor(method)..madhab = madhab;
    final times = adhan.PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: params,
      precision: true,
    );

    // adhan_dart returns UTC DateTimes (constructed via DateTime.utc(...)
    // internally) — convert to local so display/comparisons use the
    // device's wall-clock time.
    // Midnight and the last third are measured from *this* maghrib to the
    // *next* day's fajr, which is why they come from SunnahTimes rather than
    // from a naive halfway point between isha and fajr on the same date.
    final sunnah = adhan.SunnahTimes(times, precision: true);
    final fajrLocal = times.fajr.toLocal();

    return DailyPrayerTimes(
      fajr: fajrLocal,
      dhuhr: times.dhuhr.toLocal(),
      asr: times.asr.toLocal(),
      maghrib: times.maghrib.toLocal(),
      isha: times.isha.toLocal(),
      sunrise: times.sunrise.toLocal(),
      midnight: sunnah.middleOfTheNight.toLocal(),
      lastThird: sunnah.lastThirdOfTheNight.toLocal(),
      imsak: fajrLocal.subtract(DailyPrayerTimes.imsakOffset),
    );
  }

  static adhan.CalculationParameters _paramsFor(
    adhan.CalculationMethod method,
  ) {
    switch (method) {
      case adhan.CalculationMethod.dubai:
        return adhan.CalculationMethodParameters.dubai();
      case adhan.CalculationMethod.egyptian:
        return adhan.CalculationMethodParameters.egyptian();
      case adhan.CalculationMethod.karachi:
        return adhan.CalculationMethodParameters.karachi();
      case adhan.CalculationMethod.kuwait:
        return adhan.CalculationMethodParameters.kuwait();
      case adhan.CalculationMethod.moonsightingCommittee:
        return adhan.CalculationMethodParameters.moonsightingCommittee();
      case adhan.CalculationMethod.morocco:
        return adhan.CalculationMethodParameters.morocco();
      case adhan.CalculationMethod.muslimWorldLeague:
        return adhan.CalculationMethodParameters.muslimWorldLeague();
      case adhan.CalculationMethod.northAmerica:
        return adhan.CalculationMethodParameters.northAmerica();
      case adhan.CalculationMethod.other:
        return adhan.CalculationMethodParameters.other();
      case adhan.CalculationMethod.qatar:
        return adhan.CalculationMethodParameters.qatar();
      case adhan.CalculationMethod.singapore:
        return adhan.CalculationMethodParameters.singapore();
      case adhan.CalculationMethod.tehran:
        return adhan.CalculationMethodParameters.tehran();
      case adhan.CalculationMethod.turkiye:
        return adhan.CalculationMethodParameters.turkiye();
      case adhan.CalculationMethod.ummAlQura:
        return adhan.CalculationMethodParameters.ummAlQura();
    }
  }
}
