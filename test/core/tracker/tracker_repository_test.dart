import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/tracker/tracker_providers.dart';

void main() {
  late TrackerRepository repo;
  final today = DateTime(2026, 8, 25);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = TrackerRepository(await SharedPreferences.getInstance());
  });

  group('prayer completion', () {
    test('starts empty for a day with no data', () {
      expect(repo.getPrayersDone(today), isEmpty);
      expect(repo.allPrayersDone(today), isFalse);
    });

    test('round-trips a partial set', () async {
      await repo.setPrayersDone(today, {0, 2, 4});
      expect(repo.getPrayersDone(today), {0, 2, 4});
      expect(repo.allPrayersDone(today), isFalse);
    });

    test('allPrayersDone is true only once all 5 are marked', () async {
      await repo.setPrayersDone(today, {0, 1, 2, 3, 4});
      expect(repo.allPrayersDone(today), isTrue);
    });

    test('different days are independent', () async {
      final yesterday = today.subtract(const Duration(days: 1));
      await repo.setPrayersDone(today, {0, 1, 2, 3, 4});
      expect(repo.allPrayersDone(yesterday), isFalse);
      expect(repo.allPrayersDone(today), isTrue);
    });
  });

  group('night rak\'ahs', () {
    test('defaults to 0', () {
      expect(repo.getNightRakahs(today), 0);
    });

    test('round-trips a value', () async {
      await repo.setNightRakahs(today, 4);
      expect(repo.getNightRakahs(today), 4);
    });
  });
}
