import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Asks the OS for permission to post notifications — the adhan and the
/// reminders both depend on it.
///
/// Called from the first frame (see AdhanWatcher) rather than from main():
/// the plugin used to request it during `initialize()`, before `runApp`, so
/// the system prompt appeared over an empty screen and the app stayed blank
/// until it was answered. Now the home screen is up first and the prompt
/// lands on top of it, which is what a first launch should look like — and
/// what App Review sees.
///
/// Best-effort: a refusal is not an error. The in-app AdhanWatcher still
/// sounds the adhan while the app is open, and scheduling goes ahead
/// regardless so a later grant in system settings needs no further action.
Future<void> requestNotificationPermission(
  FlutterLocalNotificationsPlugin plugin,
) async {
  try {
    // Android 13+: `initialize()` alone does not ask, and without this every
    // notification is silently dropped by the OS.
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } catch (error, stack) {
    debugPrint('Notification permission request failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}
