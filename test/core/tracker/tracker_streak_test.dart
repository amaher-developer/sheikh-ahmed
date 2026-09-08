import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_providers.dart';
import 'package:sheikh_ahmed_app/core/tracker/tracker_providers.dart';

void main() {
  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('streak is 0 with no history', () async {
    final container = await buildContainer();
    expect(container.read(prayerStreakProvider), 0);
  });

  test('streak counts consecutive fully-completed days ending today', () async {
    final container = await buildContainer();
    final repo = container.read(trackerRepositoryProvider);
    final today = DateTime.now();

    for (var i = 0; i < 4; i++) {
      await repo.setPrayersDone(today.subtract(Duration(days: i)), {
        0,
        1,
        2,
        3,
        4,
      });
    }

    expect(container.read(prayerStreakProvider), 4);
  });

  test('an incomplete today does not count, but does not erase yesterday '
      'either', () async {
    final container = await buildContainer();
    final repo = container.read(trackerRepositoryProvider);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    await repo.setPrayersDone(yesterday, {0, 1, 2, 3, 4});
    await repo.setPrayersDone(today, {0, 1}); // only 2 of 5 so far

    expect(container.read(prayerStreakProvider), 1);
  });

  test('a gap day stops the streak', () async {
    final container = await buildContainer();
    final repo = container.read(trackerRepositoryProvider);
    final today = DateTime.now();

    await repo.setPrayersDone(today, {0, 1, 2, 3, 4});
    // day before yesterday is complete, but yesterday (the gap) is not.
    await repo.setPrayersDone(today.subtract(const Duration(days: 2)), {
      0,
      1,
      2,
      3,
      4,
    });

    expect(container.read(prayerStreakProvider), 1);
  });

  test('weekPrayerCompletionProvider has 7 entries, today at its Sat-week index', () async {
    final container = await buildContainer();
    final repo = container.read(trackerRepositoryProvider);
    final today = DateTime.now();
    await repo.setPrayersDone(today, {0, 1, 2, 3, 4});

    final week = container.read(weekPrayerCompletionProvider);
    expect(week, hasLength(7));
    expect(week[saturdayWeekIndex(today)], isTrue);
  });

  group('saturdayWeekIndex', () {
    test('Saturday is index 0 and Friday is index 6', () {
      // 2026-08-22 is a Saturday, 2026-08-28 the following Friday.
      expect(saturdayWeekIndex(DateTime(2026, 8, 22)), 0);
      expect(saturdayWeekIndex(DateTime(2026, 8, 23)), 1); // Sunday
      expect(saturdayWeekIndex(DateTime(2026, 8, 24)), 2); // Monday
      expect(saturdayWeekIndex(DateTime(2026, 8, 28)), 6); // Friday
    });
  });

  test('toggling a prayer persists and reflects immediately', () async {
    final container = await buildContainer();
    final notifier = container.read(todayPrayersProvider.notifier);

    notifier.toggle(0);
    expect(container.read(todayPrayersProvider), {0});
    notifier.toggle(0);
    expect(container.read(todayPrayersProvider), isEmpty);
  });

  group('night rak\'ahs', () {
    test('adding 2 accumulates and caps back to 0 at the target', () async {
      final container = await buildContainer();
      final notifier = container.read(nightRakahsProvider.notifier);

      for (var i = 0; i < kNightPrayerTargetRakahs ~/ 2; i++) {
        notifier.addTwo();
      }
      expect(container.read(nightRakahsProvider), kNightPrayerTargetRakahs);

      notifier.addTwo(); // one more tap past the target wraps to 0
      expect(container.read(nightRakahsProvider), 0);
    });
  });

  group('manual Quran read toggle', () {
    // The tracker's Quran row used to only ever auto-complete from the
    // reader actually saving a position — this is the direct "check it
    // off yourself" override that was missing.
    test('quranWirdDoneTodayProvider is false until toggled on', () async {
      final container = await buildContainer();
      expect(container.read(quranWirdDoneTodayProvider), isFalse);

      container.read(manualQuranReadTodayProvider.notifier).toggle();
      expect(container.read(quranWirdDoneTodayProvider), isTrue);
      expect(container.read(manualQuranReadTodayProvider), isTrue);
    });

    test('toggling twice returns to not done', () async {
      final container = await buildContainer();
      final notifier = container.read(manualQuranReadTodayProvider.notifier);

      notifier.toggle();
      notifier.toggle();
      expect(container.read(quranWirdDoneTodayProvider), isFalse);
    });

    test('persists across a fresh repository read for the same day', () async {
      final container = await buildContainer();
      final repo = container.read(trackerRepositoryProvider);
      final today = DateTime.now();

      container.read(manualQuranReadTodayProvider.notifier).toggle();

      expect(repo.getManualQuranRead(today), isTrue);
    });
  });
}
