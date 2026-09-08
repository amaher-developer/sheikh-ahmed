import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_providers.dart';

/// Rebuild counters for two probes watching different prayer providers.
int _nextPrayerBuilds = 0;
int _todayTimesBuilds = 0;

class _Probes extends ConsumerWidget {
  const _Probes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Consumer(
          builder: (context, ref, _) {
            // Legitimately ticks: it carries `now` for the countdown.
            ref.watch(nextPrayerProvider);
            _nextPrayerBuilds++;
            return const SizedBox();
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            ref.watch(todayPrayerTimesProvider);
            _todayTimesBuilds++;
            return const SizedBox();
          },
        ),
      ],
    );
  }
}

void main() {
  testWidgets(
    "today's prayer times are computed per day, not per 30-second tick",
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );

      _nextPrayerBuilds = 0;
      _todayTimesBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs!)],
          child: const MaterialApp(home: _Probes()),
        ),
      );
      await tester.pump();

      final todayAfterFirstFrame = _todayTimesBuilds;
      final nextAfterFirstFrame = _nextPrayerBuilds;

      // Six ticks of nowProvider's 30-second stream.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 30));
      }

      // Sanity check on the test itself: if the clock never ticked, the
      // assertion below would pass for the wrong reason.
      expect(
        _nextPrayerBuilds,
        greaterThan(nextAfterFirstFrame),
        reason: 'nowProvider must actually be ticking for this test to mean '
            'anything',
      );

      // The real assertion. todayPrayerTimesProvider used to watch the same
      // tick, so it re-ran the full astronomical calculation — and rebuilt
      // everything downstream — twice a minute, for a value that can only
      // change at midnight.
      expect(
        _todayTimesBuilds,
        todayAfterFirstFrame,
        reason: "today's times must not recompute on a clock tick",
      );
    },
  );
}
