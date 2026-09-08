import 'package:hijri/hijri_calendar.dart';

/// Where today sits in Ramadan, if at all.
class RamadanStatus {
  final bool isRamadan;

  /// 1..30, or 0 outside Ramadan.
  final int day;

  final int hijriYear;

  /// Days until 1 Ramadan. Zero once it has started, and only meaningful in
  /// the month or so before — the home screen uses it to decide when to start
  /// mentioning it at all.
  final int daysUntilStart;

  const RamadanStatus({
    required this.isRamadan,
    required this.day,
    required this.hijriYear,
    required this.daysUntilStart,
  });

  static const notRamadan = RamadanStatus(
    isRamadan: false,
    day: 0,
    hijriYear: 0,
    daysUntilStart: -1,
  );

  /// The last ten nights, when the night prayer matters most and ليلة القدر
  /// is sought.
  bool get isLastTen => isRamadan && day >= 21;

  /// The odd nights of the last ten, on which ليلة القدر is most expected.
  bool get isOddNightOfLastTen => isLastTen && day.isOdd;

  int get daysUntilLastTen => isRamadan && day < 21 ? 21 - day : 0;
}

/// Reads the Hijri date and reports Ramadan.
///
/// [offsetDays] shifts the civil-to-Hijri conversion. The tabular calendar the
/// conversion uses is arithmetic, while the month actually begins on a local
/// moonsighting, and the two differ by a day often enough that a fixed
/// calendar would tell some users to start fasting on the wrong date. The
/// setting is theirs to correct.
RamadanStatus ramadanStatusFor(DateTime date, {int offsetDays = 0}) {
  final shifted = date.add(Duration(days: offsetDays));
  final hijri = HijriCalendar.fromDate(
    DateTime(shifted.year, shifted.month, shifted.day),
  );

  if (hijri.hMonth == 9) {
    return RamadanStatus(
      isRamadan: true,
      day: hijri.hDay,
      hijriYear: hijri.hYear,
      daysUntilStart: 0,
    );
  }

  // Sha'ban (8) is the only month from which a countdown is worth showing;
  // announcing Ramadan in Muharram would be noise.
  if (hijri.hMonth == 8) {
    final daysInShaban = HijriCalendar().getDaysInMonth(hijri.hYear, 8);
    return RamadanStatus(
      isRamadan: false,
      day: 0,
      hijriYear: hijri.hYear,
      daysUntilStart: daysInShaban - hijri.hDay + 1,
    );
  }

  return RamadanStatus.notRamadan;
}
