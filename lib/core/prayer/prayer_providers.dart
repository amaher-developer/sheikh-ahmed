import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_key.dart';
import 'hijri_date_service.dart';
import 'location_service.dart';
import 'next_prayer.dart';
import 'prayer_city.dart';
import 'prayer_settings.dart';
import 'prayer_settings_repository.dart';
import 'prayer_times_service.dart';

/// Overridden in main() with the SharedPreferences instance obtained during
/// app bootstrap, so the rest of the provider graph can read it
/// synchronously instead of every consumer dealing with a Future.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

final prayerSettingsRepositoryProvider = Provider<PrayerSettingsRepository>((
  ref,
) {
  return PrayerSettingsRepository(ref.watch(sharedPreferencesProvider));
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

const _prayerTimesService = PrayerTimesService();

class PrayerSettingsNotifier extends StateNotifier<PrayerSettings> {
  final PrayerSettingsRepository _repo;

  PrayerSettingsNotifier(this._repo) : super(_repo.load());

  Future<void> setCity(PrayerCity city) async {
    state = state.copyWith(
      latitude: city.latitude,
      longitude: city.longitude,
      cityId: city.id,
    );
    await _repo.save(state);
  }

  Future<void> setCoordinates(double latitude, double longitude) async {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      clearCityId: true,
    );
    await _repo.save(state);
  }

  Future<void> setMethod(CalculationMethod method) async {
    state = state.copyWith(method: method);
    await _repo.save(state);
  }

  Future<void> setMadhab(Madhab madhab) async {
    state = state.copyWith(madhab: madhab);
    await _repo.save(state);
  }
}

final prayerSettingsProvider =
    StateNotifierProvider<PrayerSettingsNotifier, PrayerSettings>((ref) {
      return PrayerSettingsNotifier(
        ref.watch(prayerSettingsRepositoryProvider),
      );
    });

/// Ticks once immediately, then every 30s — frequent enough to keep the
/// countdown/progress ring fresh without rebuilding on every second.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

DateTime _watchNow(Ref ref) =>
    ref.watch(nowProvider).valueOrNull ?? DateTime.now();

/// Today's date-key ("YYYY-MM-DD"), re-derived every time [nowProvider]
/// ticks (every 30s). Riverpod only notifies watchers when the *value*
/// actually changes, so despite the frequent ticking this only fires once
/// a day — the one hook azkar/tracker/"read today" progress needs to
/// reset itself at midnight even when the app is never closed, since their
/// storage is already keyed by calendar date but their in-memory Riverpod
/// state otherwise only re-reads it on provider creation (app launch).
final currentDateKeyProvider = Provider<String>((ref) {
  return dateKey(_watchNow(ref));
});

final todayPrayerTimesProvider = Provider<DailyPrayerTimes>((ref) {
  final settings = ref.watch(prayerSettingsProvider);
  // Keyed to the calendar *date*, not the ticking instant. Watching
  // nowProvider here re-ran the full astronomical calculation every 30
  // seconds — around 2,880 times a day — for a result that can only change
  // at midnight, and invalidated every downstream watcher each time.
  // currentDateKeyProvider is derived from the same tick but only notifies
  // when the day actually rolls over.
  final date = DateTime.parse(ref.watch(currentDateKeyProvider));
  return _prayerTimesService.calculate(
    date: date,
    coordinates: settings.coordinates,
    method: settings.method,
    madhab: settings.madhab,
  );
});

/// Every day of the given month, for the imsakiya table.
///
/// Computed rather than downloaded: the same astronomical routine already
/// produces today's times offline, so a month is just thirty more calls to
/// it — no network, no printed table to go stale, and it follows whatever
/// calculation method and location the user has set instead of assuming
/// one city.
///
/// `.family` on a year-month key, not on a DateTime: a DateTime carries a
/// time-of-day that would make every rebuild a different family argument
/// and recompute the whole month each time.
final monthlyPrayerTimesProvider =
    Provider.family<List<DailyPrayerTimes>, String>((ref, yearMonth) {
      final settings = ref.watch(prayerSettingsProvider);
      final parts = yearMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      // Day 0 of the next month is the last day of this one.
      final days = DateTime(year, month + 1, 0).day;
      return [
        for (var d = 1; d <= days; d++)
          _prayerTimesService.calculate(
            date: DateTime(year, month, d),
            coordinates: settings.coordinates,
            method: settings.method,
            madhab: settings.madhab,
          ),
      ];
    });

final nextPrayerProvider = Provider<NextPrayerResult>((ref) {
  final settings = ref.watch(prayerSettingsProvider);
  final now = _watchNow(ref);
  final today = ref.watch(todayPrayerTimesProvider);

  return computeNextPrayer(
    now: now,
    today: today,
    computeYesterday: () => _prayerTimesService.calculate(
      date: now.subtract(const Duration(days: 1)),
      coordinates: settings.coordinates,
      method: settings.method,
      madhab: settings.madhab,
    ),
    computeTomorrow: () => _prayerTimesService.calculate(
      date: now.add(const Duration(days: 1)),
      coordinates: settings.coordinates,
      method: settings.method,
      madhab: settings.madhab,
    ),
  );
});

final hijriDateServiceProvider = Provider<HijriDateService>((ref) {
  return HijriDateService(ref.watch(sharedPreferencesProvider));
});

/// Today's Hijri date, fetched once per day and cached — see
/// HijriDateService for why this isn't computed locally.
final todayHijriDateProvider = FutureProvider<HijriDate>((ref) {
  return ref.watch(hijriDateServiceProvider).fetch(DateTime.now());
});
