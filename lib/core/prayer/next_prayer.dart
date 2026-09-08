import 'prayer_times_service.dart';

/// The prayer to display as "next" right now, with everything the UI needs
/// to render the countdown and the progress ring.
class NextPrayerResult {
  /// Index into [DailyPrayerTimes.ordered] / [DailyPrayerTimes.labelKeys]
  /// (0=fajr .. 4=isha) — which row to highlight in the five-prayer list.
  final int prayerIndex;

  /// Absolute instant of the next occurrence of that prayer. When [now] is
  /// after today's Isha, this is *tomorrow's* Fajr, not today's.
  final DateTime prayerTime;

  /// Start of the current prayer "window" (the previous prayer boundary),
  /// used to compute the elapsed-fraction progress ring.
  final DateTime windowStart;

  final DateTime now;

  const NextPrayerResult({
    required this.prayerIndex,
    required this.prayerTime,
    required this.windowStart,
    required this.now,
  });

  String get labelKey => DailyPrayerTimes.labelKeys[prayerIndex];

  Duration get countdown => prayerTime.difference(now);

  /// 0..1 fraction of the way from [windowStart] to [prayerTime].
  double get progress {
    final totalSeconds = prayerTime.difference(windowStart).inSeconds;
    if (totalSeconds <= 0) return 1;
    final elapsedSeconds = now.difference(windowStart).inSeconds;
    final fraction = elapsedSeconds / totalSeconds;
    if (fraction < 0) return 0;
    if (fraction > 1) return 1;
    return fraction;
  }
}

/// Pure function: given today's prayer times and lazy accessors for
/// yesterday's/tomorrow's (only evaluated at the day boundaries where they're
/// actually needed), determines the next prayer relative to [now].
NextPrayerResult computeNextPrayer({
  required DateTime now,
  required DailyPrayerTimes today,
  required DailyPrayerTimes Function() computeYesterday,
  required DailyPrayerTimes Function() computeTomorrow,
}) {
  final times = today.ordered;

  for (var i = 0; i < times.length; i++) {
    if (now.isBefore(times[i])) {
      final windowStart = i == 0 ? computeYesterday().isha : times[i - 1];
      return NextPrayerResult(
        prayerIndex: i,
        prayerTime: times[i],
        windowStart: windowStart,
        now: now,
      );
    }
  }

  // now is after today's Isha — next prayer is tomorrow's Fajr.
  final tomorrowFajr = computeTomorrow().fajr;
  return NextPrayerResult(
    prayerIndex: 0,
    prayerTime: tomorrowFajr,
    windowStart: today.isha,
    now: now,
  );
}
