import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/weekly_mission_data.dart';
import '../prayer/hijri_date_service.dart';
import '../prayer/next_prayer.dart';
import '../prayer/prayer_settings.dart';
import '../prayer/prayer_times_service.dart';
import '../utils/arabic_numerals.dart';
import 'azkar_widget_channel.dart';

/// Publishes a snapshot of what the home-screen widget shows into
/// SharedPreferences, where the native widget provider reads it.
///
/// The widget can't call into Dart: Android updates it on its own schedule
/// with the Flutter engine not running at all (that's why the rotating
/// dhikr is bundled natively). Anything the widget needs that only Dart
/// knows — computed prayer times, the Hijri date, this week's mission —
/// therefore has to be written out ahead of time and simply read back.
///
/// Written as pre-formatted display strings rather than raw numbers on
/// purpose: formatting means locale, Arabic-Indic digits and 12-hour
/// conversion, all of which already exist on the Dart side, and none of
/// which is worth reimplementing in Kotlin where it would drift.
class WidgetDataService {
  final SharedPreferences _prefs;
  final HijriDateService _hijri;

  const WidgetDataService(this._prefs, this._hijri);

  // Read on the native side as "flutter." + these names — the Dart
  // shared_preferences API prefixes every key it writes (see
  // AzkarWidgetProvider.kt, which prepends the same prefix).
  static const kUpdatedAt = 'widget.updatedAt';
  static const kDateLine = 'widget.dateLine';
  static const kNextLabel = 'widget.nextPrayerLabel';
  static const kNextTime = 'widget.nextPrayerTime';
  static const kPrayerNames = 'widget.prayerNames';
  static const kPrayerTimes = 'widget.prayerTimes';
  static const kMission = 'widget.missionTitle';

  /// The app's language, persisted so a publish triggered from somewhere
  /// without a BuildContext still formats in the language the user is
  /// actually reading.
  ///
  /// This can't come from `Intl.getCurrentLocale()`: easy_localization
  /// doesn't set Intl's ambient locale, so that reports the *system*
  /// locale and returned "en" on an Arabic install — which is why the
  /// widget rendered "17 Rabī al-awwal 1448" and "5:00" instead of Arabic
  /// month names and Arabic-Indic digits, while the prayer names beside
  /// them were correct (those come from `.tr()`).
  static const kLanguage = 'widget.language';

  /// Separator for the packed prayer name/time lists. A vertical bar can't
  /// occur inside a translated prayer name or a formatted clock time, so
  /// splitting on it on the Kotlin side is unambiguous.
  static const _sep = '|';

  /// Recomputes and writes the snapshot, then asks Android to redraw any
  /// placed widgets so the change is visible immediately instead of at the
  /// next 30-minute refresh.
  ///
  /// Safe to call often — it's a handful of string writes. Failures are
  /// swallowed: a stale widget is a much smaller problem than an exception
  /// escaping into app startup.
  /// [languageCode] should be passed whenever a BuildContext is in reach
  /// (`context.locale.languageCode`); it's remembered so calls made without
  /// one still format correctly. Defaults to Arabic, matching the app's own
  /// startLocale and fallbackLocale.
  Future<void> publish({
    required PrayerSettings settings,
    /// Passed in rather than computed here, so the widget cannot end up
    /// showing a different mission from the home card — during Ramadan the
    /// two lists differ, and each would pick its own.
    required WeeklyMission mission,
    String? languageCode,
    DateTime? now,
  }) async {
    try {
      if (languageCode != null) {
        await _prefs.setString(kLanguage, languageCode);
      }
      final arabic = (languageCode ?? _prefs.getString(kLanguage) ?? 'ar') != 'en';
      final today = now ?? DateTime.now();
      const service = PrayerTimesService();
      final times = service.calculate(
        date: today,
        coordinates: settings.coordinates,
        method: settings.method,
        madhab: settings.madhab,
      );

      final ordered = times.ordered;
      final labels = [
        for (final key in DailyPrayerTimes.labelKeys) key.tr(),
      ];
      final formatted = [
        for (final t in ordered) formatClockTime(t, arabicDigits: arabic),
      ];

      DailyPrayerTimes forDay(DateTime date) => service.calculate(
        date: date,
        coordinates: settings.coordinates,
        method: settings.method,
        madhab: settings.madhab,
      );
      final next = computeNextPrayer(
        now: today,
        today: times,
        computeYesterday: () =>
            forDay(today.subtract(const Duration(days: 1))),
        computeTomorrow: () => forDay(today.add(const Duration(days: 1))),
      );

      await _prefs.setString(kPrayerNames, labels.join(_sep));
      await _prefs.setString(kPrayerTimes, formatted.join(_sep));
      await _prefs.setString(kNextLabel, labels[next.prayerIndex]);
      await _prefs.setString(
        kNextTime,
        formatClockTime(next.prayerTime, arabicDigits: arabic),
      );
      await _prefs.setString(kMission, mission.titleKey.tr());
      await _prefs.setString(kDateLine, await _dateLine(today, arabic));
      await _prefs.setString(
        kUpdatedAt,
        '${today.millisecondsSinceEpoch}',
      );

      await AzkarWidgetChannel.refresh();
    } catch (error, stack) {
      debugPrint('Widget snapshot skipped: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// "١٥ رمضان ١٤٤٧" when the Hijri conversion is available, falling back
  /// to the Gregorian date when it isn't — the conversion is a network
  /// call (see HijriDateService for why it isn't computed locally), and a
  /// widget with no date at all is worse than one showing the Gregorian.
  Future<String> _dateLine(DateTime date, bool arabic) async {
    try {
      final hijri = await _hijri.fetch(date);
      final month = arabic ? hijri.monthAr : hijri.monthEn;
      final day = arabic ? toArabicDigits('${hijri.day}') : '${hijri.day}';
      final year = arabic ? toArabicDigits('${hijri.year}') : '${hijri.year}';
      return '$day $month $year';
    } catch (_) {
      final d = arabic ? toArabicDigits('${date.day}') : '${date.day}';
      final m = arabic ? toArabicDigits('${date.month}') : '${date.month}';
      final y = arabic ? toArabicDigits('${date.year}') : '${date.year}';
      return '$d/$m/$y';
    }
  }
}
