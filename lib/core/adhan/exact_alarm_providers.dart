import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adhan_providers.dart';
import 'adhan_scheduler.dart';

/// Whether Android will honour *exact* alarms for this app right now.
///
/// The app declares SCHEDULE_EXACT_ALARM rather than USE_EXACT_ALARM, because
/// Play restricts the latter to alarm-clock and calendar apps (see
/// AndroidManifest.xml). The practical consequence is that from Android 13
/// the permission is not granted at install: until the user turns on "Alarms
/// & reminders", every reminder is an inexact alarm that Android may hold
/// until the next Doze maintenance window — so the adhan can arrive late.
///
/// This exposes that state to the UI so the app can offer the grant in
/// Settings, where it can be explained, instead of throwing the user into a
/// system settings screen during their first launch with no context.
class ExactAlarmsNotifier extends StateNotifier<bool> {
  final Ref _ref;
  late final AppLifecycleListener _lifecycle;

  ExactAlarmsNotifier(this._ref) : super(true) {
    refresh();
    // The grant is made in system settings, outside this app entirely, and
    // can also be revoked there at any time. Coming back to the foreground is
    // the only reliable moment to notice either.
    _lifecycle = AppLifecycleListener(onResume: refresh);
  }

  /// Guarded because with no platform implementation registered at all —
  /// every widget test, and any non-mobile host — the resolve call throws a
  /// LateInitializationError rather than returning null or raising the
  /// MissingPluginException you would expect.
  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _ref
          .read(notificationsPluginProvider)
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
    } catch (_) {
      return null;
    }
  }

  /// Defaults to allowed on every failure path, deliberately. Being unable to
  /// *ask* is not evidence the permission is missing, and guessing the other
  /// way would show the Settings prompt to users who have nothing to fix.
  Future<bool> _canScheduleExact() async {
    final android = _android;
    // Null on iOS, and on Android versions predating the restriction, where
    // exact alarms simply work.
    if (android == null) return true;
    try {
      return await android.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> refresh() async {
    final allowed = await _canScheduleExact();
    if (!mounted || allowed == state) return;
    state = allowed;
    AdhanScheduler.setExactAlarmsAllowed(allowed);
    // Unconditional, in both directions. Gaining the permission promotes
    // already-queued reminders from inexact alarms to exact ones; losing it
    // matters just as much, because the alarm-clock alarms that play the full
    // adhan stop being startable and the notification path has to be put back
    // or the prayer passes in silence.
    await _ref.read(adhanReschedulerProvider).run();
  }

  /// Opens the system's "Alarms & reminders" screen.
  ///
  /// Deliberately does not check the result: the plugin returns as soon as
  /// the intent is fired, long before the user has decided. [refresh] on the
  /// next resume is what actually observes the outcome.
  Future<void> request() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {
      // No settings screen to open on this device. Nothing useful to say to
      // the user, and throwing here would take down the Settings tap.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }
}

final exactAlarmsAllowedProvider =
    StateNotifierProvider<ExactAlarmsNotifier, bool>(
      (ref) => ExactAlarmsNotifier(ref),
    );
