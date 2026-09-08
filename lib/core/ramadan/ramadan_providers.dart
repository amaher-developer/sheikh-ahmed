import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_providers.dart'
    show currentDateKeyProvider, sharedPreferencesProvider;
import 'ramadan_status.dart';

/// The user's correction to the arithmetic Hijri date, in days.
///
/// Kept because the conversion is tabular while the month begins on a local
/// moonsighting; a country announcing Ramadan a day either side of the
/// calendar is ordinary, not an edge case.
class HijriOffsetNotifier extends StateNotifier<int> {
  final SharedPreferences _prefs;

  static const _key = 'ramadan.hijriOffset';

  HijriOffsetNotifier(this._prefs) : super(_prefs.getInt(_key) ?? 0);

  Future<void> set(int days) async {
    final clamped = days.clamp(-2, 2);
    state = clamped;
    await _prefs.setInt(_key, clamped);
  }
}

final hijriOffsetProvider = StateNotifierProvider<HijriOffsetNotifier, int>((
  ref,
) {
  return HijriOffsetNotifier(ref.watch(sharedPreferencesProvider));
});

/// Whether it is Ramadan, and which day.
///
/// Keyed to the calendar date rather than the ticking clock — like
/// todayPrayerTimesProvider — so it recomputes when the day rolls over and
/// not thirty times a minute.
final ramadanStatusProvider = Provider<RamadanStatus>((ref) {
  final date = DateTime.parse(ref.watch(currentDateKeyProvider));
  return ramadanStatusFor(date, offsetDays: ref.watch(hijriOffsetProvider));
});
