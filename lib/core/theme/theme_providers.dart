import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_load(_prefs));

  static const _key = 'app.darkMode';

  static ThemeMode _load(SharedPreferences prefs) {
    final stored = prefs.getBool(_key);
    if (stored == null) return ThemeMode.system;
    return stored ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDark(bool dark) async {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(_key, dark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});
