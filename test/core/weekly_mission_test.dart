import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/home/weekly_mission_data.dart';

void main() {
  test('the mission holds all week and turns over on Saturday', () {
    // 2026-09-05 is a Saturday.
    final saturday = DateTime(2026, 9, 5);
    expect(saturday.weekday, DateTime.saturday);

    // Every day Saturday..Friday shares one mission.
    for (var day = 1; day <= 6; day++) {
      final within = saturday.add(Duration(days: day));
      expect(
        weeklyMission(within).titleKey,
        weeklyMission(saturday).titleKey,
        reason: 'day $day of the week must keep the same mission',
      );
      // weekKey is what the "done" tick is stored under, so it has to move
      // with the mission — otherwise a new week opens already ticked, or
      // the tick resets mid-week.
      expect(weekKey(within), weekKey(saturday));
    }

    final nextSaturday = saturday.add(const Duration(days: 7));
    expect(
      weeklyMission(nextSaturday).titleKey,
      isNot(weeklyMission(saturday).titleKey),
    );
    expect(weekKey(nextSaturday), isNot(weekKey(saturday)));
  });

  test('the turnover lands on Saturday, not mid-week', () {
    // The bug this guards: epoch day 0 is a Thursday, so the obvious
    // `epochDay ~/ 7` rolled the mission over on Thursdays while the rest
    // of the app (tracker week strip, weekly notification) starts its week
    // on Saturday.
    final start = DateTime(2026, 1, 1);
    for (var day = 0; day < 60; day++) {
      final today = start.add(Duration(days: day));
      final yesterday = today.subtract(const Duration(days: 1));
      final changed =
          weeklyMission(today).titleKey != weeklyMission(yesterday).titleKey;
      if (changed) {
        expect(
          today.weekday,
          DateTime.saturday,
          reason: 'mission changed on a ${today.weekday}, not a Saturday',
        );
      }
    }
  });

  test('a year of weeks shows every mission exactly once', () {
    final start = DateTime(2026, 1, 3); // a Saturday
    final seen = <String>[];
    for (var week = 0; week < kWeeklyMissions.length; week++) {
      seen.add(weeklyMission(start.add(Duration(days: week * 7))).titleKey);
    }

    expect(kWeeklyMissions, hasLength(52), reason: 'one per week of the year');
    expect(
      seen.toSet(),
      hasLength(kWeeklyMissions.length),
      reason: 'no mission repeats before the whole list has been shown',
    );
  });

  test('every mission is distinct and has both a title and a detail', () {
    expect(
      kWeeklyMissions.map((m) => m.titleKey).toSet(),
      hasLength(kWeeklyMissions.length),
    );
    expect(
      kWeeklyMissions.map((m) => m.detailKey).toSet(),
      hasLength(kWeeklyMissions.length),
    );
  });
}
