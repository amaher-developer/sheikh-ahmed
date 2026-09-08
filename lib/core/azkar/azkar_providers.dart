import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../prayer/prayer_providers.dart'
    show currentDateKeyProvider, sharedPreferencesProvider;
import '../utils/date_key.dart';
import 'azkar_data.dart';

/// Persists each dhikr's tap count for *today* only — progress resets
/// naturally the next day since the storage key includes the date, without
/// needing an explicit daily-reset job.
class AzkarProgressRepository {
  final SharedPreferences _prefs;

  AzkarProgressRepository(this._prefs);

  String _key(String itemId) => 'azkar.progress.${dateKey(DateTime.now())}.$itemId';

  int getCount(String itemId) => _prefs.getInt(_key(itemId)) ?? 0;

  Future<void> setCount(String itemId, int count) =>
      _prefs.setInt(_key(itemId), count);
}

final azkarProgressRepositoryProvider = Provider<AzkarProgressRepository>((
  ref,
) {
  return AzkarProgressRepository(ref.watch(sharedPreferencesProvider));
});

/// itemId -> count tapped today.
class AzkarProgressNotifier extends StateNotifier<Map<String, int>> {
  final AzkarProgressRepository _repo;

  AzkarProgressNotifier(this._repo)
    : super({
        for (final category in kAzkarCategories)
          for (final item in category.items) item.id: _repo.getCount(item.id),
      });

  void increment(AzkarItem item) {
    final current = state[item.id] ?? 0;
    if (current >= item.count) return;
    final next = current + 1;
    state = {...state, item.id: next};
    _repo.setCount(item.id, next);
  }

  bool isDone(AzkarItem item) => (state[item.id] ?? 0) >= item.count;
}

final azkarProgressProvider =
    StateNotifierProvider<AzkarProgressNotifier, Map<String, int>>((ref) {
      // Recreates the notifier (fresh read of each item's count for the new
      // day, i.e. 0) the moment the calendar day changes — otherwise this
      // in-memory state stays frozen on whatever day the app was launched,
      // even though storage itself already resets naturally (see
      // AzkarProgressRepository._key).
      ref.watch(currentDateKeyProvider);
      return AzkarProgressNotifier(ref.watch(azkarProgressRepositoryProvider));
    });

/// Fraction of [category]'s items completed today, from the same progress
/// map the Azkar screen itself uses — shared so the worship tracker can
/// show real morning/evening azkar completion instead of a fake number.
double azkarCategoryProgress(
  AzkarCategory category,
  Map<String, int> progress,
) {
  if (category.items.isEmpty) return 0;
  final done = category.items
      .where((item) => (progress[item.id] ?? 0) >= item.count)
      .length;
  return done / category.items.length;
}
