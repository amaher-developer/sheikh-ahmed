import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/adhan/adhan_scheduler.dart';

/// The native side is the subject here, so these read it as source. The
/// alternative is an instrumented Android test, which this project does not
/// run — and an untested reboot path is exactly what caused the bug: the
/// adhan alarms were registered natively and nothing put them back.
String _kotlin(String name) => File(
  'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/$name',
).readAsStringSync();

String get _manifest =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

void main() {
  group('the schedule survives what clears alarms', () {
    test('a receiver listens for every event that wipes them', () {
      // Android drops an app's alarms on reboot AND on app update. The
      // update case is the one that bit: every install from Play wipes the
      // schedule, and nothing restored it until the app was next opened —
      // so a phone that updated overnight lost Fajr with no sign anything
      // was wrong.
      final manifest = _manifest;
      final block = manifest.substring(
        manifest.indexOf('.AdhanBootReceiver'),
        manifest.indexOf('</receiver>', manifest.indexOf('.AdhanBootReceiver')),
      );

      expect(block.contains('BOOT_COMPLETED'), isTrue);
      expect(block.contains('MY_PACKAGE_REPLACED'), isTrue);
      expect(block.contains('TIME_SET'), isTrue);
      expect(block.contains('TIMEZONE_CHANGED'), isTrue);
    });

    test('the receiver actually re-registers them', () {
      final receiver = _kotlin('AdhanBootReceiver.kt');
      expect(receiver.contains('AdhanSchedule.load'), isTrue);
      expect(receiver.contains('AdhanAlarmReceiver.schedule'), isTrue);
    });

    test('scheduling stores what it registered', () {
      // The prayer calculation lives in Dart, which is not running at boot.
      // Storing the instants Dart already computed is the only way the
      // native side can put the same alarms back.
      final alarm = _kotlin('AdhanAlarmReceiver.kt');
      expect(alarm.contains('AdhanSchedule.save('), isTrue);
    });

    test('cancelling clears the store too', () {
      // Or the boot receiver would faithfully restore a schedule the user
      // had just switched off.
      final alarm = _kotlin('AdhanAlarmReceiver.kt');
      final cancel = alarm.substring(alarm.indexOf('fun cancelAll('));
      expect(cancel.contains('AdhanSchedule.clear(context)'), isTrue);
    });

    test('restoring drops instants that have already passed', () {
      // An alarm set for a time already gone fires the moment it is
      // registered. Without this, a phone switched on after two days off
      // would sound every adhan it had missed, one after another.
      final store = _kotlin('AdhanSchedule.kt');
      expect(store.contains('if (at <= now) continue'), isTrue);
    });

    test('the restore covers every slot, not just the ones it refills', () {
      // A schedule that has shrunk must not leave the tail of the old one
      // behind, still armed.
      final receiver = _kotlin('AdhanBootReceiver.kt');
      expect(receiver.contains('clearUpTo = SLOTS'), isTrue);
      expect(receiver.contains('const val SLOTS = 35'), isTrue);
      // Mirrors the Dart constant; if one moves the other has to.
      expect(kAdhanAlarmSlots, 35);
    });
  });

  group('the adhan screen', () {
    test('the receiver opens it, and only when it is allowed to', () {
      // Android refuses background activity starts silently — no exception,
      // the call just does nothing — so the permission has to be checked
      // rather than the start assumed to have worked.
      final alarm = _kotlin('AdhanAlarmReceiver.kt');
      expect(alarm.contains('canDrawOverlays(context)'), isTrue);
      expect(alarm.contains('AdhanAlertActivity.intent('), isTrue);
    });

    test('there is no second route, and the app asks Play for nothing', () {
      // There was one, riding on a full-screen intent attached to the
      // playback notification. It was dropped with the
      // USE_FULL_SCREEN_INTENT permission: Play pre-grants that only to
      // alarm-clock and calling apps, this is neither, and declaring
      // otherwise on their form would be a false declaration — the same
      // reasoning that keeps SCHEDULE_EXACT_ALARM over USE_EXACT_ALARM.
      // Unpre-granted it would have been downgraded to a floating
      // notification anyway, so nothing real was lost.
      // The declaration, not the word: the manifest comment above
      // SYSTEM_ALERT_WINDOW names the permission to explain why it is gone,
      // and a bare substring match reads that as the permission itself.
      expect(
        _manifest.contains(
          '<uses-permission android:name='
          '"android.permission.USE_FULL_SCREEN_INTENT"',
        ),
        isFalse,
      );

      final service = _kotlin('AdhanPlaybackService.kt');
      expect(service.contains('setFullScreenIntent('), isFalse);

      // And the one route that remains still works.
      final receiver = _kotlin('AdhanAlarmReceiver.kt');
      expect(receiver.contains('AdhanAlertActivity.intent('), isTrue);
    });

    test('it shows over the lock screen and wakes the display', () {
      // At Fajr the phone is face down with the screen off, which is the
      // whole situation it exists for.
      final activity = _kotlin('AdhanAlertActivity.kt');
      expect(activity.contains('setShowWhenLocked(true)'), isTrue);
      expect(activity.contains('setTurnScreenOn(true)'), isTrue);
    });

    test('closing it does not stop the adhan', () {
      // Only the stop button does. A stray back press should leave the call
      // sounding, as it would from a mosque.
      final activity = _kotlin('AdhanAlertActivity.kt');
      final back = activity.substring(activity.indexOf('override fun onBackPressed'));
      expect(back.contains('AdhanPlaybackService.stop'), isFalse);

      // And the stop button is wired to something that does.
      expect(activity.contains('AdhanPlaybackService.stop(this)'), isTrue);
    });

    test('it is not a Flutter activity', () {
      // It is opened by a broadcast receiver at the instant the alarm
      // fires, with the app not running. Starting an engine to draw a
      // prayer name would add seconds and a great deal that can fail.
      final activity = _kotlin('AdhanAlertActivity.kt');
      expect(activity.contains('FlutterActivity'), isFalse);
      expect(activity.contains(': Activity()'), isTrue);
    });
  });
}
