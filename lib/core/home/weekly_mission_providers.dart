import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../prayer/prayer_providers.dart'
    show currentDateKeyProvider, sharedPreferencesProvider;
import '../ramadan/ramadan_providers.dart';
import 'weekly_mission_data.dart';

class WeeklyMissionRepository {
  final SharedPreferences _prefs;
  WeeklyMissionRepository(this._prefs);

  static const _kCompletedWeekKey = 'weekly_mission.completedWeekKey';

  bool isCompleted(String weekKey) =>
      _prefs.getString(_kCompletedWeekKey) == weekKey;

  Future<void> setCompleted(String weekKey, bool value) =>
      _prefs.setString(_kCompletedWeekKey, value ? weekKey : '');
}

final weeklyMissionRepositoryProvider = Provider<WeeklyMissionRepository>((
  ref,
) {
  return WeeklyMissionRepository(ref.watch(sharedPreferencesProvider));
});

/// Whether *this week's* mission has been marked done — re-checked whenever
/// the calendar date changes (see [currentDateKeyProvider]) so it resets
/// itself the moment a new week's mission starts, without an explicit
/// reset job.
/// This period's mission — the Ramadan list during Ramadan, the yearly
/// one otherwise. Read from here rather than calling weeklyMission()
/// directly, so the home card, the widget and the weekly reminder cannot
/// end up showing three different missions.
final currentMissionProvider = Provider<WeeklyMission>((ref) {
  ref.watch(currentDateKeyProvider);
  final ramadan = ref.watch(ramadanStatusProvider);
  return missionFor(
    DateTime.now(),
    ramadan: ramadan.isRamadan,
    day: ramadan.day,
  );
});

final currentMissionKeyProvider = Provider<String>((ref) {
  ref.watch(currentDateKeyProvider);
  final ramadan = ref.watch(ramadanStatusProvider);
  return missionKeyFor(
    DateTime.now(),
    ramadan: ramadan.isRamadan,
    day: ramadan.day,
  );
});

final weeklyMissionCompletedProvider = Provider<bool>((ref) {
  ref.watch(currentDateKeyProvider);
  final repo = ref.watch(weeklyMissionRepositoryProvider);
  return repo.isCompleted(ref.watch(currentMissionKeyProvider));
});

Future<void> toggleWeeklyMissionCompleted(WidgetRef ref) async {
  final repo = ref.read(weeklyMissionRepositoryProvider);
  final key = ref.read(currentMissionKeyProvider);
  final current = repo.isCompleted(key);
  await repo.setCompleted(key, !current);
  ref.invalidate(weeklyMissionCompletedProvider);
}
