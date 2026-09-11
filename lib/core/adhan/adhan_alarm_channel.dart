import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Schedules the alarms that play the **full** adhan at prayer time.
///
/// This exists because a scheduled notification cannot play a long sound.
/// Android's notification player stops audio after a short timeout, so a
/// three-to-four minute adhan set as a channel sound started on
/// "الله أكبر" and was cut off part way through — a property of that
/// mechanism, which no amount of re-encoding or shrinking the file
/// changes. Instead the native side registers an alarm-clock alarm per
/// prayer, and a foreground service plays the recording to the end (see
/// AdhanAlarmReceiver.kt / AdhanPlaybackService.kt).
///
/// Android only. iOS keeps the notification-sound path, where the same
/// limit applies but there is no equivalent way around it — see
/// AdhanScheduler.
class AdhanAlarmChannel {
  const AdhanAlarmChannel._();

  static const _channel = MethodChannel('com.manassa.sheikhahmed/widget');

  /// True when the native side is reachable, so the caller knows whether
  /// the adhan will be handled here or has to fall back to a notification
  /// sound.
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// Replaces every scheduled dhikr card.
  ///
  /// Separate from the dhikr *notification*, which is unchanged and
  /// still posted by flutter_local_notifications. This only adds the
  /// card over other apps, and the native side shows nothing unless
  /// the user has granted "Appear on top".
  static Future<bool> scheduleZikr({
    required List<DateTime> times,
    required List<String> texts,
    required int clearUpTo,
  }) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('scheduleZikrAlarms', {
        'times': [for (final t in times) t.millisecondsSinceEpoch],
        'texts': texts,
        'clearUpTo': clearUpTo,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Clears them — used when the reminders are switched off.
  static Future<void> cancelZikr(int count) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('cancelZikrAlarms', {
        'count': count,
      });
    } catch (_) {
      // Nothing to cancel, or no native side. Not worth surfacing.
    }
  }

  /// Replaces every scheduled adhan alarm.
  ///
  /// [times] must already be in the future — a past alarm fires the moment
  /// it is set. [clearUpTo] is how many slots to cancel first, so a
  /// schedule that shrinks (fewer days, adhan switched off) doesn't leave
  /// orphaned alarms behind that this list no longer covers.
  static Future<bool> schedule({
    required List<DateTime> times,
    required List<String> titles,
    required String body,
    required String rawResource,
    required int clearUpTo,
  }) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('scheduleAdhanAlarms', {
        'times': [for (final t in times) t.millisecondsSinceEpoch],
        'titles': titles,
        'body': body,
        'res': rawResource,
        'clearUpTo': clearUpTo,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // No host activity — widget tests, or the engine running headless.
      return false;
    }
  }

  static Future<void> cancelAll(int count) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('cancelAdhanAlarms', {'count': count});
    } on PlatformException {
      // Nothing to do: a stale alarm at worst plays one more adhan.
    } on MissingPluginException {
      // As above.
    }
  }

  /// Stops the adhan the service is playing.
  ///
  /// The service posts a notification with its own stop action, but that is
  /// only reachable by pulling down the shade and finding it. This is the
  /// same stop from inside the app.
  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('stopAdhan');
    } catch (_) {
      // Nothing to stop, or no native side. Not worth surfacing.
    }
  }

  /// Whether the service has the adhan sounding right now.
  ///
  /// The app asks before playing its own copy. Without this the two run at
  /// once — the service started by the alarm, and the in-app player started
  /// because opening the app finds a prayer that only just became due.
  static Future<bool> isPlaying() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAdhanPlaying') ?? false;
    } catch (_) {
      return false;
    }
  }
}
