import 'package:adhan_dart/adhan_dart.dart';
import 'prayer_city.dart';

/// User-configurable inputs to the prayer-time calculation: where they are
/// and which calculation convention to use. Persisted locally (see
/// [PrayerSettingsRepository]) so the app works fully offline after the
/// first successful location fix / city pick.
class PrayerSettings {
  final double latitude;
  final double longitude;

  /// Preset city id, or null when the coordinates came from device GPS
  /// (a "custom" location with no bundled display name).
  final String? cityId;

  final CalculationMethod method;
  final Madhab madhab;

  const PrayerSettings({
    required this.latitude,
    required this.longitude,
    required this.method,
    required this.madhab,
    this.cityId,
  });

  factory PrayerSettings.defaults() => PrayerSettings(
    latitude: kDefaultCity.latitude,
    longitude: kDefaultCity.longitude,
    cityId: kDefaultCity.id,
    method: CalculationMethod.egyptian,
    madhab: Madhab.shafi,
  );

  Coordinates get coordinates => Coordinates(latitude, longitude);

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    String? cityId,
    bool clearCityId = false,
    CalculationMethod? method,
    Madhab? madhab,
  }) {
    return PrayerSettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      method: method ?? this.method,
      madhab: madhab ?? this.madhab,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerSettings &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.cityId == cityId &&
      other.method == method &&
      other.madhab == madhab;

  @override
  int get hashCode => Object.hash(latitude, longitude, cityId, method, madhab);
}
