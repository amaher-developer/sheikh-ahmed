import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/tracker/tracker_providers.dart';
import 'package:sheikh_ahmed_app/core/utils/date_key.dart';

/// Every part of the worship tracker has to start blank on a new day.
///
/// There is no nightly reset job — storage is keyed by calendar date, so a
/// new day simply reads a key nothing was written to. That works only if
/// *every* stored item is date-scoped: one that isn't would carry yesterday's
/// state forward and there would be no obvious sign of it beyond a tracker
/// that looks already half-done in the morning.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 9, 6);
  final yesterday = DateTime(2026, 9, 5);

  Future<TrackerRepository> repo() async {
    SharedPreferences.setMockInitialValues({});
    return TrackerRepository(await SharedPreferences.getInstance());
  }

  test('prayers marked yesterday do not carry into today', () async {
    final r = await repo();
    await r.setPrayersDone(yesterday, {0, 1, 2, 3, 4});

    expect(r.allPrayersDone(yesterday), isTrue);
    expect(r.getPrayersDone(today), isEmpty);
  });

  test('night rak\'ahs reset', () async {
    final r = await repo();
    await r.setNightRakahs(yesterday, kNightPrayerTargetRakahs);

    expect(r.getNightRakahs(yesterday), kNightPrayerTargetRakahs);
    expect(r.getNightRakahs(today), 0);
  });

  test('the manual "read Quran" tick resets', () async {
    final r = await repo();
    await r.setManualQuranRead(yesterday, true);

    expect(r.getManualQuranRead(yesterday), isTrue);
    expect(r.getManualQuranRead(today), isFalse);
  });

  test('yesterday is preserved, not wiped', () async {
    // The weekly streak view reads past days, so resetting must mean "a new
    // day starts empty", never "the old day is cleared".
    final r = await repo();
    await r.setPrayersDone(yesterday, {0, 3});
    await r.setNightRakahs(yesterday, 4);

    expect(r.getPrayersDone(yesterday), {0, 3});
    expect(r.getNightRakahs(yesterday), 4);
  });

  test('the day boundary is midnight, and each day gets its own key', () {
    // 23:59 and 00:00 fall either side of it; two minutes apart in the
    // evening do not.
    expect(dateKey(DateTime(2026, 9, 6, 23, 59)), '2026-09-06');
    expect(dateKey(DateTime(2026, 9, 7, 0, 0)), '2026-09-07');
    expect(
      dateKey(DateTime(2026, 9, 6, 21, 0)),
      dateKey(DateTime(2026, 9, 6, 21, 2)),
    );
  });

  test('every stored tracker key carries the date', () async {
    // The guard against a future item being added without a date scope.
    final r = await repo();
    await r.setPrayersDone(today, {1});
    await r.setNightRakahs(today, 2);
    await r.setManualQuranRead(today, true);

    final prefs = await SharedPreferences.getInstance();
    final trackerKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('tracker.') && !k.contains('Celebrated'));

    expect(trackerKeys, isNotEmpty);
    for (final key in trackerKeys) {
      expect(
        key.endsWith(dateKey(today)),
        isTrue,
        reason: '$key is not scoped to a day, so it never resets',
      );
    }
  });
}
