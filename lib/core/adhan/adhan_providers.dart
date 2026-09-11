import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_providers.dart';
import '../home/daily_quote_data.dart';
import '../home/weekly_mission_data.dart';
import '../prayer/prayer_providers.dart';
import '../prayer/prayer_times_service.dart';
import '../quran/surah_meta.dart';
import '../widget/widget_data_service.dart';
import '../home/weekly_mission_providers.dart';
import '../ramadan/ramadan_providers.dart';
import '../ramadan/ramadan_status.dart';
import 'adhan_alarm_channel.dart';
import 'adhan_audio.dart';
import 'dhikr_phrases.dart';
import 'adhan_scheduler.dart';

/// How long a prayer-anchored reminder waits after the adhan it's tied to.
///
/// These reminders stay anchored to prayer times rather than fixed clock
/// times, but they must not land *on* the adhan: the adhan notification
/// plays the full call, so a reminder firing at the same instant talks over
/// it and gets buried underneath it in the notification shade. The evening
/// azkar used to fire exactly at Asr and the tracker check-in exactly at
/// Dhuhr, which is precisely that collision.
const _afterAdhanGap = Duration(minutes: 15);

/// The daily wird keeps a longer gap than [_afterAdhanGap] — it's the last
/// call of the night rather than a follow-on to the adhan, so it sits
/// further back from Isha.
const _wirdAfterIshaGap = Duration(minutes: 20);

/// Waking hours at which a short dhikr is pushed — roughly every two hours
/// from mid-morning to late evening. A fixed list rather than an interval
/// so nothing lands overnight: a dhikr at 3am is a reason to switch the
/// whole feature off.
const kDhikrReminderHours = <int>[9, 11, 13, 15, 17, 19, 21];

/// Picks a surah for [date] deterministically — seeded from the calendar
/// date itself, not just `Random()` — so every reschedule (settings
/// change, app reopen) lands on the *same* "surah of the day" for a given
/// date instead of re-rolling it each time this runs.
Surah surahOfTheDay(DateTime date) {
  final seed = date.year * 10000 + date.month * 100 + date.day;
  final index = Random(seed).nextInt(kAllSurahs.length);
  return kAllSurahs[index];
}

/// Overridden in main() once the plugin has been initialised.
final notificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((
  ref,
) {
  throw UnimplementedError(
    'notificationsPluginProvider must be overridden in main()',
  );
});

final adhanSchedulerProvider = Provider<AdhanScheduler>((ref) {
  return AdhanScheduler(ref.watch(notificationsPluginProvider));
});

class AdhanSettings {
  final bool enabled;
  final String voiceId;

  const AdhanSettings({required this.enabled, required this.voiceId});

  AdhanVoice get voice => findAdhanVoice(voiceId);

  AdhanSettings copyWith({bool? enabled, String? voiceId}) => AdhanSettings(
    enabled: enabled ?? this.enabled,
    voiceId: voiceId ?? this.voiceId,
  );
}

class AdhanSettingsRepository {
  final SharedPreferences _prefs;
  AdhanSettingsRepository(this._prefs);

  static const _kEnabled = 'adhan.enabled';
  static const _kVoice = 'adhan.voice';

  /// The generic "Egyptian adhan" was replaced by the Rifaat Cairo
  /// recording, which is the same adhan from the same city by a named
  /// reciter — and a twentieth of the download. Without this, anyone who
  /// had picked it would silently land back on Makkah, since
  /// findAdhanVoice falls through to the default for an unknown id.
  static const _replacedVoiceIds = {'a3': 'a5'};

  AdhanSettings load() {
    final stored = _prefs.getString(_kVoice);
    return AdhanSettings(
      enabled: _prefs.getBool(_kEnabled) ?? true,
      voiceId:
          _replacedVoiceIds[stored] ?? stored ?? kDefaultAdhanVoice.id,
    );
  }

  Future<void> save(AdhanSettings settings) async {
    await _prefs.setBool(_kEnabled, settings.enabled);
    await _prefs.setString(_kVoice, settings.voiceId);
  }
}

final adhanSettingsRepositoryProvider = Provider<AdhanSettingsRepository>((ref) {
  return AdhanSettingsRepository(ref.watch(sharedPreferencesProvider));
});

class AdhanSettingsNotifier extends StateNotifier<AdhanSettings> {
  final AdhanSettingsRepository _repo;
  final Ref _ref;

  AdhanSettingsNotifier(this._repo, this._ref) : super(_repo.load());

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _repo.save(state);
    await _ref.read(adhanReschedulerProvider).run();
  }

  Future<void> setVoice(AdhanVoice voice) async {
    state = state.copyWith(voiceId: voice.id);
    await _repo.save(state);
    // Each voice has its own notification channel (a channel's sound can
    // never be changed after creation), so already-scheduled adhans still
    // point at the *previous* voice's channel until they're rebuilt.
    // Without this, picking a new adhan changed nothing until something
    // else happened to trigger a reschedule.
    await _ref.read(adhanReschedulerProvider).run();
  }
}

final adhanSettingsProvider =
    StateNotifierProvider<AdhanSettingsNotifier, AdhanSettings>((ref) {
      return AdhanSettingsNotifier(
        ref.watch(adhanSettingsRepositoryProvider),
        ref,
      );
    });

/// The single on/off switch for every *non-adhan* notification kind —
/// azkar, daily wird, surah-of-the-day, the daily ayah/hadith message, and
/// the weekly mission all ride on this one toggle together (previously
/// four separate switches; combined into one at the user's request, so
/// Settings only ever shows two notification switches total: this one and
/// [AdhanSettings.enabled]). Defaults to on, matching this app's prior
/// all-or-nothing behavior, so existing users don't silently lose
/// reminders they already had.
class NotificationTypeSettings {
  final bool azkarEnabled;

  const NotificationTypeSettings({required this.azkarEnabled});

  NotificationTypeSettings copyWith({bool? azkarEnabled}) =>
      NotificationTypeSettings(azkarEnabled: azkarEnabled ?? this.azkarEnabled);
}

class NotificationTypeSettingsRepository {
  final SharedPreferences _prefs;
  NotificationTypeSettingsRepository(this._prefs);

  static const _kAzkar = 'notifications.azkar.enabled';

  NotificationTypeSettings load() => NotificationTypeSettings(
    azkarEnabled: _prefs.getBool(_kAzkar) ?? true,
  );

  Future<void> save(NotificationTypeSettings settings) =>
      _prefs.setBool(_kAzkar, settings.azkarEnabled);
}

final notificationTypeSettingsRepositoryProvider =
    Provider<NotificationTypeSettingsRepository>((ref) {
      return NotificationTypeSettingsRepository(
        ref.watch(sharedPreferencesProvider),
      );
    });

class NotificationTypeSettingsNotifier
    extends StateNotifier<NotificationTypeSettings> {
  final NotificationTypeSettingsRepository _repo;
  final Ref _ref;

  NotificationTypeSettingsNotifier(this._repo, this._ref)
    : super(_repo.load());

  Future<void> setAzkarEnabled(bool value) async {
    state = state.copyWith(azkarEnabled: value);
    await _repo.save(state);
    await _ref.read(adhanReschedulerProvider).run();
  }
}

final notificationTypeSettingsProvider = StateNotifierProvider<
  NotificationTypeSettingsNotifier,
  NotificationTypeSettings
>((ref) {
  return NotificationTypeSettingsNotifier(
    ref.watch(notificationTypeSettingsRepositoryProvider),
    ref,
  );
});

/// Recomputes and re-registers the upcoming adhan notifications. Prayer
/// times shift daily and with every settings change, so this is re-run
/// whenever those inputs change rather than scheduled once at install.
class AdhanRescheduler {
  final Ref _ref;
  const AdhanRescheduler(this._ref);

  /// Runs one scheduling step in isolation. Previously a single try/catch
  /// wrapped every step together, so one failure — a device rejecting a
  /// channel, a single bad prayer time — silently skipped every step after
  /// it, taking the whole day's remaining reminders with it. Each step now
  /// fails alone.
  static Future<void> _guarded(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (error, stack) {
      debugPrint('Notification scheduling failed for $label: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// [languageCode] is only used for the home-screen widget snapshot, and
  /// is passed by the one caller that has a BuildContext (AdhanWatcher).
  /// Everything else here translates through `.tr()`, which resolves the
  /// locale on its own.
  Future<void> run({String? languageCode}) async {
    // Best-effort by design: scheduling legitimately fails when notification
    // permission is denied, when the OS restricts exact alarms, or when no
    // notification plugin is available at all (widget tests). None of those
    // should take the UI down — the in-app AdhanWatcher still sounds the
    // adhan while the app is open.
    try {
      final scheduler = _ref.read(adhanSchedulerProvider);
      final adhanSettings = _ref.read(adhanSettingsProvider);
      final notificationTypes = _ref.read(notificationTypeSettingsProvider);

      // Every reminder kind below needs prayer times regardless of whether
      // the adhan itself is enabled — azkar/wird/etc. are independent
      // toggles now (see NotificationTypeSettings), not riding on adhan's.
      final prayerSettings = _ref.read(prayerSettingsProvider);
      const service = PrayerTimesService();
      DailyPrayerTimes timesForDay(DateTime date) => service.calculate(
        date: date,
        coordinates: prayerSettings.coordinates,
        method: prayerSettings.method,
        madhab: prayerSettings.madhab,
      );

      await _guarded('adhan', () async {
        final voice = adhanSettings.voice;
        String titleFor(String labelKey) =>
            'adhan.time_for'.tr(namedArgs: {'prayer': labelKey.tr()});
        final body = 'adhan.notification_body'.tr();

        // On Android the adhan is played by a foreground service woken by
        // an alarm-clock alarm, not by a notification sound. A notification
        // sound is stopped by the system after a short timeout, which cut
        // the adhan off part way through — see AdhanAlarmChannel. The
        // notification path stays as the fallback (and is what iOS uses),
        // so the adhan is never lost if the channel is unavailable.
        if (AdhanAlarmChannel.isSupported) {
          if (!adhanSettings.enabled) {
            await AdhanAlarmChannel.cancelAll(kAdhanAlarmSlots);
            await scheduler.cancelAll();
            return;
          }
          final upcoming = upcomingPrayerInstants(
            timesForDay: timesForDay,
            now: DateTime.now(),
          );
          final scheduled = await AdhanAlarmChannel.schedule(
            times: [for (final p in upcoming) p.at],
            titles: [for (final p in upcoming) titleFor(p.labelKey)],
            body: body,
            rawResource: voice.rawResource,
            clearUpTo: kAdhanAlarmSlots,
          );
          if (scheduled) {
            // Belt and braces off: the service posts its own notification
            // when it fires, so leaving the scheduled ones in place would
            // show the prayer twice.
            await scheduler.cancelAll();
            return;
          }
        }

        if (adhanSettings.enabled) {
          // Fallback path. The scheduled notification's sound comes from
          // the voice's own channel, so the adhan the user picked is the
          // one that plays — see AdhanScheduler.channelIdFor.
          //
          // Must happen before the first schedule on this channel: the
          // plugin would otherwise create it lazily, and a channel takes
          // its permanent, unchangeable sound from whatever the first call
          // to mention it happened to pass.
          await AdhanScheduler.ensureAdhanChannel(
            _ref.read(notificationsPluginProvider),
            voice,
            voice.nameKey.tr(),
          );
          await scheduler.reschedule(
            timesForDay: timesForDay,
            translate: titleFor,
            bodyText: body,
            voice: voice,
            voiceName: voice.nameKey.tr(),
          );
        } else {
          await scheduler.cancelAll();
        }
      });

      // Azkar, daily wird, surah-of-the-day, the daily ayah/hadith message,
      // and the weekly mission all ride on this single combined toggle —
      // Settings only shows two notification switches total (this one and
      // adhanSettings.enabled above), not one per reminder kind.
      if (notificationTypes.azkarEnabled) {
        await _guarded('morning azkar', () => scheduler.scheduleDaily(
          baseId: kMorningAzkarReminderBaseId,
          timesForDay: timesForDay,
          timeOfDay: (t) => t.fajr.add(_afterAdhanGap),
          title: 'adhan.morning_azkar_title'.tr(),
          body: 'adhan.morning_azkar_body'.tr(),
          channelId: kAzkarReminderChannelId,
          channelName: 'adhan.azkar_channel_name'.tr(),
        ));
        await _guarded('evening azkar', () => scheduler.scheduleDaily(
          baseId: kEveningAzkarReminderBaseId,
          timesForDay: timesForDay,
          // Azkar al-masaa traditionally start from Asr — so anchored to
          // Asr, but offset clear of the Asr adhan itself.
          timeOfDay: (t) => t.asr.add(_afterAdhanGap),
          title: 'adhan.evening_azkar_title'.tr(),
          body: 'adhan.evening_azkar_body'.tr(),
          channelId: kAzkarReminderChannelId,
          channelName: 'adhan.azkar_channel_name'.tr(),
        ));
        await _guarded('wird', () => scheduler.scheduleDaily(
          baseId: kWirdReminderBaseId,
          timesForDay: timesForDay,
          timeOfDay: (t) => t.isha.add(_wirdAfterIshaGap),
          title: 'adhan.wird_reminder_title'.tr(),
          body: 'adhan.wird_reminder_body'.tr(),
          channelId: kWirdReminderChannelId,
          channelName: 'adhan.wird_channel_name'.tr(),
        ));

        // A second, earlier nudge about the daily wird — the Isha reminder
        // above is the last call before bed; this one lands around midday
        // so there's still most of the day left to act on it.
        await _guarded('midday tracker', () => scheduler.scheduleDaily(
          baseId: kMiddayTrackerReminderBaseId,
          timesForDay: timesForDay,
          timeOfDay: (t) => t.dhuhr.add(_afterAdhanGap),
          title: 'adhan.midday_tracker_title'.tr(),
          body: 'adhan.midday_tracker_body'.tr(),
          channelId: kWirdReminderChannelId,
          channelName: 'adhan.wird_channel_name'.tr(),
        ));

        await _guarded('surah of the day', () => scheduler.scheduleDailyVarying(
          baseId: kSurahOfDayReminderBaseId,
          timesForDay: timesForDay,
          timeOfDay: (t) =>
              DateTime(t.fajr.year, t.fajr.month, t.fajr.day, 9, 0),
          title: (date) => 'adhan.surah_of_day_title'.tr(),
          body: (date) => 'adhan.surah_of_day_body'.tr(
            namedArgs: {'surah': surahOfTheDay(date).name},
          ),
          channelId: kSurahOfDayChannelId,
          channelName: 'adhan.surah_of_day_channel_name'.tr(),
        ));

        // Daily ayah/hadith — the same content shown on the home screen's
        // card (see dailyQuote), pushed once a day so it's seen even
        // without opening the app.
        await _guarded('daily message', () => scheduler.scheduleDailyVarying(
          baseId: kDailyMessageReminderBaseId,
          timesForDay: timesForDay,
          timeOfDay: (t) =>
              DateTime(t.fajr.year, t.fajr.month, t.fajr.day, 8, 0),
          title: (date) => (dailyQuote(date).type == DailyQuoteType.hadith
                  ? 'home.hadith_of_day'
                  : 'home.ayah_of_day')
              .tr(),
          body: (date) => dailyQuote(date).text,
          channelId: kDailyMessageChannelId,
          channelName: 'adhan.daily_message_channel_name'.tr(),
        ));

        // This week's mission — announced once a week (see
        // AdhanScheduler.scheduleWeekly), matching the home screen card's
        // own weekly rotation (see weeklyMission).
        // A dhikr through the day, roughly every two waking hours. This is
        // the "keep me remembering God through the day" reminder — it rides
        // on the same combined toggle as the other reminders, but on its
        // own channel so it can be muted separately from the system's
        // notification settings if it's ever too much.
        await _guarded('dhikr through the day', () =>
            scheduler.scheduleHourlyDhikr(
              baseId: kDhikrReminderBaseId,
              hours: kDhikrReminderHours,
              title: 'adhan.dhikr_reminder_title'.tr(),
              phraseFor: dhikrPhrase,
              channelId: kDhikrReminderChannelId,
              channelName: 'adhan.dhikr_channel_name'.tr(),
            ));

        // The same reminders again, as a card over other apps. Built from
        // the one list scheduleHourlyDhikr uses, so the card and the
        // notification are the same dhikr at the same minute — and the
        // native side draws nothing unless "Appear on top" is granted, so
        // this costs nothing on a phone where it is off.
        await _guarded('dhikr cards', () async {
          final reminders = dhikrReminderInstants(
            hours: kDhikrReminderHours,
            phraseFor: dhikrPhrase,
          );
          await AdhanAlarmChannel.scheduleZikr(
            times: [for (final r in reminders) r.at],
            texts: [for (final r in reminders) r.text],
            clearUpTo: kZikrAlarmSlots,
          );
        });

        await _guarded('weekly mission', () => scheduler.scheduleWeekly(
          baseId: kWeeklyMissionReminderBaseId,
          timeOfDay: (weekStart) =>
              DateTime(weekStart.year, weekStart.month, weekStart.day, 9, 0),
          title: (weekStart) => 'adhan.weekly_mission_title'.tr(),
          // Resolved for that week's own date, not today's. These are
          // scheduled weeks ahead, and a run that crosses into Ramadan would
          // otherwise announce a mission from the yearly list while the home
          // card showed the Ramadan one.
          body: (weekStart) {
            final ramadan = ramadanStatusFor(
              weekStart,
              offsetDays: _ref.read(hijriOffsetProvider),
            );
            return missionFor(
              weekStart,
              ramadan: ramadan.isRamadan,
              day: ramadan.day,
            ).titleKey.tr();
          },
          channelId: kWeeklyMissionChannelId,
          channelName: 'adhan.weekly_mission_channel_name'.tr(),
        ));
      } else {
        await scheduler.cancelDaily(baseId: kMorningAzkarReminderBaseId);
        await scheduler.cancelDaily(baseId: kEveningAzkarReminderBaseId);
        await scheduler.cancelDaily(baseId: kWirdReminderBaseId);
        await scheduler.cancelDaily(baseId: kMiddayTrackerReminderBaseId);
        await scheduler.cancelDaily(baseId: kSurahOfDayReminderBaseId);
        await scheduler.cancelDaily(baseId: kDailyMessageReminderBaseId);
        await scheduler.cancelDaily(baseId: kWeeklyMissionReminderBaseId);
        await scheduler.cancelDaily(
          baseId: kDhikrReminderBaseId,
          days: 7 * kDhikrReminderHours.length,
        );
        // And the cards, or they would keep appearing over other apps after
        // the reminders they belong to were switched off.
        await AdhanAlarmChannel.cancelZikr(kZikrAlarmSlots);
      }

      // Outside both branches on purpose: the home-screen widget shows the
      // prayer times this method just computed, and it must keep doing so
      // whether or not the user has notifications switched on — the two
      // are unrelated features. Piggy-backing on this method rather than
      // adding a separate trigger reuses its existing hooks (app start,
      // resume, prayer-settings change), which are exactly the moments the
      // widget's contents can go stale.
      await _guarded('widget snapshot', () async {
        await WidgetDataService(
          _ref.read(sharedPreferencesProvider),
          _ref.read(hijriDateServiceProvider),
        ).publish(
          settings: prayerSettings,
          mission: _ref.read(currentMissionProvider),
          languageCode: languageCode,
        );
      });
    } catch (error, stack) {
      debugPrint('Adhan scheduling skipped: $error');
      debugPrintStack(stackTrace: stack);
    }
  }
}

final adhanReschedulerProvider = Provider<AdhanRescheduler>(
  (ref) => AdhanRescheduler(ref),
);

/// Plays the adhan through the shared audio handler, so it shows up on the
/// lock screen and can be stopped from there like any other playback.
Future<void> playAdhan(WidgetRef ref, {String? prayerLabelKey}) async {
  final voice = ref.read(adhanSettingsProvider).voice;
  final handler = ref.read(audioHandlerProvider);
  // The adhan is a one-off, not part of the Quran surah chain.
  handler.nextItemResolver = null;
  handler.previousItemResolver = null;
  await handler.playMediaItem(
    MediaItem(
      id: voice.url,
      title: prayerLabelKey != null
          ? 'adhan.time_for'.tr(namedArgs: {'prayer': prayerLabelKey.tr()})
          : 'adhan.title'.tr(),
      artist: voice.nameKey.tr(),
    ),
  );
}
