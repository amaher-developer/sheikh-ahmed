import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;

/// How often each quick-access tile has been opened.
///
/// Keyed by the tile's translation key, which is already a stable id and does
/// not change when the label is retranslated or the icon is swapped.
class QuickAccessUsageRepository {
  final SharedPreferences _prefs;

  QuickAccessUsageRepository(this._prefs);

  static const _key = 'home.quickAccessUsage';

  Map<String, int> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          if (e.value is int) e.key: e.value as int,
      };
    } catch (_) {
      // A malformed blob is not worth crashing the home screen over; the
      // tiles simply fall back to their declared order and start counting
      // again.
      return const {};
    }
  }

  void save(Map<String, int> counts) =>
      _prefs.setString(_key, jsonEncode(counts));
}

class QuickAccessUsageNotifier extends StateNotifier<Map<String, int>> {
  final QuickAccessUsageRepository _repo;

  QuickAccessUsageNotifier(this._repo) : super(_repo.load());

  void record(String titleKey) {
    state = {...state, titleKey: (state[titleKey] ?? 0) + 1};
    _repo.save(state);
  }
}

final quickAccessUsageProvider =
    StateNotifierProvider<QuickAccessUsageNotifier, Map<String, int>>((ref) {
      return QuickAccessUsageNotifier(
        QuickAccessUsageRepository(ref.watch(sharedPreferencesProvider)),
      );
    });

/// Orders [keys] by how often each has been opened, most first.
///
/// Ties keep the order they were declared in, which matters more than it
/// sounds: on a fresh install every count is zero, so without a stable
/// tie-break the grid would come out in an arbitrary order and shuffle on
/// every rebuild. The declared order is the considered default, and usage
/// only pulls tiles up from it.
///
/// Returns the keys rather than sorting widgets so it can be tested without
/// building anything.
List<String> orderByUsage(List<String> keys, Map<String, int> usage) {
  final indexed = [
    for (var i = 0; i < keys.length; i++) (index: i, key: keys[i]),
  ];
  indexed.sort((a, b) {
    final ua = usage[a.key] ?? 0;
    final ub = usage[b.key] ?? 0;
    if (ua != ub) return ub.compareTo(ua);
    return a.index.compareTo(b.index);
  });
  return [for (final e in indexed) e.key];
}
