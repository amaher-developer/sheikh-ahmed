import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../azkar/azkar_data.dart';
import '../azkar/azkar_providers.dart';
import '../prayer/prayer_providers.dart'
    show currentDateKeyProvider, sharedPreferencesProvider;
import '../prayer/prayer_times_service.dart';
import '../quran/quran_providers.dart';
import '../utils/date_key.dart';

const kNightPrayerTargetRakahs = 8;

/// Persists which of the day's 5 prayers are marked done, and how many
/// night-prayer rak'ahs were prayed, keyed by calendar date the same way
/// azkar progress is — so a new day starts blank without an explicit
/// reset job, and past days stay queryable for the weekly streak view.
class TrackerRepository {
  final SharedPreferences _prefs;
  TrackerRepository(this._prefs);

  String _prayerKey(DateTime date) => 'tracker.prayers.${dateKey(date)}';
  String _rakahsKey(DateTime date) => 'tracker.nightRakahs.${dateKey(date)}';

  /// Bitmask: bit i set means prayer index i (0=Fajr..4=Isha) is done.
  Set<int> getPrayersDone(DateTime date) {
    final mask = _prefs.getInt(_prayerKey(date)) ?? 0;
    return {
      for (var i = 0; i < DailyPrayerTimes.labelKeys.length; i++)
        if (mask & (1 << i) != 0) i,
    };
  }

  Future<void> setPrayersDone(DateTime date, Set<int> indices) async {
    var mask = 0;
    for (final i in indices) {
      mask |= 1 << i;
    }
    await _prefs.setInt(_prayerKey(date), mask);
  }

  bool allPrayersDone(DateTime date) =>
      getPrayersDone(date).length >= DailyPrayerTimes.labelKeys.length;

  int getNightRakahs(DateTime date) => _prefs.getInt(_rakahsKey(date)) ?? 0;

  Future<void> setNightRakahs(DateTime date, int rakahs) =>
      _prefs.setInt(_rakahsKey(date), rakahs);

  String _manualQuranKey(DateTime date) =>
      'tracker.quranReadManual.${dateKey(date)}';

  bool getManualQuranRead(DateTime date) =>
      _prefs.getBool(_manualQuranKey(date)) ?? false;

  Future<void> setManualQuranRead(DateTime date, bool value) =>
      _prefs.setBool(_manualQuranKey(date), value);

  static const _kCelebratedDate = 'tracker.wirdCelebratedDate';

  /// Whether the completion celebration has already been shown today — so
  /// it fires once per day, not on every rebuild after completion.
  bool celebratedToday() =>
      _prefs.getString(_kCelebratedDate) == dateKey(DateTime.now());

  Future<void> markCelebratedToday() =>
      _prefs.setString(_kCelebratedDate, dateKey(DateTime.now()));
}

final trackerRepositoryProvider = Provider<TrackerRepository>((ref) {
  return TrackerRepository(ref.watch(sharedPreferencesProvider));
});

/// Today's completed prayers (indices 0..4), toggleable from the UI.
class TodayPrayersNotifier extends StateNotifier<Set<int>> {
  final TrackerRepository _repo;
  final DateTime _today;

  TodayPrayersNotifier(this._repo, this._today)
    : super(_repo.getPrayersDone(_today));

  void toggle(int index) {
    final next = {...state};
    if (!next.remove(index)) next.add(index);
    state = next;
    _repo.setPrayersDone(_today, next);
  }
}

/// `DateTime.now()` truncated to the calendar day, kept as a stable
/// provider input so all tracker providers agree on "today" for one build.
/// Watches [currentDateKeyProvider] so that if the app is left open (or
/// just backgrounded, not killed) across midnight, "today" — and every
/// StateNotifier built on it below — recomputes and resets instead of
/// staying frozen on the day the app happened to launch.
final _todayProvider = Provider<DateTime>((ref) {
  ref.watch(currentDateKeyProvider);
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final todayPrayersProvider =
    StateNotifierProvider<TodayPrayersNotifier, Set<int>>((ref) {
      return TodayPrayersNotifier(
        ref.watch(trackerRepositoryProvider),
        ref.watch(_todayProvider),
      );
    });

/// Rak'ahs of night prayer (qiyam) logged today, capped at
/// [kNightPrayerTargetRakahs]. Tapping the tracker row adds 2 (the natural
/// unit of prayer) and wraps back to 0 once the target is reached.
class NightRakahsNotifier extends StateNotifier<int> {
  final TrackerRepository _repo;
  final DateTime _today;

  NightRakahsNotifier(this._repo, this._today)
    : super(_repo.getNightRakahs(_today));

  void addTwo() {
    final next = state >= kNightPrayerTargetRakahs ? 0 : state + 2;
    state = next;
    _repo.setNightRakahs(_today, next);
  }
}

final nightRakahsProvider = StateNotifierProvider<NightRakahsNotifier, int>((
  ref,
) {
  return NightRakahsNotifier(
    ref.watch(trackerRepositoryProvider),
    ref.watch(_todayProvider),
  );
});

/// Index of [date] within a week that starts on Saturday (0=Sat..6=Fri) —
/// the convention used across the Gulf/much of the Islamic world, as
/// opposed to Dart's own Mon..Sun `DateTime.weekday`.
int saturdayWeekIndex(DateTime date) => (date.weekday + 1) % 7;

/// The calendar week (Saturday..Friday) containing today, paired with
/// whether all 5 prayers were completed that day — backs the week-strip
/// calendar. Index 0 is always Saturday, regardless of where "today" falls.
final weekPrayerCompletionProvider = Provider<List<bool>>((ref) {
  // Watched so the strip updates the moment today's checkboxes change,
  // without waiting for a rebuild triggered some other way.
  ref.watch(todayPrayersProvider);
  final repo = ref.watch(trackerRepositoryProvider);
  final today = ref.watch(_todayProvider);
  final saturday = today.subtract(Duration(days: saturdayWeekIndex(today)));
  return [
    for (var i = 0; i < 7; i++)
      repo.allPrayersDone(saturday.add(Duration(days: i))),
  ];
});

/// Consecutive days (ending today or yesterday) with all 5 prayers done.
/// Today doesn't break the streak while still in progress — it just
/// doesn't count until finished, so praying Fajr doesn't reset a real
/// streak built on previous days.
final prayerStreakProvider = Provider<int>((ref) {
  ref.watch(todayPrayersProvider);
  final repo = ref.watch(trackerRepositoryProvider);
  final today = ref.watch(_todayProvider);

  var streak = 0;
  var day = repo.allPrayersDone(today)
      ? today
      : today.subtract(const Duration(days: 1));
  while (repo.allPrayersDone(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
});

/// Manual "I read Quran today" override, toggled directly from the
/// tracker. [readQuranTodayProvider] only turns on automatically once the
/// reader has actually been opened and a position saved on close — useful,
/// but it means there was previously no way to check the item off from the
/// tracker itself if e.g. someone read from a physical Mus'haf that day.
class ManualQuranReadNotifier extends StateNotifier<bool> {
  final TrackerRepository _repo;
  final DateTime _today;

  ManualQuranReadNotifier(this._repo, this._today)
    : super(_repo.getManualQuranRead(_today));

  void toggle() {
    final next = !state;
    state = next;
    _repo.setManualQuranRead(_today, next);
  }
}

final manualQuranReadTodayProvider =
    StateNotifierProvider<ManualQuranReadNotifier, bool>((ref) {
      return ManualQuranReadNotifier(
        ref.watch(trackerRepositoryProvider),
        ref.watch(_todayProvider),
      );
    });

/// Whether today's Quran-reading wird item counts as done — either the
/// reader was actually opened today, or it was checked off manually.
final quranWirdDoneTodayProvider = Provider<bool>((ref) {
  return ref.watch(readQuranTodayProvider) ||
      ref.watch(manualQuranReadTodayProvider);
});

/// True once every item of the daily wird — Quran reading, morning azkar,
/// evening azkar, night prayer — is complete for today. The tracker screen
/// watches this to trigger the completion celebration.
final dailyWirdCompleteTodayProvider = Provider<bool>((ref) {
  final readQuran = ref.watch(quranWirdDoneTodayProvider);
  final azkarProgress = ref.watch(azkarProgressProvider);
  final morning = kAzkarCategories.firstWhere((c) => c.id == 'morning');
  final evening = kAzkarCategories.firstWhere((c) => c.id == 'evening');
  final nightRakahs = ref.watch(nightRakahsProvider);

  return readQuran &&
      azkarCategoryProgress(morning, azkarProgress) >= 1 &&
      azkarCategoryProgress(evening, azkarProgress) >= 1 &&
      nightRakahs >= kNightPrayerTargetRakahs;
});
