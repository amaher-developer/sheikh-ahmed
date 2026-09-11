import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../prayer/prayer_times_service.dart';
import 'adhan_audio.dart';

// Notification id base ranges, kept far enough apart (100+ per kind, well
// under the 3-7 days actually scheduled) that none of these can collide
// with AdhanScheduler.notificationId's 1000s range or each other.
const kMorningAzkarReminderBaseId = 2000;
const kEveningAzkarReminderBaseId = 2100;
const kWirdReminderBaseId = 2200;
const kSurahOfDayReminderBaseId = 2300;
const kMiddayTrackerReminderBaseId = 2400;
const kDailyMessageReminderBaseId = 2500;
const kWeeklyMissionReminderBaseId = 2600;

/// Well clear of the other kinds' 100-slot ranges: the dhikr reminders are
/// the only ones that fire many times a day, so they need room for
/// days x times-per-day entries rather than one per day.
const kDhikrReminderBaseId = 3000;

const kAzkarReminderChannelId = 'com.sheikhahmed.sheikh_ahmed_app.azkar';
const kWirdReminderChannelId = 'com.sheikhahmed.sheikh_ahmed_app.wird';
const kSurahOfDayChannelId = 'com.sheikhahmed.sheikh_ahmed_app.surah_of_day';
const kDailyMessageChannelId = 'com.sheikhahmed.sheikh_ahmed_app.daily_message';
const kWeeklyMissionChannelId = 'com.sheikhahmed.sheikh_ahmed_app.weekly_mission';

/// Its own channel, separate from the azkar one, precisely because these
/// arrive several times a day: anyone who finds them too frequent can mute
/// this channel from the system's notification settings without losing the
/// morning/evening azkar reminders too.
const kDhikrReminderChannelId = 'com.sheikhahmed.sheikh_ahmed_app.dhikr';

/// iOS's cap on pending local notifications.
const kIosPendingNotificationLimit = 64;

/// How far ahead each kind of notification is scheduled.
///
/// iOS keeps only the 64 notifications that were scheduled *last* and
/// silently drops the rest (flutter_local_notifications' README, "iOS
/// pending notifications limit"). A week of everything is about 130 — five
/// adhans, six daily reminders and seven dhikr a day, plus the weekly
/// mission — and the adhans are scheduled first, so they were exactly the
/// ones iOS threw away: with reminders on, no adhan notification arrived.
///
/// So iOS keeps the adhan's full week and gives the reminders what is left.
/// Anyone who opens the app every day or two loses nothing, since each
/// launch and resume rolls the window forward (see AdhanWatcher). Android
/// has no such cap and keeps a week of everything.
class NotificationWindow {
  final int adhanDays;
  final int dailyReminderDays;
  final int dhikrDays;
  final int weeklyMissionWeeks;

  const NotificationWindow({
    required this.adhanDays,
    required this.dailyReminderDays,
    required this.dhikrDays,
    required this.weeklyMissionWeeks,
  });

  static const standard = NotificationWindow(
    adhanDays: 7,
    dailyReminderDays: 7,
    dhikrDays: 7,
    weeklyMissionWeeks: 4,
  );

  /// At most 35 adhans + 6 daily kinds x 2 + 7 dhikr x 2 + 2 weekly = 63.
  static const ios = NotificationWindow(
    adhanDays: 7,
    dailyReminderDays: 2,
    dhikrDays: 2,
    weeklyMissionWeeks: 2,
  );

  static NotificationWindow get current =>
      defaultTargetPlatform == TargetPlatform.iOS ? ios : standard;
}

/// Schedules a local notification at each of the five prayer times so the
/// adhan reaches the user even when the app isn't open. The notification
/// carries the prayer index in its payload; tapping it (or having the app
/// in the foreground at that moment) is what triggers adhan playback
/// through the existing audio handler — see AdhanController.
class AdhanScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  AdhanScheduler(this._plugin);

  /// One channel *per adhan voice*, rather than a single "الأذان" channel.
  ///
  /// A channel's sound is locked in the first time Android creates it and
  /// can never be changed afterward — not by passing a different sound
  /// later, and not by deleting and recreating the channel, since Android
  /// deliberately restores a recreated channel's previous settings so apps
  /// can't reset a user's customisations. So a channel simply cannot
  /// follow the voice picker. Giving each voice its own channel is the
  /// only way the chosen adhan actually plays at prayer time.
  ///
  /// The suffix is the voice id, and _v4 carries the same meaning it did
  /// when there was one channel: _v2 and _v3 were created on test devices
  /// while the adhan sound couldn't resolve, so those ids are permanently
  /// stuck on the default notification tone — the "azan comes with the
  /// default sound" symptom — and could only be escaped by a new id.
  static String channelIdFor(AdhanVoice voice) =>
      'com.sheikhahmed.sheikh_ahmed_app.adhan_v4_${voice.id}';

  /// Named per voice so the four entries are tellable apart in the
  /// system's notification settings instead of reading as four
  /// indistinguishable "الأذان" rows.
  static String channelNameFor(String voiceName) => 'الأذان — $voiceName';

  /// Deleted on startup so they don't linger as dead entries in the
  /// system's per-app notification settings.
  static const _supersededChannelIds = [
    'com.sheikhahmed.sheikh_ahmed_app.adhan',
    'com.sheikhahmed.sheikh_ahmed_app.adhan_v2',
    'com.sheikhahmed.sheikh_ahmed_app.adhan_v3',
    'com.sheikhahmed.sheikh_ahmed_app.adhan_v4',
    // The Egyptian voice was removed; its channel would otherwise sit in
    // the system's notification settings forever, since a channel outlives
    // the code that created it.
    'com.sheikhahmed.sheikh_ahmed_app.adhan_v4_a3',
  ];

  /// The voice's recording, bundled at build time as an Android raw
  /// resource (android/app/src/main/res/raw/), so the *notification itself*
  /// plays the real adhan call — not a generic ding — even when the app is
  /// fully closed. A scheduled local notification can only reference a
  /// sound already on the device (a raw resource, or a content:// URI); it
  /// cannot stream or reference a remote URL, which is why this can't just
  /// point at the same aladhan.com URLs used for in-app playback and
  /// previews. iOS can't use these files as they are, so it has its own
  /// half-minute copies — see [AdhanVoice.iosNotificationSound].
  static RawResourceAndroidNotificationSound soundFor(AdhanVoice voice) =>
      RawResourceAndroidNotificationSound(voice.rawResource);

  /// Notification ids are derived from the prayer index so re-scheduling
  /// replaces the previous day's entry instead of stacking duplicates.
  static int notificationId(int dayOffset, int prayerIndex) =>
      1000 + dayOffset * 10 + prayerIndex;

  /// Creates [voice]'s channel with its sound *before* anything schedules
  /// on it, and clears out the superseded ids.
  ///
  /// The plugin would otherwise create the channel lazily, on whichever
  /// call first mentions it. That's what made the sound so fragile: the
  /// channel got its permanent, unchangeable sound from whatever state the
  /// app happened to be in at that first call. Creating it here from one
  /// explicit definition makes the sound deterministic instead of a side
  /// effect of call ordering.
  ///
  /// Only the selected voice's channel is created, not all four, so a user
  /// who never changes voice only ever sees one adhan channel in system
  /// settings.
  static Future<void> ensureAdhanChannel(
    FlutterLocalNotificationsPlugin plugin,
    AdhanVoice voice,
    String voiceName,
  ) async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    for (final stale in _supersededChannelIds) {
      await android.deleteNotificationChannel(stale);
    }
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        channelIdFor(voice),
        channelNameFor(voiceName),
        importance: Importance.max,
        playSound: true,
        sound: soundFor(voice),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  static bool _tzReady = false;

  /// Loads the timezone database once. Required before any zonedSchedule
  /// call — without it the plugin throws on the first schedule.
  static void ensureTimezonesInitialised() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    _tzReady = true;
  }

  /// Android only guarantees an *exact* alarm actually fires at the time it
  /// was set for. An inexact one is deferred to the next Doze maintenance
  /// window, and a phone left untouched — exactly what happens overnight
  /// before Fajr, or all day while the user is at work — may not open one
  /// for many hours, so the whole day's reminders silently never arrive.
  /// That was the cause of "nothing fires all day": every notification here
  /// used to be scheduled inexactly.
  ///
  /// Exactness is never guaranteed here: the app holds SCHEDULE_EXACT_ALARM,
  /// which the user grants and can revoke at any time from system settings
  /// (AndroidManifest.xml explains why USE_EXACT_ALARM is deliberately not
  /// used). [_scheduleMode] stays mutable so a device that refuses degrades
  /// to inexact — late reminders beat none — instead of throwing and taking
  /// every later schedule call down with it.
  static AndroidScheduleMode _scheduleMode =
      AndroidScheduleMode.exactAllowWhileIdle;

  /// Set once the platform has been asked whether exact alarms are permitted,
  /// so the first schedule doesn't have to discover a refusal by throwing.
  ///
  /// Two-way on purpose. The user can grant the permission long after launch,
  /// and a one-way latch would leave every alarm inexact until the next cold
  /// start even though the OS would honour exact ones by then.
  static void setExactAlarmsAllowed(bool allowed) => _scheduleMode = allowed
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  static void useInexactAlarms() => setExactAlarmsAllowed(false);

  /// The single funnel every scheduled notification in this class goes
  /// through, so the exact→inexact fallback is written once rather than
  /// repeated at all three call sites.
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
  }) async {
    final when = tz.TZDateTime.from(at, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: _scheduleMode,
        // Prayer times are absolute instants, so they must be interpreted
        // as wall-clock time in the device's zone (matters on iOS < 10).
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } on PlatformException {
      // Only 'exact_alarms_not_permitted' is recoverable, and only once —
      // if we're already inexact the failure is something else entirely and
      // belongs with the caller.
      if (_scheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      useInexactAlarms();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Cancels previously scheduled adhans and schedules the upcoming ones
  /// for the next [days] days. Called whenever the prayer settings change
  /// (city, method, madhab) since those move every time, and every app
  /// launch (see AdhanWatcher) — which is the *only* thing that extends
  /// this window, since there's no background service re-running it.
  /// [days] defaults to a full week (matching cancelAll's own cleanup
  /// range) rather than 3, so notifications don't quietly stop firing if
  /// the app just isn't opened for a few days.
  ///
  /// [timesForDay] supplies the computed times for a given date, so this
  /// stays free of the calculation and location plumbing.
  Future<void> reschedule({
    required DailyPrayerTimes Function(DateTime date) timesForDay,
    required String Function(String labelKey) translate,
    required String bodyText,
    required AdhanVoice voice,
    required String voiceName,
    int days = 7,
    DateTime? now,
  }) async {
    ensureTimezonesInitialised();
    await cancelAll();

    final start = now ?? DateTime.now();
    for (var dayOffset = 0; dayOffset < days; dayOffset++) {
      final date = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: dayOffset));
      final times = timesForDay(date).ordered;

      for (var i = 0; i < times.length; i++) {
        final at = times[i];
        // Skip times that have already passed — zonedSchedule would either
        // fire immediately or throw depending on platform.
        if (!at.isAfter(start)) continue;

        await _schedule(
          id: notificationId(dayOffset, i),
          title: translate(DailyPrayerTimes.labelKeys[i]),
          body: bodyText,
          at: at,
          details: NotificationDetails(
            android: AndroidNotificationDetails(
              channelIdFor(voice),
              channelNameFor(voiceName),
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.alarm,
              playSound: true,
              sound: soundFor(voice),
              audioAttributesUsage: AudioAttributesUsage.alarm,
            ),
            iOS: DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.timeSensitive,
              sound: voice.iosNotificationSound,
              // Silent only while the app is in the foreground, where
              // AdhanWatcher is already playing the full adhan and the clip
              // would start a second copy over it.
              presentSound: false,
            ),
          ),
          payload: 'adhan:$i',
        );
      }
    }
  }

  Future<void> cancelAll() async {
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      for (var i = 0; i < DailyPrayerTimes.labelKeys.length; i++) {
        await _plugin.cancel(notificationId(dayOffset, i));
      }
    }
  }

  /// A single reminder fired once a day at a time derived from that day's
  /// prayer times (e.g. "10 minutes after Fajr" for the morning azkar) —
  /// shared by the azkar and daily-wird reminders, which otherwise repeat
  /// this same day-loop/skip-past/zonedSchedule structure as [reschedule].
  ///
  /// [baseId] must be unique per reminder kind (distinct from
  /// [notificationId]'s 1000s range and from other reminder kinds) so
  /// rescheduling replaces that kind's own entries rather than colliding.
  Future<void> scheduleDaily({
    required int baseId,
    required DailyPrayerTimes Function(DateTime date) timesForDay,
    required DateTime Function(DailyPrayerTimes times) timeOfDay,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    int days = 7,
    DateTime? now,
  }) => scheduleDailyVarying(
    baseId: baseId,
    timesForDay: timesForDay,
    timeOfDay: timeOfDay,
    title: (_) => title,
    body: (_) => body,
    channelId: channelId,
    channelName: channelName,
    days: days,
    now: now,
  );

  /// Same as [scheduleDaily], but [title]/[body] are computed per day
  /// instead of being fixed strings — e.g. a different random surah name
  /// each day for the "surah of the day" reminder.
  Future<void> scheduleDailyVarying({
    required int baseId,
    required DailyPrayerTimes Function(DateTime date) timesForDay,
    required DateTime Function(DailyPrayerTimes times) timeOfDay,
    required String Function(DateTime date) title,
    required String Function(DateTime date) body,
    required String channelId,
    required String channelName,
    int days = 7,
    DateTime? now,
  }) async {
    ensureTimezonesInitialised();
    await cancelDaily(baseId: baseId, days: 7);

    final start = now ?? DateTime.now();
    for (var dayOffset = 0; dayOffset < days; dayOffset++) {
      final date = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: dayOffset));
      final at = timeOfDay(timesForDay(date));
      if (!at.isAfter(start)) continue;

      await _schedule(
        id: baseId + dayOffset,
        title: title(date),
        body: body(date),
        at: at,
        details: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
    }
  }

  /// A short dhikr several times a day, at [hours] on each of the next
  /// [days] days.
  ///
  /// Unlike every other reminder here this fires many times a day, so it
  /// needs its own id range and its own channel. Hours are given as a
  /// waking-hours list rather than a plain "every N hours" interval — a
  /// reminder at 3am is a reason to turn the whole feature off.
  ///
  /// [phraseFor] is passed the running index so the caller can walk its own
  /// rotation and no two consecutive reminders repeat.
  Future<void> scheduleHourlyDhikr({
    required int baseId,
    required List<int> hours,
    required String title,
    required String Function(int index) phraseFor,
    required String channelId,
    required String channelName,
    int days = 7,
    DateTime? now,
  }) async {
    ensureTimezonesInitialised();
    await cancelDaily(baseId: baseId, days: days * hours.length);

    // The same list the card over other apps is built from — see
    // [dhikrReminderInstants]. Shared rather than recomputed so the two
    // cannot land on different minutes.
    final reminders = dhikrReminderInstants(
      hours: hours,
      phraseFor: phraseFor,
      days: days,
      now: now,
    );

    for (var slot = 0; slot < reminders.length; slot++) {
      final reminder = reminders[slot];
      {
        final id = baseId + slot;

        await _schedule(
          id: id,
          title: title,
          body: reminder.text,
          at: reminder.at,
          details: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: const DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.passive,
            ),
          ),
        );
      }
    }
  }

  Future<void> cancelDaily({required int baseId, int days = 7}) async {
    for (var dayOffset = 0; dayOffset < days; dayOffset++) {
      await _plugin.cancel(baseId + dayOffset);
    }
  }

  /// Like [scheduleDailyVarying], but one occurrence per *week* instead of
  /// per day — for the weekly-mission reminder, which would be noise if it
  /// fired daily. Anchored to the upcoming Saturday, the same start-of-week
  /// convention the tracker's week strip uses (see saturdayWeekIndex in
  /// tracker_providers.dart), so "weekly" lands on a predictable day.
  Future<void> scheduleWeekly({
    required int baseId,
    required DateTime Function(DateTime weekStart) timeOfDay,
    required String Function(DateTime weekStart) title,
    required String Function(DateTime weekStart) body,
    required String channelId,
    required String channelName,
    int weeks = 4,
    DateTime? now,
  }) async {
    ensureTimezonesInitialised();
    await cancelDaily(baseId: baseId, days: weeks + 1);

    final start = now ?? DateTime.now();
    final today = DateTime(start.year, start.month, start.day);
    // DateTime.weekday: Mon=1..Sun=7, so Saturday=6.
    final daysUntilSaturday = (6 - today.weekday + 7) % 7;
    final firstSaturday = today.add(Duration(days: daysUntilSaturday));

    for (var w = 0; w < weeks; w++) {
      final weekStart = firstSaturday.add(Duration(days: w * 7));
      final at = timeOfDay(weekStart);
      if (!at.isAfter(start)) continue;

      await _schedule(
        id: baseId + w,
        title: title(weekStart),
        body: body(weekStart),
        at: at,
        details: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
    }
  }
}

/// One upcoming prayer, for the native alarm scheduler.
class UpcomingPrayer {
  final DateTime at;
  final String labelKey;

  const UpcomingPrayer({required this.at, required this.labelKey});
}

/// How many alarm slots the native side reserves for the adhan.
///
/// 7 days x 5 prayers. Used as the cancel range too, so a schedule that
/// shrinks — fewer days, adhan switched off — clears the slots it no
/// longer fills instead of leaving orphaned alarms behind.
const kAdhanAlarmSlots = 7 * 5;

/// How many alarm slots the native side reserves for the dhikr cards.
///
/// A fixed ceiling of 7 days x 8 reminders rather than the length of
/// [kDhikrReminderHours], because the native side cancels this many
/// slots and cannot read a Dart constant: shortening the hours list
/// must still clear the slots the longer one filled.
const kZikrAlarmSlots = 7 * 8;

/// One dhikr reminder: when, and what it says.
class DhikrReminder {
  final DateTime at;
  final String text;

  const DhikrReminder({required this.at, required this.text});
}

/// Every dhikr reminder still ahead, in order.
///
/// Both the notification and the card over other apps are built from
/// this one list. Computing them separately would let the two drift
/// onto different minutes, and a card that does not match the
/// notification beside it reads as a bug in both.
List<DhikrReminder> dhikrReminderInstants({
  required List<int> hours,
  required String Function(int index) phraseFor,
  int days = 7,
  DateTime? now,
}) {
  final start = now ?? DateTime.now();
  final result = <DhikrReminder>[];
  for (var dayOffset = 0; dayOffset < days; dayOffset++) {
    final date = DateTime(
      start.year,
      start.month,
      start.day,
    ).add(Duration(days: dayOffset));
    for (var i = 0; i < hours.length; i++) {
      final at = DateTime(date.year, date.month, date.day, hours[i]);
      if (!at.isAfter(start)) continue;
      result.add(
        DhikrReminder(
          // Indexed by absolute slot, not by hour, so the phrase
          // advances across days instead of showing the same one
          // every day at 9am.
          at: at,
          text: phraseFor(dayOffset * hours.length + i),
        ),
      );
    }
  }
  return result;
}

/// Every prayer instant in the next [days] days that is still in the
/// future, in order.
///
/// Split out from AdhanScheduler.reschedule because the native alarm path
/// needs the same instants that method computes, but as plain data rather
/// than as scheduled notifications.
List<UpcomingPrayer> upcomingPrayerInstants({
  required DailyPrayerTimes Function(DateTime date) timesForDay,
  required DateTime now,
  int days = 7,
}) {
  final result = <UpcomingPrayer>[];
  for (var dayOffset = 0; dayOffset < days; dayOffset++) {
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: dayOffset));
    final times = timesForDay(date).ordered;
    for (var i = 0; i < times.length; i++) {
      // A past instant would fire the moment it is registered.
      if (!times[i].isAfter(now)) continue;
      result.add(
        UpcomingPrayer(at: times[i], labelKey: DailyPrayerTimes.labelKeys[i]),
      );
    }
  }
  return result;
}
