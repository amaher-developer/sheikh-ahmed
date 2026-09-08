import 'package:adhan_dart/adhan_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_settings.dart';

/// Reads/writes [PrayerSettings] to on-device key-value storage.
/// SharedPreferences (not Hive, per scope) — a handful of scalar values
/// doesn't need a database.
class PrayerSettingsRepository {
  final SharedPreferences _prefs;

  PrayerSettingsRepository(this._prefs);

  static const _kLatitude = 'prayer.latitude';
  static const _kLongitude = 'prayer.longitude';
  static const _kCityId = 'prayer.cityId';
  static const _kMethod = 'prayer.method';
  static const _kMadhab = 'prayer.madhab';

  PrayerSettings load() {
    final lat = _prefs.getDouble(_kLatitude);
    final lng = _prefs.getDouble(_kLongitude);
    if (lat == null || lng == null) return PrayerSettings.defaults();

    final method = CalculationMethod.values.firstWhere(
      (m) => m.name == _prefs.getString(_kMethod),
      orElse: () => CalculationMethod.egyptian,
    );
    final madhab = Madhab.values.firstWhere(
      (m) => m.name == _prefs.getString(_kMadhab),
      orElse: () => Madhab.shafi,
    );

    return PrayerSettings(
      latitude: lat,
      longitude: lng,
      cityId: _prefs.getString(_kCityId),
      method: method,
      madhab: madhab,
    );
  }

  Future<void> save(PrayerSettings settings) async {
    await _prefs.setDouble(_kLatitude, settings.latitude);
    await _prefs.setDouble(_kLongitude, settings.longitude);
    await _prefs.setString(_kMethod, settings.method.name);
    await _prefs.setString(_kMadhab, settings.madhab.name);
    if (settings.cityId != null) {
      await _prefs.setString(_kCityId, settings.cityId!);
    } else {
      await _prefs.remove(_kCityId);
    }
  }
}
