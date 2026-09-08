import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prayer/next_prayer.dart';
import '../prayer/prayer_providers.dart';
import '../prayer/prayer_times_service.dart';
import 'adhan_alarm_channel.dart';
import 'adhan_providers.dart';

/// Plays the adhan the moment a prayer time arrives while the app is open.
///
/// The scheduled notifications (see [AdhanScheduler]) cover the app being
/// closed; this covers the app being in the foreground, where a
/// notification alone would be easy to miss. Wrapped around the app shell
/// so it's alive for the whole session.
class AdhanWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const AdhanWatcher({super.key, required this.child});

  @override
  ConsumerState<AdhanWatcher> createState() => _AdhanWatcherState();
}

class _AdhanWatcherState extends ConsumerState<AdhanWatcher>
    with WidgetsBindingObserver {
  /// The prayer instant we've already sounded, so a rebuild inside the same
  /// minute doesn't replay the adhan.
  DateTime? _lastPlayedFor;
  bool _scheduledOnce = false;

  /// When the schedule was last extended. Rescheduling covers a 7-day
  /// window, so re-running it roughly daily keeps that window rolling
  /// forward; more often than that is wasted work on every app switch.
  DateTime? _lastScheduledAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Scheduling used to happen exactly once per process. A session that
    // stays alive in memory for over a week — normal on a phone that never
    // runs out of RAM — would run off the end of its 7-day window and go
    // silent with no way to notice. Coming back to the foreground is the
    // natural moment to roll the window forward.
    if (state != AppLifecycleState.resumed) return;
    final last = _lastScheduledAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 12)) {
      return;
    }
    _reschedule();
  }

  void _reschedule() {
    _lastScheduledAt = DateTime.now();
    // This is the one reschedule trigger with a BuildContext in reach, so
    // it's where the widget snapshot's language comes from — see
    // WidgetDataService.kLanguage for why it can't be read globally.
    ref
        .read(adhanReschedulerProvider)
        .run(languageCode: context.locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    // Registering the upcoming notifications needs the provider graph, so
    // it happens here on first build rather than in main().
    if (!_scheduledOnce) {
      _scheduledOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reschedule());
    }

    // Prayer times move whenever location/method/madhab changes — without
    // this, notifications already scheduled from the *old* settings would
    // keep firing at the wrong times until the app was restarted.
    ref.listen(prayerSettingsProvider, (previous, next) {
      if (previous != null && previous != next) {
        _reschedule();
      }
    });

    // listen, not watch. This widget's child is the entire app shell, and
    // nextPrayerProvider re-emits every 30 seconds (it carries `now` for the
    // countdown, and NextPrayerResult has no value equality, so every tick
    // is a new value). Watching it here rebuilt all five tab screens twice a
    // minute — the IndexedStack keeps them all mounted — for a value this
    // widget only needs in order to decide whether to sound the adhan.
    // Listening reacts to the same ticks without rebuilding anything.
    ref.listen(nextPrayerProvider, (previous, next) {
      _maybeSoundAdhan(next);
    });

    return widget.child;
  }

  void _maybeSoundAdhan(NextPrayerResult next) {
    final settings = ref.read(adhanSettingsProvider);

    if (settings.enabled) {
      // `prayerTime` is by definition still in the future, so the prayer
      // that has *just* become due is `windowStart` — the boundary we just
      // crossed. Its index is one before the upcoming prayer's (wrapping
      // round to Isha when the next one is Fajr).
      final justPassed = next.windowStart;
      final justPassedIndex =
          (next.prayerIndex - 1 + DailyPrayerTimes.labelKeys.length) %
          DailyPrayerTimes.labelKeys.length;

      // nowProvider ticks every 30s, so the boundary is caught within that
      // window. The short window also means an app opened long after a
      // prayer doesn't sound a stale adhan.
      final sinceDue = next.now.difference(justPassed);
      final justDue =
          !sinceDue.isNegative && sinceDue < const Duration(minutes: 2);

      if (justDue && _lastPlayedFor != justPassed) {
        _lastPlayedFor = justPassed;
        final labelKey = DailyPrayerTimes.labelKeys[justPassedIndex];
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            // The native service plays the adhan whether the app is open or
            // not, so opening the app during one used to start a second copy
            // over the top of it: this state is rebuilt on every launch, so
            // _lastPlayedFor is null again and the prayer is still inside the
            // two-minute window. Two adhans at once, each with a separate
            // stop control — which is why neither seemed to stop it.
            //
            // Asked rather than inferred from the exact-alarm permission: the
            // service can also be sounding a prayer from before this state
            // existed, and only the service itself knows.
            if (await AdhanAlarmChannel.isPlaying()) return;
            await playAdhan(ref, prayerLabelKey: labelKey);
          } catch (error, stack) {
            // Fire-and-forget from a postFrameCallback: an uncaught
            // rejection here would otherwise vanish silently, leaving the
            // adhan simply not heard with no trace of why.
            debugPrint('Adhan playback failed: $error');
            debugPrintStack(stackTrace: stack);
          }
        });
      }
    }
  }
}
