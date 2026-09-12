import 'package:shared_preferences/shared_preferences.dart';

import 'surah_meta.dart';

/// Keeps the surah favourites across restarts.
///
/// The flag itself lives on the shared [kAllSurahs] entries — that is what
/// the surah list already reads — so this only mirrors it to preferences:
/// [restore] once when the Quran tab is first built, [persist] after every
/// toggle. Before this the favourites were in memory only and every launch
/// started with an empty favourites chip.
class FavoriteSurahs {
  const FavoriteSurahs._();

  static const _key = 'quran_favorite_surahs';

  /// Applies the saved favourites to [kAllSurahs].
  static void restore(SharedPreferences prefs) {
    final saved = prefs.getStringList(_key);
    if (saved == null) return;
    final numbers = saved.map(int.tryParse).whereType<int>().toSet();
    for (final surah in kAllSurahs) {
      surah.favorite = numbers.contains(surah.number);
    }
  }

  /// Writes the current favourites from [kAllSurahs].
  static Future<void> persist(SharedPreferences prefs) => prefs.setStringList(
        _key,
        [for (final s in kAllSurahs) if (s.favorite) '${s.number}'],
      );
}
