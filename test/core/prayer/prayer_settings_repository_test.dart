import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_city.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_settings.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrayerSettingsRepository', () {
    test(
      'load() returns app defaults (Cairo, Egyptian, Shafi) when nothing is persisted',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = PrayerSettingsRepository(
          await SharedPreferences.getInstance(),
        );

        final settings = repo.load();

        expect(settings.cityId, kDefaultCity.id);
        expect(settings.latitude, kDefaultCity.latitude);
        expect(settings.longitude, kDefaultCity.longitude);
        expect(settings.method, CalculationMethod.egyptian);
        expect(settings.madhab, Madhab.shafi);
      },
    );

    test('save() then load() round-trips a preset-city selection', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrayerSettingsRepository(
        await SharedPreferences.getInstance(),
      );

      const mecca = PrayerCity(
        id: 'mecca',
        latitude: 21.3891,
        longitude: 39.8579,
      );
      final saved = PrayerSettings(
        latitude: mecca.latitude,
        longitude: mecca.longitude,
        cityId: mecca.id,
        method: CalculationMethod.ummAlQura,
        madhab: Madhab.hanafi,
      );

      await repo.save(saved);
      final loaded = repo.load();

      expect(loaded, saved);
    });

    test(
      'save() with a null cityId (custom GPS location) clears any previously saved city',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = PrayerSettingsRepository(
          await SharedPreferences.getInstance(),
        );

        await repo.save(
          PrayerSettings(
            latitude: kDefaultCity.latitude,
            longitude: kDefaultCity.longitude,
            cityId: kDefaultCity.id,
            method: CalculationMethod.egyptian,
            madhab: Madhab.shafi,
          ),
        );

        const customLat = 12.34;
        const customLng = 56.78;
        await repo.save(
          PrayerSettings(
            latitude: customLat,
            longitude: customLng,
            cityId: null,
            method: CalculationMethod.egyptian,
            madhab: Madhab.shafi,
          ),
        );

        final loaded = repo.load();
        expect(loaded.cityId, isNull);
        expect(loaded.latitude, customLat);
        expect(loaded.longitude, customLng);
      },
    );

    test(
      'load() falls back to Egyptian/Shafi if a stored method/madhab name is unrecognized',
      () async {
        SharedPreferences.setMockInitialValues({
          'prayer.latitude': 1.0,
          'prayer.longitude': 2.0,
          'prayer.method': 'not_a_real_method',
          'prayer.madhab': 'not_a_real_madhab',
        });
        final repo = PrayerSettingsRepository(
          await SharedPreferences.getInstance(),
        );

        final settings = repo.load();

        expect(settings.method, CalculationMethod.egyptian);
        expect(settings.madhab, Madhab.shafi);
      },
    );
  });

  group('PrayerSettings.copyWith', () {
    test(
      'clearCityId: true drops the city id even if a new one is not supplied',
      () {
        final withCity = PrayerSettings.defaults();
        final cleared = withCity.copyWith(
          latitude: 9.9,
          longitude: 8.8,
          clearCityId: true,
        );

        expect(cleared.cityId, isNull);
        expect(cleared.latitude, 9.9);
        expect(cleared.longitude, 8.8);
        // Untouched fields are preserved.
        expect(cleared.method, withCity.method);
        expect(cleared.madhab, withCity.madhab);
      },
    );
  });
}
