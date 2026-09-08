import 'package:adhan_dart/adhan_dart.dart';

/// A small offline preset list of cities used as quick-pick locations —
/// no geocoding network call required, keeping location selection fully
/// offline-first. Display names live in the translation catalog under
/// `cities.<id>` so they follow the same ar/en localization as everything
/// else in the app.
class PrayerCity {
  final String id;
  final double latitude;
  final double longitude;

  const PrayerCity({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  Coordinates get coordinates => Coordinates(latitude, longitude);
}

const kPresetCities = <PrayerCity>[
  PrayerCity(id: 'cairo', latitude: 30.0444, longitude: 31.2357),
  PrayerCity(id: 'mecca', latitude: 21.3891, longitude: 39.8579),
  PrayerCity(id: 'medina', latitude: 24.5247, longitude: 39.5692),
  PrayerCity(id: 'istanbul', latitude: 41.0082, longitude: 28.9784),
  PrayerCity(id: 'riyadh', latitude: 24.7136, longitude: 46.6753),
  PrayerCity(id: 'amman', latitude: 31.9454, longitude: 35.9284),
  PrayerCity(id: 'jakarta', latitude: -6.2088, longitude: 106.8456),
  PrayerCity(id: 'london', latitude: 51.5072, longitude: -0.1276),
  PrayerCity(id: 'newyork', latitude: 40.7128, longitude: -74.0060),
];

// kPresetCities[0] isn't usable in a const context (const list indexing
// isn't a constant expression in Dart), so this is `final` rather than
// `const` — still just one immutable singleton evaluated once.
final kDefaultCity = kPresetCities
    .first; // Cairo — matches the app's existing mock/default context

PrayerCity? findPresetCity(String? id) {
  if (id == null) return null;
  for (final city in kPresetCities) {
    if (city.id == id) return city;
  }
  return null;
}
